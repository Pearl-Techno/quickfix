import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/customer_provider.dart';
import '../../providers/quote_provider.dart';
import '../../models/customer.dart';
import '../../models/quote.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/sidebar_menu.dart';
import '../../utils/helpers.dart';
import '../../utils/formatters.dart';

class SiteMeasurements extends StatefulWidget {
  const SiteMeasurements({super.key});

  @override
  State<SiteMeasurements> createState() => _SiteMeasurementsState();
}

class _SiteMeasurementsState extends State<SiteMeasurements>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _measurementsController = TextEditingController();
  final _notesController = TextEditingController();

  Customer? _selectedCustomer;
  Quote? _selectedQuote;
  List<Quote> _customerQuotes = [];
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
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
    _measurementsController.dispose();
    _notesController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final customerProvider = context.read<CustomerProvider>();
    final quoteProvider = context.read<QuoteProvider>();
    await Future.wait([
      customerProvider.loadCustomers(),
      quoteProvider.loadQuotes(),
    ]);
  }

  Future<void> _loadCustomerQuotes(String customerId) async {
    final quoteProvider = context.read<QuoteProvider>();
    final allQuotes = quoteProvider.quotes;
    setState(() {
      _customerQuotes = allQuotes
          .where((q) => q.customerId == customerId)
          .toList();
      _selectedQuote = null;
    });
  }

  Future<void> _saveMeasurements() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedQuote == null) {
      Helpers.showError(context, 'Please select a quote');
      return;
    }

    setState(() => _isSubmitting = true);

    final quoteProvider = context.read<QuoteProvider>();
    final updated = await quoteProvider.updateQuote(
      quoteId: _selectedQuote!.id,
      siteMeasurements: _measurementsController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (updated != null) {
      Helpers.showSuccess(context, 'Measurements saved successfully');
      Navigator.pop(context, true);
    } else {
      Helpers.showError(
        context,
        quoteProvider.errorMessage ?? 'Failed to save measurements',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Site Measurements',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 80),
            child: TextButton(
              onPressed: _isSubmitting ? null : _saveMeasurements,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 6,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return _buildWideLayout();
                    } else {
                      return _buildNarrowLayout();
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.info.withValues(alpha: 0.1),
            AppColors.info.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.straighten,
              color: AppColors.info,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Measurements',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Add site measurements and notes',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerCard(),
              if (_selectedCustomer != null) ...[
                const SizedBox(height: 16),
                _buildQuoteCard(),
              ],
              const SizedBox(height: 16),
              _buildMeasurementsCard(),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTipsCard(),
              const SizedBox(height: 16),
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
        _buildCustomerCard(),
        if (_selectedCustomer != null) ...[
          const SizedBox(height: 16),
          _buildQuoteCard(),
        ],
        const SizedBox(height: 16),
        _buildMeasurementsCard(),
        const SizedBox(height: 16),
        _buildTipsCard(),
        const SizedBox(height: 24),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildCustomerCard() {
    final customerProvider = context.watch<CustomerProvider>();

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
                child: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Select Customer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          CustomDropdown<Customer>(
            value: _selectedCustomer,
            label: 'Customer',
            hint: 'Select a customer',
            prefixIcon: const Icon(Icons.person_outline, size: 20),
            isRequired: true,
            items: customerProvider.customers.map((customer) {
              return DropdownMenuItem<Customer>(
                value: customer,
                child: Text(customer.name),
              );
            }).toList(),
            onChanged: (customer) {
              setState(() {
                _selectedCustomer = customer;
                if (customer != null) {
                  _loadCustomerQuotes(customer.id);
                }
              });
            },
            validator: (value) {
              if (value == null) return 'Please select a customer';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard() {
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
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  size: 18,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Select Quote',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          CustomDropdown<Quote>(
            value: _selectedQuote,
            label: 'Quote',
            hint: 'Select a quote',
            prefixIcon: const Icon(Icons.receipt_long, size: 20),
            isRequired: true,
            items: _customerQuotes.map((quote) {
              return DropdownMenuItem<Quote>(
                value: quote,
                child: Text('${quote.quoteNumber} (${Formatters.currency(quote.total)})'),
              );
            }).toList(),
            onChanged: (quote) {
              setState(() {
                _selectedQuote = quote;
                if (quote != null) {
                  _measurementsController.text = quote.siteMeasurements ?? '';
                  _notesController.text = quote.notes ?? '';
                }
              });
            },
            validator: (value) {
              if (value == null) return 'Please select a quote';
              return null;
            },
          ),
          if (_customerQuotes.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No quotes found for this customer',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsCard() {
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
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.straighten,
                  size: 18,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Measurements',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Required',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          CustomTextField(
            controller: _measurementsController,
            label: 'Site Measurements',
            hint: 'Enter dimensions, site conditions, etc.',
            maxLines: 4,
            isRequired: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter measurements';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _notesController,
            label: 'Additional Notes',
            hint: 'Any other observations (optional)',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTipsCard() {
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
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Quick Tips',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildTipItem('📏 Measure pipe lengths and diameters'),
          _buildTipItem('🔧 Note any special fittings required'),
          _buildTipItem('📸 Take photos of the site'),
          _buildTipItem('📝 Record any access challenges'),
          _buildTipItem('⚠️ Note any safety concerns'),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.warning,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }

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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 20),
          CustomButton(
            text: _isSubmitting ? 'Saving...' : 'Save Measurements',
            onPressed: _isSubmitting ? null : _saveMeasurements,
            icon: _isSubmitting ? null : Icons.save,
            isLoading: _isSubmitting,
          ),
          const SizedBox(height: 12),
          CustomButton(
            text: 'Cancel',
            onPressed: () => Navigator.pop(context),
            isOutlined: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        CustomButton(
          text: _isSubmitting ? 'Saving...' : 'Save Measurements',
          onPressed: _isSubmitting ? null : _saveMeasurements,
          icon: _isSubmitting ? null : Icons.save,
          isLoading: _isSubmitting,
        ),
        const SizedBox(height: 12),
        CustomButton(
          text: 'Cancel',
          onPressed: () => Navigator.pop(context),
          isOutlined: true,
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
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
