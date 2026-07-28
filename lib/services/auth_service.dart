import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:quickfix/config/constants.dart';
import 'package:quickfix/services/supabase_service.dart';
import 'package:quickfix/services/database_helper.dart';
import 'package:quickfix/models/user.dart';
import 'package:quickfix/models/customer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class AuthService {
  final SupabaseService _supabase = SupabaseService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  User? _currentUser;
  bool _isInitialized = false;

  // ============= AUTHENTICATION =============
  Future<User?> login(String email, String password) async {
    try {
      final response = await _supabase.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        _clearSession();
        return null;
      }

      // Fetch or create user profile
      final user = await _getOrCreateUser(response.user!);
      if (user != null) {
        _currentUser = user;
        await _saveSession();
        return user;
      }

      return null;
    } catch (e) {
      _handleError('Login error', e);
      _clearSession();
      return null;
    }
  }

  Future<User?> register({
    required String email,
    required String password,
    required String name,
    String role = Constants.roleTechnician,
    String? phone,
    bool isCreatingOtherUser = false,
  }) async {
    try {
      // Check if user already exists
      if (await _emailExists(email)) {
        throw Exception('Email already registered');
      }

      // Enforce security control: Self-registered users are always created as Technicians
      final finalRole = isCreatingOtherUser ? role : Constants.roleTechnician;

      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
      final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';

      String newUserId = '';

      if (isCreatingOtherUser && serviceRoleKey.isNotEmpty) {
        // Create user directly using Admin API (skips confirmation and doesn't change active session)
        final adminClient = supabase.SupabaseClient(supabaseUrl, serviceRoleKey);
        final response = await adminClient.auth.admin.createUser(
          supabase.AdminUserAttributes(
            email: email.trim(),
            password: password,
            emailConfirm: true, // Auto-confirm email
            userMetadata: {'name': name, 'role': finalRole, 'phone': phone},
          ),
        );
        if (response.user == null) {
          throw Exception('Failed to create user via Admin API');
        }
        newUserId = response.user!.id;
      } else {
        // Standard client-side signup
        final signupClient = isCreatingOtherUser
            ? supabase.SupabaseClient(supabaseUrl, supabaseAnonKey)
            : _supabase.client;

        final response = await signupClient.auth.signUp(
          email: email.trim(),
          password: password,
          data: {'name': name, 'role': finalRole, 'phone': phone},
        );

        if (response.user == null) {
          throw Exception('Failed to create user');
        }
        newUserId = response.user!.id;
      }

      // Create user profile (excluding is_active as the Supabase table doesn't have it)
      final newUser = {
        'id': newUserId,
        'name': name.trim(),
        'email': email.trim(),
        'role': finalRole,
        'phone': phone,
      };

      // Always insert profile using the main client (which has admin permissions)
      await _supabase.client.from(SupabaseService.usersTable).insert(newUser);

      // Create model with active status set to true for local cache
      final user = User.fromJson({
        ...newUser,
        'is_active': 1,
      });
      
      // Cache locally
      try {
        await _dbHelper.insert('users', user.toMap());
      } catch (_) {}

      if (!isCreatingOtherUser) {
        _currentUser = user;
        await _saveSession();
      }
      return user;
    } catch (e) {
      _handleError('Registration error', e);
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _supabase.client.auth.signOut();
      _clearSession();
    } catch (e) {
      _handleError('Logout error', e);
    }
  }

  // ============= SESSION MANAGEMENT =============
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final session = _supabase.client.auth.currentSession;
      if (session == null) {
        await _loadSession();
        return _currentUser;
      }

      final user = await _getOrCreateUser(session.user);
      if (user != null) {
        _currentUser = user;
        await _saveSession();
        return user;
      }

      return null;
    } catch (e) {
      _handleError('Get current user error', e);
      return null;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final session = _supabase.client.auth.currentSession;
      if (session != null) return true;

      // Check if we have a cached session
      await _loadSession();
      return _currentUser != null;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      return _supabase.client.auth.currentSession?.accessToken;
    } catch (e) {
      return null;
    }
  }

  Future<String?> getRefreshToken() async {
    try {
      return _supabase.client.auth.currentSession?.refreshToken;
    } catch (e) {
      return null;
    }
  }

  Future<bool> refreshSession() async {
    try {
      final session = _supabase.client.auth.currentSession;
      if (session == null) return false;

      await _supabase.client.auth.refreshSession();
      await _saveSession();
      return true;
    } catch (e) {
      _handleError('Refresh session error', e);
      return false;
    }
  }

  // ============= USER MANAGEMENT =============
  Future<User?> getUserById(String userId) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.usersTable)
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        final user = User.fromJson(response);
        // Cache locally
        try {
          await _dbHelper.insert('users', user.toMap());
        } catch (_) {
          try {
            await _dbHelper.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
          } catch (_) {}
        }
        return user;
      }
      return null;
    } catch (e) {
      _handleError('Get user by id error', e);
      // Fallback to local DB
      try {
        final localMap = await _dbHelper.getUser(userId);
        if (localMap != null) {
          return User.fromMap(localMap);
        }
      } catch (localError) {
        _handleError('Get user by id local error', localError);
      }
      return null;
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.usersTable)
          .select()
          .order('name');

      final users = response.map<User>((json) => User.fromJson(json)).toList();
      // Cache locally
      for (var user in users) {
        try {
          await _dbHelper.insert('users', user.toMap());
        } catch (_) {
          try {
            await _dbHelper.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
          } catch (_) {}
        }
      }
      return users;
    } catch (e) {
      _handleError('Get all users error', e);
      try {
        final localMaps = await _dbHelper.getAllUsers();
        return localMaps.map((map) => User.fromMap(map)).toList();
      } catch (localError) {
        _handleError('Get all users local error', localError);
        return [];
      }
    }
  }

  Future<List<User>> getUsersByRole(String role) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.usersTable)
          .select()
          .eq('role', role)
          .order('name');

      final users = response.map<User>((json) => User.fromJson(json)).toList();
      // Cache locally
      for (var user in users) {
        try {
          await _dbHelper.insert('users', user.toMap());
        } catch (_) {
          try {
            await _dbHelper.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
          } catch (_) {}
        }
      }
      return users;
    } catch (e) {
      _handleError('Get users by role error', e);
      try {
        final localMaps = await _dbHelper.query('users', where: 'role = ?', whereArgs: [role], orderBy: 'name ASC');
        return localMaps.map((map) => User.fromMap(map)).toList();
      } catch (localError) {
        _handleError('Get users by role local error', localError);
        return [];
      }
    }
  }

  Future<bool> updateUserProfile({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    String? avatarUrl,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      // Check if name is provided and not empty
      if (name != null && name.isNotEmpty) {
        updates['name'] = name.trim();
      }
      if (email != null && email.isNotEmpty) {
        updates['email'] = email.trim();
      }

      if (phone != null) {
        updates['phone'] = phone.trim().isEmpty ? null : phone.trim();
      }
      if (role != null && role.isNotEmpty) updates['role'] = role;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      // Do NOT set updates['is_active'] = isActive; because the Supabase users table doesn't have it.

      if (updates.isEmpty && isActive == null) {
        throw Exception('No updates provided');
      }

      // Update email in Supabase Auth if provided
      if (email != null && email.isNotEmpty) {
        if (_currentUser?.id == userId) {
          await _supabase.client.auth.updateUser(
            supabase.UserAttributes(email: email.trim()),
          );
        } else {
          final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
          if (serviceRoleKey.isNotEmpty) {
            final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
            final adminClient = supabase.SupabaseClient(supabaseUrl, serviceRoleKey);
            await adminClient.auth.admin.updateUserById(
              userId,
              attributes: supabase.AdminUserAttributes(email: email.trim()),
            );
          } else {
            throw supabase.AuthApiException(
              'Updating another user\'s email/username requires administrative credentials. Please add SUPABASE_SERVICE_ROLE_KEY to the .env file.',
              statusCode: '403',
            );
          }
        }
      }

      updates['updated_at'] = DateTime.now().toIso8601String();

      await _supabase.client
          .from(SupabaseService.usersTable)
          .update(updates)
          .eq('id', userId);

      // Update current user if it's the same
      if (_currentUser?.id == userId) {
        _currentUser = await getUserById(userId);
        await _saveSession();
      }

      // Update locally
      try {
        final localUpdates = Map<String, dynamic>.from(updates);
        if (isActive != null) {
          localUpdates['is_active'] = isActive ? 1 : 0;
        }
        await _dbHelper.update('users', localUpdates, where: 'id = ?', whereArgs: [userId]);
      } catch (_) {}

      return true;
    } catch (e) {
      _handleError('Update user error', e);
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      // Check if user is trying to delete themselves
      if (_currentUser?.id == userId) {
        throw Exception('Cannot delete your own account');
      }

      // Delete from users table
      await _supabase.client
          .from(SupabaseService.usersTable)
          .delete()
          .eq('id', userId);

      // Delete locally
      try {
        await _dbHelper.deleteUser(userId);
      } catch (_) {}

      return true;
    } catch (e) {
      _handleError('Delete user error', e);
      return false;
    }
  }

  Future<bool> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Validate password strength
      if (!Constants.isValidPassword(newPassword)) {
        throw Exception('Password does not meet requirements');
      }

      // Update password in auth
      await _supabase.client.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );

      return true;
    } catch (e) {
      _handleError('Change password error', e);
      return false;
    }
  }

  Future<bool> updateUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      // Validate password strength
      if (!Constants.isValidPassword(newPassword)) {
        throw Exception('Password does not meet requirements');
      }

      if (_currentUser?.id == userId) {
        await _supabase.client.auth.updateUser(
          supabase.UserAttributes(password: newPassword),
        );
        return true;
      }

      final serviceRoleKey = dotenv.env['SUPABASE_SERVICE_ROLE_KEY'] ?? '';
      if (serviceRoleKey.isNotEmpty) {
        final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
        final adminClient = supabase.SupabaseClient(supabaseUrl, serviceRoleKey);
        await adminClient.auth.admin.updateUserById(
          userId,
          attributes: supabase.AdminUserAttributes(password: newPassword),
        );
        return true;
      }

      // If we don't have service role key, we cannot update another user's password directly.
      throw supabase.AuthApiException(
        'Direct password updates require administrative credentials. Please add SUPABASE_SERVICE_ROLE_KEY to the .env file or use the "Send Password Reset Email" option.',
        statusCode: '403',
      );
    } catch (e) {
      _handleError('Update user password error', e);
      rethrow;
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      await _supabase.client.auth.resetPasswordForEmail(email.trim());
      return true;
    } catch (e) {
      _handleError('Reset password error', e);
      return false;
    }
  }

  // ============= CUSTOMER MANAGEMENT =============
  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.customersTable)
          .select()
          .order('name');

      return response.map<Customer>((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      _handleError('Get customers error', e);
      return [];
    }
  }

  Future<Customer?> getCustomerById(String customerId) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.customersTable)
          .select()
          .eq('id', customerId)
          .maybeSingle();

      if (response != null) {
        return Customer.fromJson(response);
      }
      return null;
    } catch (e) {
      _handleError('Get customer by id error', e);
      return null;
    }
  }

  // ============= PRIVATE METHODS =============
  Future<User?> _getOrCreateUser(supabase.User authUser) async {
    try {
      final userData = await _supabase.client
          .from(SupabaseService.usersTable)
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (userData != null) {
        final user = User.fromJson(userData);
        // Cache locally
        try {
          await _dbHelper.insert('users', user.toMap());
        } catch (_) {
          try {
            await _dbHelper.update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
          } catch (_) {}
        }
        return user;
      }

      // Create user profile if it doesn't exist
      final newUser = {
        'id': authUser.id,
        'name': authUser.email?.split('@').first ?? 'User',
        'email': authUser.email,
        'role': Constants.roleTechnician,
      };

      await _supabase.client.from(SupabaseService.usersTable).insert(newUser);

      final user = User.fromJson(newUser);
      // Cache locally
      try {
        await _dbHelper.insert('users', user.toMap());
      } catch (_) {}

      return user;
    } catch (e) {
      _handleError('Get or create user error', e);
      // Fallback to local DB
      try {
        final localMap = await _dbHelper.getUser(authUser.id);
        if (localMap != null) {
          return User.fromMap(localMap);
        }
      } catch (localError) {
        _handleError('Get or create user local error', localError);
      }
      return null;
    }
  }

  Future<bool> _emailExists(String email) async {
    try {
      final response = await _supabase.client
          .from(SupabaseService.usersTable)
          .select('id')
          .eq('email', email.trim())
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        await prefs.setString('user_id', _currentUser!.id);
        await prefs.setString('user_role', _currentUser!.role);
        await prefs.setBool('is_authenticated', true);
      }
    } catch (e) {
      _handleError('Save session error', e);
    }
  }

  Future<void> _loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      if (userId != null) {
        final user = await getUserById(userId);
        if (user != null) {
          _currentUser = user;
          _isInitialized = true;
        }
      }
    } catch (e) {
      _handleError('Load session error', e);
    }
  }

  void _clearSession() {
    try {
      _currentUser = null;
      _isInitialized = false;
      // Async cleanup is done separately
      _clearSessionAsync();
    } catch (e) {
      _handleError('Clear session error', e);
    }
  }

  Future<void> _clearSessionAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('user_role');
      await prefs.setBool('is_authenticated', false);
    } catch (e) {
      _handleError('Clear session async error', e);
    }
  }

  void _handleError(String message, dynamic error) {
    if (kDebugMode) {
      print('$message: $error');
    }
  }

  // ============= GETTERS =============
  User? get currentUser => _currentUser;
  bool get isInitialized => _isInitialized;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isTechnician => _currentUser?.isTechnician ?? false;
  bool get isManager => _currentUser?.isManager ?? false;

  String? get userId => _currentUser?.id;
  String? get userRole => _currentUser?.role;
  String? get userName => _currentUser?.name;
  String? get userEmail => _currentUser?.email;

  // ============= STREAMS =============
  Stream<User?> get userChanges {
    return _supabase.client.auth.onAuthStateChange
        .map((event) {
          if (event.session != null) {
            return _getOrCreateUser(event.session!.user);
          }
          return null;
        })
        .asyncMap((future) => future);
  }

  // ============= PERMISSION HELPERS =============
  bool hasPermission(String requiredRole) {
    return _currentUser?.hasPermission(requiredRole) ?? false;
  }

  bool get canManageUsers => _currentUser?.canManageUsers ?? false;
  bool get canManageQuotes => _currentUser?.canManageQuotes ?? false;
  bool get canManageInvoices => _currentUser?.canManageInvoices ?? false;
  bool get canManageCustomers => _currentUser?.canManageCustomers ?? false;
  bool get canManageProducts => _currentUser?.canManageProducts ?? false;
  bool get canViewReports => _currentUser?.canViewReports ?? false;
}

// ============= AUTH EXCEPTIONS =============
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  @override
  String toString() =>
      'AuthException: $message${code != null ? ' (Code: $code)' : ''}';
}
