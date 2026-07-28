import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/customer_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/helpers.dart';
import '../../utils/validators.dart';

class AddCustomerScreen extends StatefulWidget {
  const AddCustomerScreen({super.key});

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _siteLocationController = TextEditingController();
  final _siteNotesController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _showSummary = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _siteLocationController.dispose();
    _siteNotesController.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (!_formKey.currentState!.validate()) {
      _showValidationError();
      return;
    }

    setState(() => _isSubmitting = true);

    final provider = context.read<CustomerProvider>();
    final success = await provider.addCustomer(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      siteLocation: _siteLocationController.text.trim().isEmpty
          ? null
          : _siteLocationController.text.trim(),
      siteNotes: _siteNotesController.text.trim().isEmpty
          ? null
          : _siteNotesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      Helpers.showSuccess(context, 'Customer added successfully!');
      Navigator.pop(context);
    } else {
      Helpers.showError(
        context,
        provider.errorMessage ?? 'Failed to add customer',
      );
    }
  }

  void _showValidationError() {
    Helpers.showSnackBar(
      context,
      'Please fill in all required fields',
      backgroundColor: AppColors.error,
    );
  }

  void _toggleSummary() {
    setState(() {
      _showSummary = !_showSummary;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    if (isWide)
                      _buildWideLayout()
                    else
                      _buildNarrowLayout(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================
  // LAYOUTS
  // ============================================

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (flex: 2)
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPersonalInfoCard(isWide: true),
              const SizedBox(height: 16),
              _buildAddressInfoCard(),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Right Column (flex: 1)
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSiteInfoCard(isWide: true),
              const SizedBox(height: 16),
              _buildNotesCard(),
              const SizedBox(height: 16),
              if (_showSummary) ...[
                _buildSummaryCard(),
                const SizedBox(height: 16),
              ],
              _buildActionCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPersonalInfoCard(isWide: false),
        const SizedBox(height: 16),
        _buildAddressInfoCard(),
        const SizedBox(height: 16),
        _buildSiteInfoCard(isWide: false),
        const SizedBox(height: 16),
        _buildNotesCard(),
        const SizedBox(height: 16),
        if (_showSummary) ...[
          _buildSummaryCard(),
          const SizedBox(height: 16),
        ],
        _buildActionButtons(),
      ],
    );
  }

  // ============================================
  // DRAWER
  // ============================================

  Widget _buildDrawer() {
    return const SidebarMenu(
      selectedIndex: 2,
    );
  }

  // ============================================
  // APP BAR
  // ============================================

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_add_alt_1,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Add Customer',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      elevation: 0,
      actions: [
        IconButton(
          icon: Icon(
            _showSummary ? Icons.visibility_off : Icons.visibility,
            color: Colors.white,
          ),
          onPressed: _toggleSummary,
          tooltip: _showSummary ? 'Hide Summary' : 'Show Summary',
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 36,
          child: TextButton(
            onPressed: _isSubmitting ? null : _saveCustomer,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(60, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
          ),
        ),
      ],
    );
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
              Icons.person_add_alt_1,
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
                  'Add New Customer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Fill in the details below to add a new customer',
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
  // PERSONAL INFO CARD
  // ============================================

  Widget _buildPersonalInfoCard({required bool isWide}) {
    final nameField = CustomTextField(
      controller: _nameController,
      label: 'Full Name *',
      hint: 'Enter customer name',
      prefixIcon: const Icon(Icons.person_outline, size: 20),
      validator: Validators.name,
    );

    final phoneField = CustomTextField(
      controller: _phoneController,
      label: 'Phone Number',
      hint: 'Enter phone number',
      keyboardType: TextInputType.phone,
      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
      validator: Validators.phone,
    );

    final emailField = CustomTextField(
      controller: _emailController,
      label: 'Email Address',
      hint: 'Enter email (optional)',
      keyboardType: TextInputType.emailAddress,
      prefixIcon: const Icon(Icons.email_outlined, size: 20),
      validator: Validators.email,
    );

    return _buildCard(
      title: 'Personal Information',
      icon: Icons.person_outline,
      iconColor: AppColors.primary,
      tag: 'Required',
      tagColor: AppColors.primary,
      child: Column(
        children: [
          nameField,
          const SizedBox(height: 16),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: phoneField),
                const SizedBox(width: 16),
                Expanded(child: emailField),
              ],
            )
          else ...[
            phoneField,
            const SizedBox(height: 16),
            emailField,
          ],
        ],
      ),
    );
  }

  // ============================================
  // ADDRESS INFO CARD
  // ============================================

  Widget _buildAddressInfoCard() {
    return _buildCard(
      title: 'Address Information',
      icon: Icons.location_on_outlined,
      iconColor: AppColors.info,
      tag: 'Optional',
      tagColor: AppColors.info,
      child: Column(
        children: [
          CustomTextField(
            controller: _addressController,
            label: 'Address',
            hint: 'Enter address (optional)',
            maxLines: 2,
            prefixIcon: const Icon(Icons.home_outlined, size: 20),
          ),
        ],
      ),
    );
  }

  // ============================================
  // SITE INFO CARD
  // ============================================

  Widget _buildSiteInfoCard({required bool isWide}) {
    final locationField = CustomTextField(
      controller: _siteLocationController,
      label: 'Site Location',
      hint: 'Enter site location',
      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
    );

    final notesField = CustomTextField(
      controller: _siteNotesController,
      label: 'Site Notes',
      hint: 'Enter any site notes',
      maxLines: 3,
      prefixIcon: const Icon(Icons.note_outlined, size: 20),
    );

    return _buildCard(
      title: 'Site Information',
      icon: Icons.build_outlined,
      iconColor: AppColors.warning,
      tag: 'Optional',
      tagColor: AppColors.warning,
      child: Column(
        children: [
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: locationField),
                const SizedBox(width: 16),
                Expanded(child: notesField),
              ],
            )
          else ...[
            locationField,
            const SizedBox(height: 16),
            notesField,
          ],
        ],
      ),
    );
  }

  // ============================================
  // NOTES CARD
  // ============================================

  Widget _buildNotesCard() {
    return _buildCard(
      title: 'Additional Notes',
      icon: Icons.note_add_outlined,
      iconColor: AppColors.secondary,
      tag: 'Optional',
      tagColor: AppColors.secondary,
      child: Column(
        children: [
          CustomTextField(
            controller: _notesController,
            label: 'Notes',
            hint: 'Add any additional notes about the customer',
            maxLines: 3,
            prefixIcon: const Icon(Icons.note_outlined, size: 20),
          ),
        ],
      ),
    );
  }

  // ============================================
  // CARD WIDGET
  // ============================================

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String tag,
    required Color tagColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 18, color: iconColor),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tagColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  // ============================================
  // SUMMARY CARD
  // ============================================

  Widget _buildSummaryCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.08),
            AppColors.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text(
                'Customer Summary',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Preview',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Name', _nameController.text),
          _buildSummaryRow('Phone', _phoneController.text),
          _buildSummaryRow('Email', _emailController.text),
          _buildSummaryRow('Address', _addressController.text),
          _buildSummaryRow('Site Location', _siteLocationController.text),
          _buildSummaryRow('Notes', _notesController.text),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isEmpty ? 'Not set' : value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isEmpty ? AppColors.textLight : AppColors.text,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ACTION BUTTONS
  // ============================================

  Widget _buildActionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.settings, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              const Text(
                'Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          CustomButton(
            text: _isSubmitting ? 'Saving...' : 'Add Customer',
            onPressed: _isSubmitting ? null : _saveCustomer,
            icon: _isSubmitting ? null : Icons.save,
            isLoading: _isSubmitting,
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
            isOutlined: true,
            variant: ButtonVariant.outlined,
            size: ButtonSize.large,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: CustomButton(
            text: _isSubmitting ? 'Saving...' : 'Add Customer',
            onPressed: _isSubmitting ? null : _saveCustomer,
            icon: _isSubmitting ? null : Icons.save,
            isLoading: _isSubmitting,
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 1,
          child: CustomButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
            isOutlined: true,
            variant: ButtonVariant.outlined,
            size: ButtonSize.large,
          ),
        ),
      ],
    );
  }

  // ============================================
  // CARD DECORATION
  // ============================================

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
