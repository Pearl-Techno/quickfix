import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../utils/helpers.dart';
import '../../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isSignUp = false;
  final String _selectedRole = Constants.roleTechnician;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final inputVal = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Map username to a valid email format under the hood for Supabase Auth
    final email = inputVal.contains('@') ? inputVal : '$inputVal@quickfix.local';

    bool success;
    if (_isSignUp) {
      success = await authProvider.register(
        email: email,
        password: password,
        name: _nameController.text.trim().isEmpty 
            ? inputVal 
            : _nameController.text.trim(),
        role: _selectedRole,
      );
    } else {
      success = await authProvider.login(
        email,
        password,
      );
    }

    if (!mounted) return;

    if (success) {
      if (_isSignUp) {
        Helpers.showSuccess(context, 'Account created successfully!');
      }
      if (authProvider.isAdmin) {
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
      } else if (authProvider.isTechnician) {
        Navigator.pushReplacementNamed(context, AppRoutes.technicianDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.technicianDashboard);
      }
    } else {
      Helpers.showError(
        context,
        authProvider.errorMessage ?? (_isSignUp ? 'Failed to create account' : 'Invalid email or password'),
      );
    }
  }

  void _fillDemoCredentials(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: size.height * 0.05,
            ),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      const SizedBox(height: 20),

                      // Logo
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 60,
                                spreadRadius: -20,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.plumbing,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Welcome Text
                      Center(
                        child: Column(
                          children: [
                            Text(
                              _isSignUp ? 'Create Account' : 'Welcome Back!',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 28,
                                    color: AppColors.text,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSignUp
                                  ? 'Register to get started with Quickfix Plumbers'
                                  : 'Sign in to continue to Quickfix Plumbers',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textLight,
                                    fontSize: 14,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Name Field (only in Sign Up mode)
                      if (_isSignUp) ...[
                        CustomTextField(
                          controller: _nameController,
                          label: 'Full Name',
                          hint: 'Enter your full name',
                          keyboardType: TextInputType.name,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: AppColors.textLight,
                            size: 20,
                          ),
                          validator: (value) {
                            return Validators.name(value);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Username Field
                      CustomTextField(
                        controller: _emailController,
                        label: 'Username',
                        hint: 'Enter your username or email',
                        keyboardType: TextInputType.text,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        prefixIcon: const Icon(
                          Icons.person_outline,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                        validator: (value) {
                          final requiredError = Validators.required(
                            value,
                            fieldName: 'Username',
                          );
                          if (requiredError != null) return requiredError;
                          if (value!.contains('@')) {
                            return Validators.email(value);
                          }
                          if (value.trim().length < 3) {
                            return 'Username must be at least 3 characters';
                          }
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
                            return 'Username can only contain letters, numbers, and underscores';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        obscureText: _obscurePassword,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.textLight,
                          size: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.textLight,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          final requiredError = Validators.required(
                            value,
                            fieldName: 'Password',
                          );
                          if (requiredError != null) return requiredError;
                          return Validators.password(value);
                        },
                        onFieldSubmitted: (_) => _handleSubmit(),
                      ),



                      // Remember me & Forgot password (only in Sign In mode)
                      if (!_isSignUp) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const Text(
                                  'Remember me',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                Helpers.showSnackBar(
                                  context,
                                  'Password reset link will be sent to your email',
                                  backgroundColor: AppColors.info,
                                );
                              },
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Submit Button
                      CustomButton(
                        text: authProvider.isLoading
                            ? (_isSignUp ? 'Creating account...' : 'Signing in...')
                            : (_isSignUp ? 'Create Account' : 'Sign In'),
                        onPressed: authProvider.isLoading ? null : _handleSubmit,
                        isLoading: authProvider.isLoading,
                        icon: authProvider.isLoading ? null : (_isSignUp ? Icons.person_add : Icons.login),
                        variant: ButtonVariant.primary,
                        size: ButtonSize.large,
                      ),
                      const SizedBox(height: 16),

                      // Toggle Login/Signup Mode Text Button
                      Center(
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              authProvider.clearError();
                            });
                          },
                          style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: Text(
                            _isSignUp
                                ? 'Already have an account? Sign In'
                                : "Don't have an account? Sign Up",
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Error Message
                      if (authProvider.errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  authProvider.errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => authProvider.clearError(),
                                child: const Icon(
                                  Icons.close,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Demo Credentials (only in Sign In mode)
                      if (!_isSignUp) ...[
                        _buildDemoCredentials(),
                        const SizedBox(height: 16),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // DEMO CREDENTIALS
  // ============================================

  Widget _buildDemoCredentials() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 8),
              const Text(
                'Demo Credentials',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Click to fill',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Admin Credentials
          _buildCredentialRow(
            icon: Icons.admin_panel_settings,
            label: 'Admin',
            email: 'admin@quickfix.com',
            password: 'Quickfix@2024',
            color: AppColors.primary,
            onTap: () =>
                _fillDemoCredentials('admin@quickfix.com', 'Quickfix@2024'),
          ),
          const SizedBox(height: 4),

          // Technician Credentials
          _buildCredentialRow(
            icon: Icons.build,
            label: 'Technician',
            email: 'tech@quickfix.com',
            password: 'Tech@2024',
            color: AppColors.secondary,
            onTap: () => _fillDemoCredentials('tech@quickfix.com', 'Tech@2024'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow({
    required IconData icon,
    required String label,
    required String email,
    required String password,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              '$label: ',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            Expanded(
              child: Text(
                email,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.copy, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }
}
