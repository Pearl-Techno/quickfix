import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../../config/app_colors.dart';
import '../../providers/customer_provider.dart';
import '../../providers/quote_provider.dart';
import '../../models/customer.dart';
import '../../models/quote.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/custom_dropdown.dart';
import '../../widgets/sidebar_menu.dart';
import '../../services/pdf_service.dart';
import '../../utils/helpers.dart';
import '../../utils/formatters.dart';

class SiteMeasurements extends StatefulWidget {
  final String? initialQuoteId;

  const SiteMeasurements({super.key, this.initialQuoteId});

  @override
  State<SiteMeasurements> createState() => _SiteMeasurementsState();
}

class _SiteMeasurementsState extends State<SiteMeasurements>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _measurementsController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  late TabController _tabController;
  Customer? _selectedCustomer;
  Quote? _selectedQuote;
  List<Quote> _customerQuotes = [];
  bool _isSubmitting = false;
  bool _isLoading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _measurementsController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final customerProvider = context.read<CustomerProvider>();
    final quoteProvider = context.read<QuoteProvider>();

    await Future.wait([
      customerProvider.loadCustomers(),
      quoteProvider.loadQuotes(),
    ]);

    if (widget.initialQuoteId != null) {
      final quote = quoteProvider.quotes.firstWhere(
        (q) => q.id == widget.initialQuoteId,
        orElse: () => Quote.empty(),
      );
      if (quote.id.isNotEmpty) {
        final customer = customerProvider.customers.firstWhere(
          (c) => c.id == quote.customerId,
          orElse: () => Customer(id: '', name: 'Customer'),
        );
        _selectQuoteForEdit(quote, customer);
      }
    }

    setState(() => _isLoading = false);
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

  void _selectQuoteForEdit(Quote quote, Customer? customer) {
    final customerProvider = context.read<CustomerProvider>();
    final cust = customer ??
        customerProvider.customers.firstWhere(
          (c) => c.id == quote.customerId,
          orElse: () => Customer(id: quote.customerId, name: quote.customerName ?? 'Customer'),
        );

    setState(() {
      _selectedCustomer = cust;
      _loadCustomerQuotes(cust.id);
      _selectedQuote = quote;
      _measurementsController.text = quote.siteMeasurements ?? '';
      _notesController.text = quote.notes ?? '';
    });

    _tabController.animateTo(1);
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
      Helpers.showSuccess(context, 'Site measurements saved successfully');
      _loadData();
      _tabController.animateTo(0);
    } else {
      Helpers.showError(
        context,
        quoteProvider.errorMessage ?? 'Failed to save measurements',
      );
    }
  }

  Future<void> _exportMeasurementPDF(Quote quote) async {
    final customerProvider = context.read<CustomerProvider>();
    final customer = customerProvider.customers.firstWhere(
      (c) => c.id == quote.customerId,
      orElse: () => Customer(id: quote.customerId, name: quote.customerName ?? 'Customer'),
    );

    try {
      final pdfService = PdfService();
      final file = await pdfService.generateSiteMeasurementPdf(
        quote: quote,
        customer: customer,
      );

      if (!mounted) return;

      await Printing.layoutPdf(
        onLayout: (format) async => file.readAsBytes(),
        name: 'site_measurements_${quote.quoteNumber}',
      );
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to generate PDF: $e');
      }
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.rule_folder_outlined),
              text: 'Recorded Measurements',
            ),
            Tab(
              icon: Icon(Icons.edit_document),
              text: 'Record / Edit Measurement',
            ),
          ],
        ),
      ),
      drawer: const SidebarMenu(selectedIndex: 6),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecordedMeasurementsTab(),
          _buildRecordEditFormTab(),
        ],
      ),
    );
  }

  // ============================================
  // TAB 1: RECORDED MEASUREMENTS LIST
  // ============================================

  Widget _buildRecordedMeasurementsTab() {
    final quoteProvider = context.watch<QuoteProvider>();
    final customerProvider = context.watch<CustomerProvider>();

    final quotesWithMeasurements = quoteProvider.quotes
        .where((q) => q.hasSiteMeasurements)
        .where((q) {
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          final qNum = q.quoteNumber.toLowerCase();
          final cName = (q.customerName ?? '').toLowerCase();
          final mText = (q.siteMeasurements ?? '').toLowerCase();
          return qNum.contains(query) || cName.contains(query) || mText.contains(query);
        })
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMetricsHeader(quoteProvider.quotes),
            const SizedBox(height: 16),
            _buildSearchAndFilterBar(),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (quotesWithMeasurements.isEmpty)
              _buildEmptyMeasurementsState()
            else
              Column(
                children: quotesWithMeasurements.map((quote) {
                  final customer = customerProvider.customers.firstWhere(
                    (c) => c.id == quote.customerId,
                    orElse: () => Customer(id: quote.customerId, name: quote.customerName ?? 'Customer'),
                  );
                  return _buildMeasurementCard(quote, customer);
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsHeader(List<Quote> allQuotes) {
    final recordedCount = allQuotes.where((q) => q.hasSiteMeasurements).length;
    final totalQuotesCount = allQuotes.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.info.withValues(alpha: 0.12),
            AppColors.info.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.straighten,
              color: AppColors.info,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Site Surveys & Measurements Dashboard',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$recordedCount of $totalQuotesCount quotations have site measurements attached.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value.trim();
        });
      },
      decoration: InputDecoration(
        hintText: 'Search site measurements by customer, quote #, or text...',
        prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, color: AppColors.textLight),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildEmptyMeasurementsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(Icons.straighten_outlined, size: 64, color: AppColors.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'No Site Measurements Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'There are no recorded site measurements matching your search.',
            style: TextStyle(color: AppColors.textLight, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(1),
            icon: const Icon(Icons.add),
            label: const Text('Record New Measurements'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementCard(Quote quote, Customer customer) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Quote ${quote.quoteNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDate(quote.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: AppColors.textLight),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${quote.customerName ?? customer.name}${customer.phone != null ? " • 📞 ${customer.phone}" : ""}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
            ),
            child: SelectableText(
              quote.siteMeasurements!,
              style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.text),
            ),
          ),
          if (quote.notes != null && quote.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Notes: ${quote.notes}',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/admin/quotes/${quote.id}');
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 14),
                      label: const Text('View Quote'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _exportMeasurementPDF(quote),
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('Separate PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _selectQuoteForEdit(quote, customer),
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.info,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // TAB 2: RECORD / EDIT MEASUREMENTS FORM
  // ============================================

  Widget _buildRecordEditFormTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormHeader(),
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
    );
  }

  Widget _buildFormHeader() {
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
              Icons.edit_note,
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
                  'Record & Update Site Measurements',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Select a quotation and input exact field measurements and notes.',
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
                child: Text('${quote.quoteNumber} (${Formatters.currency(quote.effectiveTotal)})'),
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
            hint: 'Enter dimensions, site conditions, pipe lengths, room sizes...',
            maxLines: 4,
            isRequired: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter site measurements';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _notesController,
            label: 'Additional Field Notes',
            hint: 'Any other site observations (optional)',
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
          _buildTipItem('📏 Measure pipe lengths and diameters accurately'),
          _buildTipItem('🔧 Note any special fittings or adapters required'),
          _buildTipItem('📸 Take photos of the site area for documentation'),
          _buildTipItem('📝 Record any site access or pressure issues'),
          _buildTipItem('⚠️ Note safety concerns or structural constraints'),
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
            onPressed: () => _tabController.animateTo(0),
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
          onPressed: () => _tabController.animateTo(0),
          isOutlined: true,
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
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
