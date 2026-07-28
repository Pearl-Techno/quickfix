import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../providers/quote_provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/quote.dart';
import '../../models/quote_item.dart';
import '../../models/customer.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/sidebar_menu.dart';
import '../../widgets/loading_spinner.dart';
import '../../services/pdf_service.dart';
import '../../utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';

class QuoteDetailsScreen extends StatefulWidget {
  final String quoteId;

  const QuoteDetailsScreen({super.key, required this.quoteId});

  @override
  State<QuoteDetailsScreen> createState() => _QuoteDetailsScreenState();
}

class _QuoteDetailsScreenState extends State<QuoteDetailsScreen>
    with SingleTickerProviderStateMixin {
  Quote? _quote;
  Customer? _customer;
  bool _isLoading = true;
  bool _isExporting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _preparedByName;

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
      _loadQuote();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    setState(() => _isLoading = true);

    final quoteProvider = context.read<QuoteProvider>();
    final customerProvider = context.read<CustomerProvider>();

    await customerProvider.loadCustomers();
    final quote = await quoteProvider.getQuote(widget.quoteId);

    if (mounted) {
      setState(() {
        _quote = quote;
        if (quote != null) {
          _customer = customerProvider.customers.firstWhere(
            (c) => c.id == quote.customerId,
            orElse: () => Customer(
              id: quote.customerId,
              name: quote.customerName ?? 'Unknown Customer',
            ),
          );
        }
      });
      if (quote != null) {
        _loadPreparedByName(quote.userId);
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPreparedByName(String? userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (mounted) {
      setState(() {
        _preparedByName = authProvider.currentUser?.name;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    final provider = context.read<QuoteProvider>();
    final updated = await provider.updateQuoteStatus(widget.quoteId, status);

    if (mounted && updated != null) {
      setState(() {
        _quote = updated;
      });
      Helpers.showSuccess(context, 'Quote ${status.toUpperCase()}');
    }
  }

  Future<void> _convertToInvoice() async {
    // Capture the quote ID before the async gap
    final quoteId = widget.quoteId;
    final provider = context.read<QuoteProvider>();
    final invoice = await provider.convertQuoteToInvoice(quoteId);

    if (!mounted) return;

    if (invoice != null) {
      Helpers.showSuccess(context, 'Invoice created successfully');
      await _loadQuote();
      if (mounted) {
        Navigator.pushNamed(context, '/admin/invoices/${invoice.id}');
      }
    } else {
      Helpers.showError(
        context,
        provider.errorMessage ?? 'Failed to convert to invoice',
      );
    }
  }

  Future<void> _exportQuotePDF() async {
    if (_quote == null || _customer == null) return;

    setState(() => _isExporting = true);

    try {
      final pdfService = PdfService();

      final List<QuoteItem> items = _quote!.items ?? [];
      final file = await pdfService.generateQuotePdf(
        quote: _quote!,
        customer: _customer!,
        items: items,
        preparedBy: _preparedByName,
      );

      setState(() => _isExporting = false);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuotePreviewPage(
            pdfFile: file,
            quote: _quote!,
            customer: _customer!,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to generate PDF: $e');
      }
    }
  }

  Future<void> _shareQuote() async {
    if (_quote == null || _customer == null) return;

    setState(() => _isExporting = true);

    try {
      final pdfService = PdfService();

      final List<QuoteItem> items = _quote!.items ?? [];

      final file = await pdfService.generateQuotePdf(
        quote: _quote!,
        customer: _customer!,
        items: items,
        preparedBy: _preparedByName,
      );

      setState(() => _isExporting = false);

      if (!mounted) return;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${_quote!.quoteNumber}.pdf');
      await tempFile.writeAsBytes(await file.readAsBytes());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Quote ${_quote!.quoteNumber} - ${_customer!.name}',
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to share quote: $e');
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${monthNames[date.month - 1]} ${date.year}';
  }

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quote Details')),
        body: const Center(child: LoadingSpinner(message: 'Loading quote...')),
      );
    }

    if (_quote == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quote Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Quote not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The quote you are looking for does not exist.',
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Back to Quotes',
                onPressed: () => Navigator.pop(context),
                isOutlined: true,
                variant: ButtonVariant.outlined,
                size: ButtonSize.medium,
              ),
            ],
          ),
        ),
      );
    }

    final quote = _quote!;
    final items = quote.items ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          quote.quoteNumber,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share_outlined),
            onPressed: _isExporting ? null : _shareQuote,
            tooltip: 'Share',
          ),
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf),
            onPressed: _isExporting ? null : _exportQuotePDF,
            tooltip: 'Export PDF',
          ),
        ],
      ),
      drawer: const SidebarMenu(
        selectedIndex: 1,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(quote),
              const SizedBox(height: 12),
              _buildActionToolbar(quote),
              const SizedBox(height: 16),
              _buildCustomerCard(quote),
              if (quote.scope != null && quote.scope!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildScopeCard(quote),
              ],
              const SizedBox(height: 16),
              _buildItemsSection(quote, items),
              const SizedBox(height: 16),
              _buildTotalsCard(quote),
              if (quote.notes != null || quote.siteMeasurements != null)
                _buildNotesCard(quote),
              const SizedBox(height: 16),
              _buildPreparedBySection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(Quote quote) {
    final statusColor = Helpers.getStatusColor(quote.status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.08),
            statusColor.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Helpers.getStatusIcon(quote.status),
              color: statusColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: ${quote.displayStatus}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: statusColor,
                  ),
                ),
                Text(
                  'Created: ${_formatDate(quote.createdAt)}',
                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                ),
                if (quote.validityDays > 0)
                  Text(
                    'Valid for ${quote.validityDays} days',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              quote.displayStatus,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(Quote quote) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                'Customer Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 20),
          if (_customer != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    Helpers.getInitials(_customer!.name),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customer!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (_customer!.phone != null)
                        Text(
                          '📞 ${_customer!.phone}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                      if (_customer!.email != null)
                        Text(
                          '📧 ${_customer!.email}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              quote.customerName ?? 'Unknown Customer',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScopeCard(Quote quote) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
                  Icons.work_outline,
                  size: 18,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Scope of Works / Service',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            quote.scope ?? '',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(Quote quote, List<QuoteItem> items) {
    final groupedItems = <String, List<QuoteItem>>{};
    for (var item in items) {
      final section = item.section ?? 'Uncategorized';
      if (!groupedItems.containsKey(section)) {
        groupedItems[section] = [];
      }
      groupedItems[section]!.add(item);
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                  Icons.list,
                  size: 18,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Items (${items.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          if (items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No items in this quote',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3.8), // Item
                    1: FlexColumnWidth(1.0), // Qty
                    2: FlexColumnWidth(2.0), // Price
                    3: FlexColumnWidth(2.2), // Discount
                    4: FlexColumnWidth(2.0), // Total
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.2),
                      width: 1,
                    ),
                    verticalInside: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(color: AppColors.primary),
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            'Item',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            'Qty',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            'Price',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            'Discount',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Text(
                            'Total',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    for (var entry in groupedItems.entries) ...[
                      // Section row
                      TableRow(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                        ),
                        children: [
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                entry.key.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          TableCell(
                            verticalAlignment: TableCellVerticalAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Text(
                                'Total: ${_formatCurrency(entry.value.fold(0.0, (sum, item) => sum + item.total))}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Item rows in this section
                      for (var item in entry.value)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                item.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  item.quantity.toString(),
                                  style: const TextStyle(fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  _formatCurrency(item.unitPrice),
                                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  item.discount > 0
                                      ? '${_formatCurrency(item.discount)} (${item.discountPercentage.toStringAsFixed(0)}%)'
                                      : 'KSh 0.00',
                                  style: TextStyle(fontSize: 13, color: AppColors.textLight),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment: TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  _formatCurrency(item.total),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPreparedBySection() {
    final dateTimeStr = _quote?.createdAt != null ? Formatters.dateTime(_quote!.createdAt) : 'N/A';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.primary),
              const SizedBox(width: 12),
              const Text(
                'Served By: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textLight,
                ),
              ),
              Text(
                _preparedByName ?? 'N/A',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.access_time, size: 16, color: AppColors.textLight),
              const SizedBox(width: 6),
              Text(
                dateTimeStr,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsCard(Quote quote) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.05),
            AppColors.primary.withValues(alpha: 0.01),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTotalsRow('Subtotal', _formatCurrency(quote.subtotal)),
          if (quote.tax > 0) ...[
            const SizedBox(height: 4),
            _buildTotalsRow(
              'Tax (${(Constants.taxRate * 100).toInt()}%)',
              _formatCurrency(quote.tax),
            ),
          ],
          if (quote.discount > 0)
            _buildTotalsRow('Discount', _formatCurrency(quote.discount)),
          const Divider(height: 20),
          _buildTotalsRow(
            'Total',
            _formatCurrency(quote.grandTotal),
            isBold: true,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(Quote quote) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                  Icons.note,
                  size: 18,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Additional Notes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Divider(height: 20),
          if (quote.notes != null) ...[
            Text(quote.notes!, style: const TextStyle(fontSize: 14)),
          ],
          if (quote.siteMeasurements != null) ...[
            if (quote.notes != null) const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten, size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Site Measurements: ${quote.siteMeasurements}',
                      style: TextStyle(fontSize: 13, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionToolbar(Quote quote) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (quote.isDraft) ...[
                _buildSmallActionButton(
                  text: 'Mark as Sent',
                  icon: Icons.send,
                  color: AppColors.success,
                  onPressed: () => _updateStatus(Constants.quoteStatusSent),
                ),
                _buildSmallActionButton(
                  text: 'Edit Quote',
                  icon: Icons.edit,
                  color: AppColors.primary,
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/admin/quotes/edit/${quote.id}',
                    ).then((_) => _loadQuote());
                  },
                ),
              ],
              if (quote.isSent) ...[
                _buildSmallActionButton(
                  text: 'Approve',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  onPressed: () => _updateStatus(Constants.quoteStatusApproved),
                ),
                _buildSmallActionButton(
                  text: 'Reject',
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  onPressed: () => _updateStatus(Constants.quoteStatusRejected),
                ),
              ],
              if (quote.canConvertToInvoice)
                _buildSmallActionButton(
                  text: 'Convert to Invoice',
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.success,
                  onPressed: _convertToInvoice,
                ),
              if (quote.isConverted)
                _buildSmallActionButton(
                  text: 'View Invoice',
                  icon: Icons.description_outlined,
                  color: AppColors.primary,
                  onPressed: () {
                    Navigator.pushNamed(context, '/admin/invoices');
                  },
                ),
              _buildSmallActionButton(
                text: 'Preview PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: AppColors.secondary,
                onPressed: _exportQuotePDF,
              ),
              _buildSmallActionButton(
                text: 'Share',
                icon: Icons.share_outlined,
                color: AppColors.secondary,
                onPressed: _shareQuote,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 18 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isLarge ? AppColors.text : AppColors.textLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 20 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isLarge ? AppColors.primary : AppColors.textLight,
          ),
        ),
      ],
    );
  }

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

// ============================================
// QUOTE PREVIEW PAGE
// ============================================

class QuotePreviewPage extends StatefulWidget {
  final File pdfFile;
  final Quote quote;
  final Customer customer;

  const QuotePreviewPage({
    super.key,
    required this.pdfFile,
    required this.quote,
    required this.customer,
  });

  @override
  State<QuotePreviewPage> createState() => _QuotePreviewPageState();
}

class _QuotePreviewPageState extends State<QuotePreviewPage> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preview: ${widget.quote.quoteNumber}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isPrinting ? null : _downloadQuote,
            tooltip: 'Download',
          ),
          IconButton(
            icon: _isPrinting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.print),
            onPressed: _isPrinting ? null : _printQuote,
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isPrinting ? null : _shareQuote,
            tooltip: 'Share',
          ),
        ],
      ),
      body: PdfPreview(
        build: (context) => widget.pdfFile.readAsBytesSync(),
        allowPrinting: false,
        allowSharing: false,
        maxPageWidth: 700,
        scrollViewDecoration: const BoxDecoration(color: AppColors.background),
        onError: (error, _) {
          if (mounted) {
            Helpers.showError(context, 'Failed to load PDF: $error');
          }
          return const Center(
            child: Text(
              'Failed to load preview',
              style: TextStyle(color: AppColors.textLight),
            ),
          );
        },
        loadingWidget: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading preview...',
                style: TextStyle(color: AppColors.textLight),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printQuote() async {
    setState(() => _isPrinting = true);

    try {
      await Printing.layoutPdf(
        onLayout: (format) => widget.pdfFile.readAsBytesSync(),
        name: '${widget.quote.quoteNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to print: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _shareQuote() async {
    try {
      final bytes = await widget.pdfFile.readAsBytes();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${widget.quote.quoteNumber}.pdf');
      await tempFile.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Quote ${widget.quote.quoteNumber} - ${widget.customer.name}',
        ),
      );
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to share: $e');
      }
    }
  }

  Future<void> _downloadQuote() async {
    setState(() => _isPrinting = true);
    try {
      final file = await Helpers.downloadPdfToLocalDisk(widget.pdfFile, 'quote');
      if (file == null) throw Exception('Failed to write file to local disk');
      if (mounted) {
        Helpers.showSuccess(context, 'Saved to: ${file.path}');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showError(context, 'Failed to download: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }
}
