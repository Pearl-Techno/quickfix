import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/config/app_colors.dart';
import 'package:quickfix/config/constants.dart';
import 'package:quickfix/models/user.dart';
import 'package:quickfix/providers/auth_provider.dart';
import 'package:quickfix/providers/settings_provider.dart';
import 'package:quickfix/widgets/custom_button.dart';
import 'package:quickfix/widgets/custom_textfield.dart';
import 'package:quickfix/widgets/custom_dropdown.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickfix/utils/helpers.dart';
import 'package:quickfix/services/database_service.dart';
import 'package:quickfix/providers/quote_provider.dart';
import 'package:quickfix/providers/invoice_provider.dart';
import 'package:quickfix/providers/customer_provider.dart';
import 'package:quickfix/providers/product_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Profile section
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Password section
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isEditingProfile = false;
  bool _isChangingPassword = false;
  bool _isSaving = false;
  int _selectedTab = 0;

  // User management section
  Future<List<User>>? _usersFuture;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _refreshUsers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _refreshUsers() {
    setState(() {
      _usersFuture = context.read<AuthProvider>().getAllUsers();
    });
  }

  void _loadUserData() {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      _nameController.text = user.name;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
    }
  }

  Future<void> _saveProfile() async {
    if (!_isEditingProfile) {
      setState(() => _isEditingProfile = true);
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      Helpers.showError(context, 'Name cannot be empty');
      return;
    }

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateProfile(
      name: name,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      setState(() => _isEditingProfile = false);
      Helpers.showSuccess(context, 'Profile updated successfully');
    } else {
      Helpers.showError(
        context,
        authProvider.errorMessage ?? 'Failed to update profile',
      );
    }
  }

  Future<void> _changePassword() async {
    if (!_isChangingPassword) {
      setState(() => _isChangingPassword = true);
      return;
    }

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      Helpers.showError(context, 'Please enter your current password');
      return;
    }

    if (newPassword.isEmpty) {
      Helpers.showError(context, 'Please enter a new password');
      return;
    }

    if (newPassword.length < 8) {
      Helpers.showError(context, 'Password must be at least 8 characters');
      return;
    }

    if (!Constants.isValidPassword(newPassword)) {
      Helpers.showError(context, 'Password must contain letters and numbers');
      return;
    }

    if (newPassword != confirmPassword) {
      Helpers.showError(context, 'Passwords do not match');
      return;
    }

    setState(() => _isSaving = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;

    if (success) {
      setState(() {
        _isChangingPassword = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });
      Helpers.showSuccess(context, 'Password changed successfully');
    } else {
      Helpers.showError(
        context,
        authProvider.errorMessage ?? 'Failed to change password',
      );
    }
  }

  void _cancelEditing() {
    setState(() {
      _isEditingProfile = false;
      _isChangingPassword = false;
      _loadUserData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditingProfile || _isChangingPassword)
            TextButton(
              onPressed: _isSaving ? null : _cancelEditing,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),

              const SizedBox(height: 20),

              // Responsive Layout Builder for Settings sections
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 850;
                  if (isWide) {
                    return _buildWideLayout();
                  } else {
                    return _buildMobileLayout();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // RESPONSIVE LAYOUT HELPER METHODS
  // ============================================

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Sidebar Navigation
        SizedBox(
          width: 260,
          child: _buildSettingsSidebar(),
        ),
        const SizedBox(width: 24),
        // Right Content Area
        Expanded(
          child: _buildActiveTabContent(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    final canManageUsers = context.read<AuthProvider>().currentUser?.canManageUsers ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal Scrollable Segment Bar
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildSegmentItem(0, Icons.person_outline, 'Profile'),
              _buildSegmentItem(1, Icons.lock_outline, 'Security'),
              if (canManageUsers)
                _buildSegmentItem(4, Icons.people_outline, 'Users'),
              _buildSegmentItem(2, Icons.apps_outlined, 'Preferences'),
              _buildSegmentItem(3, Icons.info_outline, 'About'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Active Content Card
        _buildActiveTabContent(),
        const SizedBox(height: 16),
        // Logout Button at bottom for mobile
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildSettingsSidebar() {
    final canManageUsers = context.read<AuthProvider>().currentUser?.canManageUsers ?? false;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          _buildSidebarItem(0, Icons.person_outline, 'Profile & Account'),
          _buildSidebarItem(1, Icons.lock_outline, 'Security'),
          if (canManageUsers)
            _buildSidebarItem(4, Icons.people_outline, 'User Management'),
          _buildSidebarItem(2, Icons.apps_outlined, 'App Preferences'),
          _buildSidebarItem(3, Icons.info_outline, 'About & Support'),
          const Divider(height: 24),
          _buildSidebarLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String title) {
    final isActive = _selectedTab == index;
    final color = isActive ? AppColors.primary : AppColors.text;
    final bgColor = isActive ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
              if (isActive)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: _showLogoutConfirmation,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.logout, size: 20, color: AppColors.error),
              const SizedBox(width: 12),
              const Text(
                'Logout',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentItem(int index, IconData icon, String title) {
    final isActive = _selectedTab == index;
    final color = isActive ? Colors.white : AppColors.text;
    final bgColor = isActive ? AppColors.primary : Colors.white;
    final borderColor = isActive ? AppColors.primary : AppColors.border.withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = index;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildProfileSection();
      case 1:
        return _buildSecuritySection();
      case 2:
        return _buildAppSettingsSection();
      case 3:
        return _buildAboutSection();
      case 4:
        return _buildUserManagementSection();
      default:
        return _buildProfileSection();
    }
  }

  // ============================================
  // HEADER
  // ============================================

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.settings,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Manage your account and app preferences',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PROFILE SECTION
  // ============================================

  Widget _buildProfileSection() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return _buildSectionCard(
      title: 'Profile',
      icon: Icons.person_outline,
      color: AppColors.primary,
      content: Column(
        children: [
          // Avatar
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: CircleAvatar(
                radius: 38,
                backgroundColor: Colors.transparent,
                child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          user.avatarUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              Helpers.getInitials(user.name),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 30,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        Helpers.getInitials(user?.name ?? 'User'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Name
          if (!_isEditingProfile) ...[
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.textLight),
              title: const Text('Name'),
              subtitle: Text(
                user?.name ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ] else ...[
            CustomTextField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              isRequired: true,
            ),
          ],

          // Email / Username
          if (!_isEditingProfile) ...[
            ListTile(
              leading: const Icon(Icons.email, color: AppColors.textLight),
              title: Text(user?.email.endsWith('@quickfix.local') ?? false ? 'Username' : 'Email'),
              subtitle: Text(
                user?.displayEmail ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ] else ...[
            const SizedBox(height: 8),
            CustomTextField(
              controller: _emailController,
              label: user?.email.endsWith('@quickfix.local') ?? false ? 'Username' : 'Email / Username',
              hint: 'Enter your email or username',
              isRequired: true,
              prefixIcon: const Icon(Icons.email),
            ),
          ],

          // Phone
          if (!_isEditingProfile) ...[
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.textLight),
              title: const Text('Phone'),
              subtitle: Text(
                user?.phone ?? 'Not set',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: user?.phone == null ? AppColors.textLight : null,
                ),
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ] else ...[
            const SizedBox(height: 8),
            CustomTextField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: 'Enter your phone number (optional)',
              keyboardType: TextInputType.phone,
            ),
          ],

          const SizedBox(height: 16),

          // Role Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Role: ${_getRoleDisplay(user?.role)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.info,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Edit/Save Button
          CustomButton(
            text: _isEditingProfile
                ? _isSaving
                      ? 'Saving...'
                      : 'Save Profile'
                : 'Edit Profile',
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isEditingProfile ? Icons.save : Icons.edit,
            isLoading: _isSaving,
            variant: _isEditingProfile
                ? ButtonVariant.primary
                : ButtonVariant.secondary,
            size: ButtonSize.medium,
          ),
        ],
      ),
    );
  }

  // ============================================
  // SECURITY SECTION
  // ============================================

  Widget _buildSecuritySection() {
    return _buildSectionCard(
      title: 'Security',
      icon: Icons.lock_outline,
      color: AppColors.warning,
      content: Column(
        children: [
          if (!_isChangingPassword) ...[
            ListTile(
              leading: const Icon(Icons.lock, color: AppColors.textLight),
              title: const Text('Password'),
              subtitle: const Text('••••••••'),
              trailing: Icon(Icons.chevron_right, color: AppColors.textLight),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () {
                setState(() => _isChangingPassword = true);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email_outlined, color: AppColors.textLight),
              title: const Text('Reset Password via Email'),
              subtitle: const Text('Send a password reset link to your email'),
              trailing: const Icon(
                Icons.send,
                color: AppColors.textLight,
                size: 16,
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                setState(() => _isSaving = true);
                final authProvider = context.read<AuthProvider>();
                final email = authProvider.currentUser?.email ?? '';
                final success = await authProvider.resetPassword(email);
                setState(() => _isSaving = false);
                if (!mounted) return;
                if (success) {
                  Helpers.showSuccess(context, 'Reset link sent to $email');
                } else {
                  Helpers.showError(
                    context,
                    authProvider.errorMessage ?? 'Failed to send reset email',
                  );
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.devices, color: AppColors.textLight),
              title: const Text('Active Sessions'),
              subtitle: const Text('Manage your devices'),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.textLight,
              ),
              dense: true,
              contentPadding: EdgeInsets.zero,
              onTap: () {
                _showComingSoon('Active sessions');
              },
            ),
          ] else ...[
            CustomTextField(
              controller: _currentPasswordController,
              label: 'Current Password',
              hint: 'Enter your current password',
              obscureText: true,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _newPasswordController,
              label: 'New Password',
              hint: 'Enter a new password (min 8 characters)',
              obscureText: true,
              isRequired: true,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              hint: 'Confirm your new password',
              obscureText: true,
              isRequired: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: _isSaving ? 'Changing...' : 'Change Password',
                    onPressed: _isSaving ? null : _changePassword,
                    icon: Icons.save,
                    isLoading: _isSaving,
                    size: ButtonSize.medium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'Cancel',
                    onPressed: _cancelEditing,
                    isOutlined: true,
                    variant: ButtonVariant.outlined,
                    size: ButtonSize.medium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================
  // APP SETTINGS SECTION
  // ============================================

  Widget _buildAppSettingsSection() {
    final settingsProvider = context.watch<SettingsProvider>();

    return _buildSectionCard(
      title: 'App Settings',
      icon: Icons.apps_outlined,
      color: AppColors.secondary,
      content: Column(
        children: [
          SwitchListTile(
            value: settingsProvider.vatEnabled,
            title: const Text('VAT (16% Tax)'),
            subtitle: Text(
              settingsProvider.vatEnabled
                  ? 'VAT (16%) is enabled for quotes and invoices'
                  : 'VAT (16%) is disabled by default for quotes and invoices',
            ),
            secondary: Icon(
              Icons.receipt_long_outlined,
              color: settingsProvider.vatEnabled
                  ? AppColors.primary
                  : AppColors.textLight,
            ),
            onChanged: (value) {
              settingsProvider.setVatEnabled(value);
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          SwitchListTile(
            value: settingsProvider.notificationsEnabled,
            title: const Text('Push Notifications'),
            subtitle: const Text(
              'Receive notifications about quotes and invoices',
            ),
            secondary: Icon(
              Icons.notifications_outlined,
              color: settingsProvider.notificationsEnabled
                  ? AppColors.primary
                  : AppColors.textLight,
            ),
            onChanged: (value) {
              settingsProvider.setNotificationsEnabled(value);
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          SwitchListTile(
            value: settingsProvider.darkModeEnabled,
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch to dark theme'),
            secondary: Icon(
              settingsProvider.darkModeEnabled
                  ? Icons.dark_mode
                  : Icons.light_mode,
              color: settingsProvider.darkModeEnabled
                  ? AppColors.primary
                  : AppColors.textLight,
            ),
            onChanged: (value) {
              settingsProvider.setDarkModeEnabled(value);
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          SwitchListTile(
            value: settingsProvider.offlineModeEnabled,
            title: const Text('Offline Mode'),
            subtitle: const Text('Enable offline access to data'),
            secondary: Icon(
              Icons.offline_bolt_outlined,
              color: settingsProvider.offlineModeEnabled
                  ? AppColors.primary
                  : AppColors.textLight,
            ),
            onChanged: (value) {
              settingsProvider.setOfflineModeEnabled(value);
            },
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.language, color: AppColors.textLight),
            title: const Text('Language'),
            subtitle: const Text('English'),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showComingSoon('Language settings');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.data_usage, color: AppColors.textLight),
            title: const Text('Data Usage'),
            subtitle: const Text('Manage app data storage'),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showComingSoon('Data management');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.numbers, color: AppColors.textLight),
            title: const Text('Starting Quote Number'),
            subtitle: FutureBuilder<String>(
              future: SharedPreferences.getInstance().then((prefs) => prefs.getString('start_quote_number') ?? '010A'),
              builder: (context, snapshot) {
                return Text(snapshot.data ?? '010A');
              },
            ),
            trailing: const Icon(
              Icons.edit,
              size: 18,
              color: AppColors.textLight,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showStartingQuoteNumberDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.numbers_outlined, color: AppColors.textLight),
            title: const Text('Starting Invoice Number'),
            subtitle: FutureBuilder<String>(
              future: SharedPreferences.getInstance().then((prefs) => prefs.getString('start_invoice_number') ?? 'QPN00001'),
              builder: (context, snapshot) {
                return Text(snapshot.data ?? 'QPN00001');
              },
            ),
            trailing: const Icon(
              Icons.edit,
              size: 18,
              color: AppColors.textLight,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showStartingInvoiceNumberDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.refresh_outlined, color: AppColors.primary),
            title: const Text('Renumber Existing Records'),
            subtitle: const Text('Re-sequence all historical quotes and invoices chronologically'),
            trailing: const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showRenumberConfirmationDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.error),
            title: const Text(
              'Reset System for Production',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              'Wipe all development & test data (quotes, invoices, customers, products) while retaining Admin accounts',
            ),
            trailing: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showProductionResetConfirmationDialog();
            },
          ),
        ],
      ),
    );
  }

  // ============================================
  // ABOUT SECTION
  // ============================================

  Widget _buildAboutSection() {
    return _buildSectionCard(
      title: 'About & Support',
      icon: Icons.info_outline,
      color: AppColors.info,
      content: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.textLight),
            title: const Text('System Version'),
            subtitle: const Text('1.0.0'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.business_outlined, color: AppColors.textLight),
            title: const Text('System Name'),
            subtitle: const Text('Quickfix Plumbers Management System'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.code_outlined, color: AppColors.primary),
            title: const Text('Developing Company'),
            subtitle: const Text('Quantyx Labs, Nairobi Kenya'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.email_outlined, color: AppColors.primary),
            title: const Text('Support Email'),
            subtitle: const Text('info@quantyx.co.ke'),
            trailing: IconButton(
              icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'info@quantyx.co.ke'));
                Helpers.showSuccess(context, 'Support email copied to clipboard!');
              },
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.support_agent, color: AppColors.textLight),
            title: const Text('Help & Support'),
            subtitle: const Text('Get assistance & system guidance'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showHelpAndSupportDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.textLight),
            title: const Text('Privacy Policy'),
            subtitle: const Text('View data handling & privacy terms'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showPrivacyPolicyDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.description_outlined, color: AppColors.textLight),
            title: const Text('Terms of Service'),
            subtitle: const Text('View software licensing & usage terms'),
            trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
            dense: true,
            contentPadding: EdgeInsets.zero,
            onTap: () {
              _showTermsOfServiceDialog();
            },
          ),
        ],
      ),
    );
  }

  // ============================================
  // LOGOUT BUTTON
  // ============================================

  Widget _buildLogoutButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomButton(
        text: 'Logout',
        onPressed: _showLogoutConfirmation,
        icon: Icons.logout,
        variant: ButtonVariant.danger,
        size: ButtonSize.large,
      ),
    );
  }

  // ============================================
  // DIALOGS & HELPERS
  // ============================================

  void _showComingSoon(String feature) {
    Helpers.showSnackBar(
      context,
      '$feature coming soon',
      backgroundColor: AppColors.info,
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performLogout();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performLogout() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.logout();

    if (!mounted) return;

    // Navigate to login screen and remove all previous routes
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ============================================
  // HELPER WIDGETS
  // ============================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Small decorative line
              Container(
                width: 30,
                height: 2,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          content,
        ],
      ),
    );
  }

  String _getRoleDisplay(String? role) {
    switch (role) {
      case Constants.roleAdmin:
        return 'Administrator';
      case Constants.roleTechnician:
        return 'Technician';
      case Constants.roleManager:
        return 'Manager';
      default:
        return 'User';
    }
  }

  // ============================================
  // USER MANAGEMENT WIDGETS & DIALOGS
  // ============================================

  Widget _buildUserManagementSection() {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;

    return _buildSectionCard(
      title: 'User Management',
      icon: Icons.people_outline,
      color: AppColors.primary,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search and Add Header
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or role...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              CustomButton(
                text: 'Add User',
                onPressed: _showAddUserDialog,
                icon: Icons.person_add,
                size: ButtonSize.medium,
                fullWidth: false,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // User list
          FutureBuilder<List<User>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading users: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                );
              }

              final users = snapshot.data ?? [];
              final filteredUsers = users.where((user) {
                return User.filterBySearch(user, _searchQuery);
              }).toList();

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isEmpty ? 'No users in the system' : 'No users match "$_searchQuery"',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredUsers.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  final isSelf = user.id == currentUserId;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Initials Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: user.displayColor.withValues(alpha: 0.15),
                            border: Border.all(color: user.displayColor.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text(
                              user.displayInitials,
                              style: TextStyle(
                                color: user.displayColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),

                        // User Information
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (isSelf) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'You',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                user.displayEmail,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textLight,
                                ),
                              ),
                              if (user.hasPhone) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user.phone!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Role and Status badges
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: user.roleColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(user.roleIcon, size: 12, color: user.roleColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    user.displayRole,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: user.roleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: user.isActive
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                user.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: user.isActive ? Colors.green : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),

                        // Actions
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textLight),
                          onPressed: () => _showEditUserDialog(user),
                          tooltip: 'Edit User',
                        ),
                        if (!isSelf)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                            onPressed: () => _showDeleteUserDialog(user),
                            tooltip: 'Delete User',
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = Constants.roleTechnician;
    bool isSaving = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: AppColors.primary),
              SizedBox(width: 10),
              Text('Add New User', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTextField(
                      controller: nameCtrl,
                      label: 'Full Name',
                      hint: 'Enter user full name',
                      isRequired: true,
                      prefixIcon: const Icon(Icons.person),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: emailCtrl,
                      label: 'Email / Username',
                      hint: 'user@quickfix.local or standard email',
                      isRequired: true,
                      prefixIcon: const Icon(Icons.email),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!Constants.isValidEmail(v.trim())) return 'Invalid email format';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomTextFields.password(
                      label: 'Password',
                      controller: passCtrl,
                      obscureText: obscurePassword,
                      onToggleVisibility: () => setStateDialog(() {
                        obscurePassword = !obscurePassword;
                      }),
                      isRequired: true,
                      hint: 'Minimum 8 characters with letters & numbers',
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: phoneCtrl,
                      label: 'Phone Number',
                      hint: 'Enter phone number (optional)',
                      prefixIcon: const Icon(Icons.phone),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    CustomDropdown<String>(
                      value: selectedRole,
                      label: 'Role',
                      isRequired: true,
                      prefixIcon: const Icon(Icons.admin_panel_settings),
                      items: Constants.roleList.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(Constants.getRoleDisplay(role)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedRole = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setStateDialog(() => isSaving = true);

                      final authProvider = context.read<AuthProvider>();
                      final success = await authProvider.createUser(
                        email: emailCtrl.text.trim(),
                        password: passCtrl.text,
                        name: nameCtrl.text.trim(),
                        role: selectedRole,
                        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                      );

                      setStateDialog(() => isSaving = false);

                      if (!context.mounted) return;

                      if (success) {
                        Navigator.pop(context);
                        Helpers.showSuccess(context, 'User created successfully!');
                        _refreshUsers();
                      } else {
                        Helpers.showError(
                          context,
                          authProvider.errorMessage ?? 'Failed to create user',
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUserDialog(User user) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    String selectedRole = user.role;
    bool isActive = user.isActive;
    bool isSaving = false;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isSelf = user.id == currentUserId;
    final passCtrl = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Edit User: ${user.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTextField(
                      controller: nameCtrl,
                      label: 'Full Name',
                      hint: 'Enter user full name',
                      isRequired: true,
                      prefixIcon: const Icon(Icons.person),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: emailCtrl,
                      label: 'Email / Username',
                      hint: 'user@quickfix.local or standard email',
                      isRequired: true,
                      prefixIcon: const Icon(Icons.email),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Email is required';
                        if (!Constants.isValidEmail(v.trim())) return 'Invalid email format';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    CustomTextField(
                      controller: phoneCtrl,
                      label: 'Phone Number',
                      hint: 'Enter phone number (optional)',
                      prefixIcon: const Icon(Icons.phone),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    CustomDropdown<String>(
                      value: selectedRole,
                      label: 'Role',
                      isRequired: true,
                      enabled: !isSelf, // Cannot change own role to prevent lockout
                      prefixIcon: const Icon(Icons.admin_panel_settings),
                      items: Constants.roleList.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(Constants.getRoleDisplay(role)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedRole = val;
                          });
                        }
                      },
                      helperText: isSelf ? 'You cannot modify your own role' : null,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: isActive,
                      title: const Text('Active Status'),
                      subtitle: Text(isActive ? 'User can log in and access system' : 'User access is blocked'),
                      contentPadding: EdgeInsets.zero,
                      activeThumbColor: AppColors.primary,
                      onChanged: isSelf
                          ? null // Cannot deactivate self
                          : (val) {
                              setStateDialog(() {
                                isActive = val;
                              });
                            },
                    ),
                    const SizedBox(height: 12),
                    CustomTextFields.password(
                      label: 'Assign New Password',
                      controller: passCtrl,
                      obscureText: obscurePassword,
                      onToggleVisibility: () => setStateDialog(() {
                        obscurePassword = !obscurePassword;
                      }),
                      isRequired: false,
                      hint: 'Leave blank to keep current password',
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Account Reset Options',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    CustomButton(
                      text: 'Send Password Reset Email',
                      onPressed: isSaving
                          ? null
                          : () async {
                              setStateDialog(() => isSaving = true);
                              final authProvider = context.read<AuthProvider>();
                              final success = await authProvider.resetPassword(user.email);
                              setStateDialog(() => isSaving = false);
                              if (!context.mounted) return;
                              if (success) {
                                Helpers.showSuccess(context, 'Reset link sent to ${user.email}');
                              } else {
                                Helpers.showError(
                                  context,
                                  authProvider.errorMessage ?? 'Failed to send reset email',
                                );
                              }
                            },
                      icon: Icons.send_and_archive,
                      variant: ButtonVariant.outlined,
                      size: ButtonSize.small,
                      fullWidth: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setStateDialog(() => isSaving = true);

                      final authProvider = context.read<AuthProvider>();
                      final success = await authProvider.updateUser(
                        userId: user.id,
                        name: nameCtrl.text.trim(),
                        email: emailCtrl.text.trim(),
                        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        role: isSelf ? null : selectedRole, // Don't send role update if editing self
                        isActive: isSelf ? null : isActive, // Don't deactivate self
                      );

                      bool passwordSuccess = true;
                      if (success && passCtrl.text.isNotEmpty) {
                        passwordSuccess = await authProvider.updateUserPassword(
                          userId: user.id,
                          newPassword: passCtrl.text,
                        );
                      }

                      setStateDialog(() => isSaving = false);

                      if (!context.mounted) return;

                      if (success && passwordSuccess) {
                        Navigator.pop(context);
                        Helpers.showSuccess(context, 'User updated successfully!');
                        _refreshUsers();
                      } else {
                        Helpers.showError(
                          context,
                          authProvider.errorMessage ?? 'Failed to update user',
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteUserDialog(User user) {
    bool isDeleting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              SizedBox(width: 10),
              Text('Delete User', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text('Are you sure you want to delete ${user.name}? This action cannot be undone.'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setStateDialog(() => isDeleting = true);

                      final authProvider = context.read<AuthProvider>();
                      final success = await authProvider.deleteUser(user.id);

                      setStateDialog(() => isDeleting = false);

                      if (!context.mounted) return;

                      if (success) {
                        Navigator.pop(context);
                        Helpers.showSuccess(context, 'User deleted successfully!');
                        _refreshUsers();
                      } else {
                        Helpers.showError(
                          context,
                          authProvider.errorMessage ?? 'Failed to delete user',
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStartingQuoteNumberDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVal = prefs.getString('start_quote_number') ?? '010A';
    final controller = TextEditingController(text: currentVal);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Starting Quote Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the starting sequence number (e.g. 010A). Must match 3 digits followed by an uppercase letter.',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: controller,
                label: 'Start Number',
                hint: '010A',
                prefixIcon: const Icon(Icons.numbers),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final val = controller.text.trim().toUpperCase();
                final regex = RegExp(r'^\d{3}[A-Z]$');
                if (!regex.hasMatch(val)) {
                  Helpers.showError(context, 'Invalid format. Must be e.g. 010A');
                  return;
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('start_quote_number', val);
                if (context.mounted) {
                  Navigator.pop(context);
                  Helpers.showSuccess(context, 'Starting quote number updated to $val');
                }
                if (mounted) {
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showStartingInvoiceNumberDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final currentVal = prefs.getString('start_invoice_number') ?? 'QPN00001';
    final controller = TextEditingController(text: currentVal);
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Starting Invoice Number'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the starting invoice number (e.g. QPN00001). Must start with QPN followed by 5 digits.',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: controller,
                label: 'Start Number',
                hint: 'QPN00001',
                prefixIcon: const Icon(Icons.numbers),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final val = controller.text.trim().toUpperCase();
                final regex = RegExp(r'^QPN\d{5}$');
                if (!regex.hasMatch(val)) {
                  Helpers.showError(context, 'Invalid format. Must be e.g. QPN00001');
                  return;
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('start_invoice_number', val);
                if (context.mounted) {
                  Navigator.pop(context);
                  Helpers.showSuccess(context, 'Starting invoice number updated to $val');
                }
                if (mounted) {
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showRenumberConfirmationDialog() {
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 10),
              Text('Renumber Records', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Are you sure you want to renumber all existing quotes and invoices in chronological order starting from the configured values? This will update local and Supabase numbers.',
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: isProcessing ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      setStateDialog(() => isProcessing = true);
                      
                      try {
                        final dbService = DatabaseService();
                        await dbService.forceRenumberAllRecords();
                        
                        setStateDialog(() => isProcessing = false);
                        if (!context.mounted) return;
                        
                        Navigator.pop(context);
                        Helpers.showSuccess(context, 'All records renumbered successfully!');
                        
                        // Force refresh lists on next view
                        try {
                          context.read<QuoteProvider>().refreshQuotes();
                        } catch (_) {}
                        try {
                          context.read<InvoiceProvider>().refreshInvoices();
                        } catch (_) {}
                      } catch (e) {
                        setStateDialog(() => isProcessing = false);
                        if (!context.mounted) return;
                        Helpers.showError(context, 'Failed to renumber records: $e');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Renumber'),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductionResetConfirmationDialog() {
    final textController = TextEditingController();
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                  SizedBox(width: 10),
                  Text('Reset System for Production', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This action will permanently delete all test & development data, including:\n'
                      '• All Quotes & Quote Items\n'
                      '• All Invoices & Payments\n'
                      '• All Customers & Sites\n'
                      '• All Products & Inventory\n'
                      '• All Non-Admin Users\n\n'
                      'Your Admin user credentials will be preserved.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Type "RESET" to confirm:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'RESET',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: (textController.text.trim() == 'RESET' && !isProcessing)
                      ? () async {
                          setDialogState(() {
                            isProcessing = true;
                          });

                          try {
                            await DatabaseService().resetSystemForProduction();

                            if (context.mounted) {
                              final quoteProv = context.read<QuoteProvider>();
                              final invoiceProv = context.read<InvoiceProvider>();
                              final customerProv = context.read<CustomerProvider>();
                              final productProv = context.read<ProductProvider>();

                              try {
                                await quoteProv.loadQuotes();
                              } catch (_) {}
                              try {
                                await invoiceProv.loadInvoices();
                              } catch (_) {}
                              try {
                                await customerProv.loadCustomers();
                              } catch (_) {}
                              try {
                                await productProv.loadProducts();
                              } catch (_) {}
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              Helpers.showSuccess(
                                context,
                                'System successfully reset for production! Admin accounts preserved.',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() {
                                isProcessing = false;
                              });
                              Helpers.showError(context, 'Failed to reset system: $e');
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Confirm Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHelpAndSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.support_agent, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quantyx Labs Support Team',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Developer: Quantyx Labs, Nairobi Kenya',
                style: TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'info@quantyx.co.ke',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(const ClipboardData(text: 'info@quantyx.co.ke'));
                        Helpers.showSuccess(context, 'Support email copied!');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Copy',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'System Guidance & Support Services:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                '• System Activation & Licensing: For trial renewals or key activations, contact info@quantyx.co.ke.\n'
                '• Quotation & Invoicing: Create, manage, and print quotes/invoices with custom QR code validation.\n'
                '• Offline & Cloud Sync: Automatic local SQLite storage and Supabase cloud synchronization.\n'
                '• Developer Contact: Email info@quantyx.co.ke for software customization or technical support.',
                style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.text),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.privacy_tip_outlined, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Quantyx Labs • Quickfix Plumbers', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Privacy Policy & Data Handling',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  'Developer: Quantyx Labs, Nairobi Kenya\nSupport: info@quantyx.co.ke\n\n'
                  '1. Information Collection & Use\n'
                  'Quickfix Plumbers Management System stores customer profiles, site addresses, product inventory rates, quotation records, and invoice transactions essential for business operations.\n\n'
                  '2. Storage & Security\n'
                  'Data is saved in local offline SQLite database tables and synchronized securely with Supabase cloud infrastructure. Quantyx Labs applies encrypted protocols for database communications.\n\n'
                  '3. Data Ownership & Privacy\n'
                  'All customer and transactional data remains the exclusive property of Quickfix Plumbers. Quantyx Labs does not monetize or share your business data with third parties.\n\n'
                  '4. Licensing Verification\n'
                  'Encrypted activation metadata is checked locally to enforce trial and subscription licensing periods.\n\n'
                  '5. Support & Contact\n'
                  'For privacy inquiries or technical support, contact Quantyx Labs at info@quantyx.co.ke.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTermsOfServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.description_outlined, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Quantyx Labs • Quickfix Plumbers', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Software Licensing & Terms of Service',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  'Developer: Quantyx Labs, Nairobi Kenya\nSupport: info@quantyx.co.ke\n\n'
                  '1. Software License Grant\n'
                  'Quantyx Labs grants Quickfix Plumbers a non-exclusive license to operate the Quickfix Plumbers Management System for managing plumbing operations, quotes, invoices, inventory, and field staff.\n\n'
                  '2. System Activation Keys\n'
                  'System activation relies on authentic keys issued by Quantyx Labs. Software usage transitions from a 14-day trial to an annual subscription model.\n\n'
                  '3. Acceptable Use\n'
                  'Users agree to utilize the software in compliance with all relevant commercial regulations in Kenya. Unauthorized redistribution or reverse engineering is prohibited.\n\n'
                  '4. Limitation of Liability\n'
                  'Quantyx Labs provides the management system to streamline plumbing workflows. Businesses remain responsible for accurate pricing and customer agreements.\n\n'
                  '5. Support Services\n'
                  'For system support, updates, or licensing extensions, contact Quantyx Labs at info@quantyx.co.ke.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
