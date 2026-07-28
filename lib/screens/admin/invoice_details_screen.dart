import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/app_colors.dart';
import '../../config/constants.dart';
import '../../providers/quote_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../../models/invoice.dart';
import '../../models/customer.dart';
import '../../models/quote_item.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_spinner.dart';
import '../../services/pdf_service.dart';
import '../../utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';

class InvoiceDetailsScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailsScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailsScreen> createState() => _InvoiceDetailsScreenState();
}

class _InvoiceDetailsScreenState extends State<InvoiceDetailsScreen>
    with SingleTickerProviderStateMixin {
  Invoice? _invoice;
  Customer? _customer;
  List<QuoteItem> _items = [];
  bool _isLoading = true;
  bool _isExporting = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String? _preparedByName;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoice();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return '${_formatDate(date)} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double amount) {
    return 'KSh ${amount.toStringAsFixed(2)}';
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invoiceProvider = context.read<InvoiceProvider>();
      final customerProvider = context.read<CustomerProvider>();
      final quoteProvider = context.read<QuoteProvider>();

      await invoiceProvider.loadInvoices();
      await customerProvider.loadCustomers();
      await quoteProvider.loadQuotes();

      final invoice = invoiceProvider.allInvoices.firstWhere(
        (inv) => inv.id == widget.invoiceId,
        orElse: () => throw Exception('Invoice not found'),
      );

      final customer = customerProvider.allCustomers.firstWhere(
        (c) => c.id == invoice.customerId,
        orElse: () => Customer(
          id: invoice.customerId,
          name: invoice.customerName ?? 'Unknown Customer',
        ),
      );

      // Get quote items
      List<QuoteItem> items = [];
      String? quoteUserId;
      if (invoice.quoteId.isNotEmpty) {
        final quote = await quoteProvider.getQuote(invoice.quoteId);
        if (quote != null) {
          quoteUserId = quote.userId;
          if (quote.items != null) {
            items = quote.items!;
          }
        }
      }

      if (mounted) {
        setState(() {
          _invoice = invoice;
          _customer = customer;
          _items = items;
        });
        if (quoteUserId != null) {
          _loadPreparedByName(quoteUserId);
        }
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsPaid() async {
    if (_invoice == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: const Text(
          'Are you sure you want to mark this invoice as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.success),
            child: const Text('Yes, Mark as Paid'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    final invoiceProvider = context.read<InvoiceProvider>();
    final success = await invoiceProvider.updatePaymentStatus(
      _invoice!.id,
      Constants.invoiceStatusPaid,
      amountPaid: _invoice!.total,
    );

    if (!mounted) return;

    if (success) {
      Helpers.showSuccess(context, 'Invoice marked as paid successfully');
      await _loadInvoice();
    } else {
      Helpers.showError(
        context,
        invoiceProvider.errorMessage ?? 'Failed to update payment status',
      );
    }
  }

  Future<void> _recordPartialPayment() async {
    if (_invoice == null) return;

    final amountController = TextEditingController();
    final amount = _invoice!.total - _invoice!.amountPaid;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Partial Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Balance Due: ${_formatCurrency(amount)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount Paid',
                hintText: 'Enter amount',
                prefixText: 'KSh ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final paidAmount =
                  double.tryParse(amountController.text.trim()) ?? 0;
              if (paidAmount <= 0) {
                Helpers.showError(context, 'Please enter a valid amount');
                return;
              }
              if (paidAmount > amount) {
                Helpers.showError(context, 'Amount cannot exceed balance due');
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );

    if (result != true) return;

    if (!mounted) return;
    final paidAmount = double.tryParse(amountController.text.trim()) ?? 0;
    final invoiceProvider = context.read<InvoiceProvider>();

    final newStatus = paidAmount >= _invoice!.total
        ? Constants.invoiceStatusPaid
        : Constants.invoiceStatusPartial;

    final success = await invoiceProvider.updatePaymentStatus(
      _invoice!.id,
      newStatus,
      amountPaid: _invoice!.amountPaid + paidAmount,
    );

    if (!mounted) return;

    if (success) {
      Helpers.showSuccess(context, 'Partial payment recorded successfully');
      await _loadInvoice();
    } else {
      Helpers.showError(
        context,
        invoiceProvider.errorMessage ?? 'Failed to record payment',
      );
    }
  }

  // ============================================
  // PDF GENERATION
  // ============================================

  Future<void> _generateAndPrintInvoice() async {
    if (_invoice == null || _customer == null) return;

    setState(() => _isExporting = true);

    try {
      final pdfService = PdfService();
      final file = await pdfService.generateInvoicePdf(
        invoice: _invoice!,
        customer: _customer!,
        items: _items,
        preparedBy: _preparedByName,
      );

      setState(() => _isExporting = false);

      if (!mounted) return;

      await Printing.layoutPdf(
        onLayout: (format) => file.readAsBytesSync(),
        name: '${_invoice!.invoiceNumber}.pdf',
      );
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to print invoice: $e');
      }
    }
  }

  Future<void> _generateAndPreviewInvoice() async {
    if (_invoice == null || _customer == null) return;

    setState(() => _isExporting = true);

    try {
      final pdfService = PdfService();
      final file = await pdfService.generateInvoicePdf(
        invoice: _invoice!,
        customer: _customer!,
        items: _items,
        preparedBy: _preparedByName,
      );

      setState(() => _isExporting = false);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              InvoicePreviewPage(pdfFile: file, invoice: _invoice!),
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to generate preview: $e');
      }
    }
  }

  Future<void> _generateAndPreviewReceipt() async {
    if (_invoice == null || _customer == null) return;

    setState(() => _isExporting = true);

    try {
      final pdfService = PdfService();
      final file = await pdfService.generateInvoiceReceiptPdf(
        invoice: _invoice!,
        customer: _customer!,
        items: _items,
        preparedBy: _preparedByName,
      );

      setState(() => _isExporting = false);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              InvoicePreviewPage(pdfFile: file, invoice: _invoice!, isReceipt: true),
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to generate receipt: $e');
      }
    }
  }

  Future<void> _shareInvoice() async {
    if (_invoice == null || _customer == null) return;

    setState(() => _isExporting = true);

    try {
      final pdfService = PdfService();
      final file = await pdfService.generateInvoicePdf(
        invoice: _invoice!,
        customer: _customer!,
        items: _items,
        preparedBy: _preparedByName,
      );

      setState(() => _isExporting = false);

      if (!mounted) return;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${_invoice!.invoiceNumber}.pdf');
      await tempFile.writeAsBytes(await file.readAsBytes());

      // Use SharePlus with ShareParams
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: 'Invoice ${_invoice!.invoiceNumber} - ${_customer!.name}',
        ),
      );
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to share invoice: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice Details')),
        body: const Center(
          child: LoadingSpinner(message: 'Loading invoice...'),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Error loading invoice',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Try Again',
                onPressed: _loadInvoice,
                icon: Icons.refresh,
                variant: ButtonVariant.primary,
                size: ButtonSize.medium,
              ),
            ],
          ),
        ),
      );
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invoice Details')),
        body: const Center(
          child: Text(
            'Invoice not found',
            style: TextStyle(fontSize: 16, color: AppColors.textLight),
          ),
        ),
      );
    }

    final invoice = _invoice!;
    final customer = _customer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(invoice.invoiceNumber),
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
                : const Icon(Icons.share),
            onPressed: _isExporting ? null : _shareInvoice,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _isExporting ? null : _generateAndPreviewInvoice,
            tooltip: 'Preview',
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _isExporting ? null : _generateAndPrintInvoice,
            tooltip: 'Print',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(invoice),
              const SizedBox(height: 12),
              _buildActionToolbar(invoice),
              const SizedBox(height: 16),

              // Customer Info
              _buildCustomerCard(customer, invoice),
              const SizedBox(height: 16),

              // Invoice Details
              _buildInvoiceDetailsCard(invoice),
              if (invoice.scope != null && invoice.scope!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildScopeCard(invoice),
              ],
              const SizedBox(height: 16),

              // Items Table
              _buildItemsTable(),
              const SizedBox(height: 16),

              // Payment Summary
              _buildPaymentSummaryCard(invoice),
              const SizedBox(height: 16),

              // Totals
              _buildTotalsCard(invoice),
              const SizedBox(height: 16),
              _buildPreparedBySection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // STATUS CARD
  // ============================================

  Widget _buildStatusCard(Invoice invoice) {
    final isPaid = invoice.isPaid;
    final isOverdue = invoice.isOverdue;
    final isPartial = invoice.isPartial;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isPaid) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle;
      statusText = 'Paid';
    } else if (isOverdue) {
      statusColor = AppColors.error;
      statusIcon = Icons.warning;
      statusText = 'Overdue';
    } else if (isPartial) {
      statusColor = AppColors.info;
      statusIcon = Icons.pending;
      statusText = 'Partially Paid';
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.pending;
      statusText = 'Unpaid';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status: $statusText',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: statusColor,
                  ),
                ),
                if (invoice.paymentDate != null)
                  Text(
                    'Paid on: ${_formatDateTime(invoice.paymentDate)}',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                if (invoice.isOverdue)
                  Text(
                    'Payment is overdue',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // CUSTOMER CARD
  // ============================================

  Widget _buildCustomerCard(Customer? customer, Invoice invoice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Customer', Icons.person_outline),
          const SizedBox(height: 8),
          if (customer != null) ...[
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    Helpers.getInitials(customer.name),
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
                        customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (customer.phone != null)
                        Text(
                          '📞 ${customer.phone}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                      if (customer.email != null)
                        Text(
                          '📧 ${customer.email}',
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
              invoice.customerName ?? 'Unknown Customer',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
          ],
          if (invoice.quoteNumber != null) ...[
            const SizedBox(height: 4),
            Text(
              'Quote: ${invoice.quoteNumber}',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================
  // INVOICE DETAILS CARD
  // ============================================

  Widget _buildInvoiceDetailsCard(Invoice invoice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Invoice Details', Icons.info_outline),
          const SizedBox(height: 8),
          _buildDetailRow('Invoice Number', invoice.invoiceNumber),
          _buildDetailRow('Created', _formatDateTime(invoice.createdAt)),
          if (invoice.dueDate != null)
            _buildDetailRow(
              'Due Date',
              _formatDate(invoice.dueDate),
              isHighlighted: invoice.isOverdue,
            ),
          if (invoice.issuedDate != null)
            _buildDetailRow('Issued Date', _formatDate(invoice.issuedDate)),
        ],
      ),
    );
  }

  // ============================================
  // ITEMS TABLE
  // ============================================

  Widget _buildScopeCard(Invoice invoice) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Scope of Works / Service', Icons.work_outline),
          const Divider(height: 20),
          Text(
            invoice.scope ?? '',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    final Map<String, List<QuoteItem>> groupedItems = {};
    for (var item in _items) {
      final section = item.section ?? 'General';
      groupedItems.putIfAbsent(section, () => []).add(item);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Invoice Items', Icons.list_alt),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No items found',
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
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

  // ============================================
  // PAYMENT SUMMARY CARD
  // ============================================

  Widget _buildPaymentSummaryCard(Invoice invoice) {
    final progress = invoice.total > 0 ? invoice.paidPercentage : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Payment Summary', Icons.payment),
          const SizedBox(height: 12),
          _buildDetailRow('Total Amount', _formatCurrency(invoice.total)),
          _buildDetailRow(
            'Amount Paid',
            _formatCurrency(invoice.amountPaid),
            color: AppColors.success,
          ),
          _buildDetailRow(
            'Balance Due',
            _formatCurrency(invoice.balanceDue),
            color: invoice.balanceDue > 0 ? AppColors.error : AppColors.success,
            isBold: true,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress / 100,
              minHeight: 8,
              backgroundColor: AppColors.background,
              color: progress >= 100
                  ? AppColors.success
                  : progress >= 50
                  ? AppColors.warning
                  : AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${progress.toStringAsFixed(0)}% paid',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  // ============================================
  // TOTALS CARD
  // ============================================

  Widget _buildTotalsCard(Invoice invoice) {
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
          if (invoice.subtotal > 0)
            _buildTotalsRow('Subtotal', _formatCurrency(invoice.subtotal)),
          if (invoice.tax > 0)
            _buildTotalsRow('Tax', _formatCurrency(invoice.tax)),
          if (invoice.discount > 0)
            _buildTotalsRow('Discount', _formatCurrency(invoice.discount)),
          const Divider(),
          _buildTotalsRow(
            'Total',
            _formatCurrency(invoice.total),
            isBold: true,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  // ============================================
  // ACTION BUTTONS
  // ============================================

  Widget _buildActionToolbar(Invoice invoice) {
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
              if (!invoice.isPaid) ...[
                _buildSmallActionButton(
                  text: 'Mark as Paid',
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  onPressed: _markAsPaid,
                ),
                _buildSmallActionButton(
                  text: 'Record Payment',
                  icon: Icons.payment_outlined,
                  color: AppColors.primary,
                  onPressed: _recordPartialPayment,
                ),
              ],
              _buildSmallActionButton(
                text: 'Preview Invoice',
                icon: Icons.preview_outlined,
                color: AppColors.secondary,
                onPressed: _generateAndPreviewInvoice,
              ),
              _buildSmallActionButton(
                text: 'Preview Receipt',
                icon: Icons.receipt_long_outlined,
                color: AppColors.secondary,
                onPressed: _generateAndPreviewReceipt,
              ),
              _buildSmallActionButton(
                text: 'Print Invoice',
                icon: Icons.print_outlined,
                color: AppColors.secondary,
                onPressed: _generateAndPrintInvoice,
              ),
              _buildSmallActionButton(
                text: 'Share',
                icon: Icons.share_outlined,
                color: AppColors.secondary,
                onPressed: _shareInvoice,
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

  // ============================================
  // HELPER WIDGETS
  // ============================================

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlighted = false,
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: AppColors.textLight),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color:
                  color ?? (isHighlighted ? AppColors.error : AppColors.text),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalsRow(
    String label,
    String value, {
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
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
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ],
    );
  }

  Future<void> _loadPreparedByName(String? userId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (mounted) {
      setState(() {
        _preparedByName = authProvider.currentUser?.name;
      });
    }
  }

  Widget _buildPreparedBySection() {
    final dateTimeStr = _invoice?.createdAt != null ? Formatters.dateTime(_invoice!.createdAt) : 'N/A';
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
}

// ============================================
// INVOICE PREVIEW PAGE
// ============================================

class InvoicePreviewPage extends StatefulWidget {
  final File pdfFile;
  final Invoice invoice;

  final bool isReceipt;

  const InvoicePreviewPage({
    super.key,
    required this.pdfFile,
    required this.invoice,
    this.isReceipt = false,
  });

  @override
  State<InvoicePreviewPage> createState() => _InvoicePreviewPageState();
}

class _InvoicePreviewPageState extends State<InvoicePreviewPage> {
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReceipt
            ? 'Receipt Preview: ${widget.invoice.invoiceNumber}'
            : 'Invoice Preview: ${widget.invoice.invoiceNumber}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isPrinting ? null : _downloadInvoice,
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
            onPressed: _isPrinting ? null : _printInvoice,
            tooltip: 'Print',
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
          return const Center(child: Text('Failed to load PDF'));
        },
        loadingWidget: const Center(
          child: LoadingSpinner(message: 'Loading preview...'),
        ),
      ),
    );
  }

  Future<void> _printInvoice() async {
    setState(() => _isPrinting = true);

    try {
      await Printing.layoutPdf(
        onLayout: (format) => widget.pdfFile.readAsBytesSync(),
        name: '${widget.invoice.invoiceNumber}.pdf',
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

  Future<void> _downloadInvoice() async {
    setState(() => _isPrinting = true);
    try {
      final file = await Helpers.downloadPdfToLocalDisk(
        widget.pdfFile,
        widget.isReceipt ? 'receipt' : 'invoice',
      );
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
