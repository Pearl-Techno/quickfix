import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';
import '../services/database_helper.dart';
import 'package:uuid/uuid.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  User? _currentUser;
  bool _isLoading = false;
  bool _isAuthenticated = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isTechnician => _currentUser?.isTechnician ?? false;
  bool get isManager => _currentUser?.isManager ?? false;

  // ============= AUTHENTICATION =============
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.login(email, password);

      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        _setLoading(false);
        notifyListeners();

        // Log login event
        await LogService().logEvent(
          currentUser: user,
          action: 'USER_LOGIN',
          description: 'User ${user.name} (${user.displayRole}) logged in',
          status: 'info',
        );

        // Sync pending data after login
        await _databaseService.syncNow().catchError((e) => debugPrint('Error syncing: $e'));

        return true;
      } else {
        _errorMessage = 'Invalid email or password';
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Login failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String name,
    String role = 'technician',
    String? phone,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.register(
        email: email,
        password: password,
        name: name,
        role: role,
        phone: phone,
      );

      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Registration failed. Please try again.';
        _setLoading(false);
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Registration failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    _clearError();

    try {
      await LogService().logEvent(
        currentUser: _currentUser,
        action: 'USER_LOGOUT',
        description: 'User ${_currentUser?.name ?? "Unknown"} logged out',
        status: 'info',
      );
      await _authService.logout();
      _currentUser = null;
      _isAuthenticated = false;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
    }
  }

  // ============= SESSION MANAGEMENT =============
  Future<bool> checkAuth() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        return true;
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        return false;
      }
    } catch (e) {
      _errorMessage = 'Auth check failed: ${_getErrorMessage(e)}';
      _currentUser = null;
      _isAuthenticated = false;
      return false;
    }
  }

  Future<bool> refreshSession() async {
    try {
      return await _authService.refreshSession();
    } catch (e) {
      _errorMessage = 'Session refresh failed: ${_getErrorMessage(e)}';
      return false;
    }
  }

  // ============= USER PROFILE MANAGEMENT =============
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.updateUserProfile(
        userId: _currentUser!.id,
        name: name,
        email: email,
        phone: phone,
        role: role,
        isActive: isActive,
        avatarUrl: avatarUrl,
      );

      if (success) {
        // Refresh user data
        final updatedUser = await _authService.getUserById(_currentUser!.id);
        if (updatedUser != null) {
          _currentUser = updatedUser;
        }
      }

      _setLoading(false);
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Profile update failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_currentUser == null) return false;

    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.changePassword(
        userId: _currentUser!.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      _setLoading(false);
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Password change failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.resetPassword(email);
      _setLoading(false);
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'Password reset failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  // ============= USER MANAGEMENT (Admin) =============
  Future<bool> createUser({
    required String email,
    required String password,
    required String name,
    String role = 'technician',
    String? phone,
  }) async {
    // Check if current user is admin using null-aware operator
    final isUserAdmin = _currentUser?.isAdmin ?? false;
    if (!isUserAdmin) {
      _errorMessage = 'Only admins can create users';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final user = await _authService.register(
        email: email,
        password: password,
        name: name,
        role: role,
        phone: phone,
        isCreatingOtherUser: true,
      );

      _setLoading(false);
      notifyListeners();
      return user != null;
    } catch (e) {
      _errorMessage = 'User creation failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser({
    required String userId,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    String? avatarUrl,
  }) async {
    // Check if current user is admin using null-aware operator
    final isUserAdmin = _currentUser?.isAdmin ?? false;
    if (!isUserAdmin) {
      _errorMessage = 'Only admins can update users';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.updateUserProfile(
        userId: userId,
        name: name,
        email: email,
        phone: phone,
        role: role,
        isActive: isActive,
        avatarUrl: avatarUrl,
      );

      _setLoading(false);
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'User update failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    // Check if current user is admin using null-aware operator
    final isUserAdmin = _currentUser?.isAdmin ?? false;
    if (!isUserAdmin) {
      _errorMessage = 'Only admins can update user passwords';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.updateUserPassword(
        userId: userId,
        newPassword: newPassword,
      );

      _setLoading(false);
      notifyListeners();
      return success;
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('requires a valid Bearer token') || 
          errorStr.contains('no_authorization') || 
          errorStr.contains('401') ||
          errorStr.contains('403') ||
          errorStr.contains('User not allowed') ||
          errorStr.contains('not_admin')) {
        _errorMessage = 'Direct password assignment is restricted on the client-side due to Supabase security (requires a Service Role key). Please use the "Send Password Reset Email" option instead.';
      } else {
        _errorMessage = 'Failed to update user password: ${_getErrorMessage(e)}';
      }
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    final isSuperAdmin = _currentUser?.isSuperAdmin ?? false;
    final isUserAdmin = _currentUser?.isAdmin ?? false;

    if (!isUserAdmin) {
      _errorMessage = 'Only admins can delete users';
      notifyListeners();
      return false;
    }

    if (userId == _currentUser?.id) {
      _errorMessage = 'Cannot delete your own account';
      notifyListeners();
      return false;
    }

    if (!isSuperAdmin) {
      try {
        final targetUser = await _authService.getUserById(userId);
        final targetName = targetUser?.name ?? userId;
        final dbHelper = DatabaseHelper();
        final reqId = const Uuid().v4();
        await dbHelper.saveApprovalRequest({
          'id': reqId,
          'requested_by_id': _currentUser!.id,
          'requested_by_name': _currentUser!.name,
          'user_role': _currentUser!.role,
          'action_type': 'DELETE_USER',
          'target_id': userId,
          'target_summary': 'Delete user $targetName ($userId)',
          'details': 'Action submitted by ${_currentUser!.name} for Superadmin approval.',
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        });
        await LogService().logEvent(
          currentUser: _currentUser,
          action: 'CRITICAL_APPROVAL_REQUEST',
          description: 'Submitted approval request to delete user $targetName',
          status: 'pending_approval',
        );
        _errorMessage = 'User deletion request submitted for Superadmin approval.';
        notifyListeners();
        return false;
      } catch (e) {
        _errorMessage = 'Failed to submit approval request: $e';
        notifyListeners();
        return false;
      }
    }

    _setLoading(true);
    _clearError();

    try {
      final success = await _authService.deleteUser(userId);
      if (success) {
        await LogService().logEvent(
          currentUser: _currentUser,
          action: 'DELETE_USER',
          description: 'Superadmin deleted user $userId',
          status: 'critical',
        );
      }
      _setLoading(false);
      notifyListeners();
      return success;
    } catch (e) {
      _errorMessage = 'User deletion failed: ${_getErrorMessage(e)}';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<List<User>> getAllUsers() async {
    try {
      return await _authService.getAllUsers();
    } catch (e) {
      _errorMessage = 'Failed to fetch users: ${_getErrorMessage(e)}';
      notifyListeners();
      return [];
    }
  }

  Future<List<User>> getUsersByRole(String role) async {
    try {
      return await _authService.getUsersByRole(role);
    } catch (e) {
      _errorMessage = 'Failed to fetch users: ${_getErrorMessage(e)}';
      notifyListeners();
      return [];
    }
  }

  // ============= PERMISSION HELPERS =============
  bool hasPermission(String requiredRole) {
    return _authService.hasPermission(requiredRole);
  }

  bool get canManageUsers => _authService.canManageUsers;
  bool get canManageQuotes => _authService.canManageQuotes;
  bool get canManageInvoices => _authService.canManageInvoices;
  bool get canManageCustomers => _authService.canManageCustomers;
  bool get canManageProducts => _authService.canManageProducts;
  bool get canViewReports => _authService.canViewReports;

  // ============= UTILITY METHODS =============
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _errorMessage = null;
    }
  }

  void _clearError() {
    _errorMessage = null;
  }

  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return error.message;
    }
    return error.toString();
  }

  // ============= GETTERS =============
  String? get userId => _currentUser?.id;
  String? get userRole => _currentUser?.role;
  String? get userName => _currentUser?.name;
  String? get userEmail => _currentUser?.email;
  User? get user => _currentUser;
}

// ============= AUTH PROVIDER EXTENSIONS =============
extension AuthProviderExtensions on BuildContext {
  AuthProvider get auth => Provider.of<AuthProvider>(this, listen: false);
  AuthProvider get authWatch => Provider.of<AuthProvider>(this, listen: true);

  bool get isAuthenticated => auth.isAuthenticated;
  bool get isAdmin => auth.isAdmin;
  bool get isTechnician => auth.isTechnician;
  bool get isManager => auth.isManager;

  User? get currentUser => auth.currentUser;
  String? get userId => auth.userId;
  String? get userRole => auth.userRole;
  String? get userName => auth.userName;
  String? get userEmail => auth.userEmail;

  bool get canManageUsers => auth.canManageUsers;
  bool get canManageQuotes => auth.canManageQuotes;
  bool get canManageInvoices => auth.canManageInvoices;
  bool get canManageCustomers => auth.canManageCustomers;
  bool get canManageProducts => auth.canManageProducts;
  bool get canViewReports => auth.canViewReports;
}
