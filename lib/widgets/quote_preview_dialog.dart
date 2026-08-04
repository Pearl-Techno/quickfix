import 'dart:io';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../config/constants.dart';
import '../models/customer.dart';
import '../models/quote.dart';
import '../models/quote_item.dart';
import '../models/invoice.dart';
import '../services/pdf_service.dart';
import '../services/database_service.dart';
import '../utils/helpers.dart';
import '../utils/formatters.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class QuotePreviewDialog extends StatefulWidget {
  final Map<String, dynamic> quoteData;
  final bool isInvoice;

  const QuotePreviewDialog({super.key, required this.quoteData, this.isInvoice = false});

  @override
  State<QuotePreviewDialog> createState() => _QuotePreviewDialogState();
}

class _QuotePreviewDialogState extends State<QuotePreviewDialog>
    with SingleTickerProviderStateMixin {
  bool _isExporting = false;
  String _docNumber = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
    _initDocNumber();
  }

  void _initDocNumber() {
    final existingNum = widget.quoteData['quoteNumber'] ??
        widget.quoteData['quote_number'] ??
        widget.quoteData['invoiceNumber'] ??
        widget.quoteData['invoice_number'];
    if (existingNum != null && existingNum.toString().isNotEmpty) {
      _docNumber = existingNum.toString();
    } else {
      _loadDocNumber();
    }
  }

  Future<void> _loadDocNumber() async {
    final dbService = DatabaseService();
    if (widget.isInvoice) {
      final num = await dbService.generateInvoiceNumber();
      if (mounted) setState(() => _docNumber = num);
    } else {
      final num = await dbService.generateQuoteNumber();
      if (mounted) setState(() => _docNumber = num);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _exportPDF() async {
    final customer = widget.quoteData['customer'] as Customer?;
    final rawItems = widget.quoteData['items'] as List?;
    final items = rawItems?.cast<QuoteItem>() ?? <QuoteItem>[];

    if (customer == null || items.isEmpty) {
      Helpers.showError(
        context,
        'Cannot export PDF: Customer and at least one item are required.',
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      double subtotal = (widget.quoteData['subtotal'] as num?)?.toDouble() ?? 0.0;
      double tax = (widget.quoteData['tax'] as num?)?.toDouble() ?? 0.0;
      double total = (widget.quoteData['total'] as num?)?.toDouble() ?? 0.0;

      if (subtotal <= 0 && items.isNotEmpty) {
        subtotal = items.fold(0.0, (sum, item) => sum + item.total);
      }
      final bool applyTax = widget.quoteData['applyTax'] == true || tax > 0;
      if (tax <= 0 && applyTax) {
        tax = subtotal * Constants.taxRate;
      }
      if (total <= 0) {
        total = subtotal + tax;
      }
      final notes = widget.quoteData['notes'] as String?;
      final siteMeasurements = widget.quoteData['siteMeasurements'] as String?;
      final docNumToUse = _docNumber.isNotEmpty
          ? _docNumber
          : (widget.isInvoice ? 'QPN00001' : '010A');

      final quote = Quote(
        id: 'preview-${DateTime.now().millisecondsSinceEpoch}',
        quoteNumber: docNumToUse,
        customerId: customer.id,
        status: Constants.quoteStatusDraft,
        subtotal: subtotal,
        tax: tax,
        total: total,
        grandTotal: total,
        scope: widget.quoteData['scope'] as String?,
        title: widget.quoteData['title'] as String?,
        notes: notes,
        terms: widget.quoteData['terms'] as String?,
        siteMeasurements: siteMeasurements,
        createdAt: DateTime.now(),
        expiryDate: widget.quoteData['expiryDate'] as DateTime?,
        customerName: customer.name,
        items: items,
      );

      final pdfService = PdfService();
      final preparedBy = Provider.of<AuthProvider>(context, listen: false).currentUser?.name;
      final File file;
      if (widget.isInvoice) {
        final invoice = Invoice(
          id: 'preview-${DateTime.now().millisecondsSinceEpoch}',
          invoiceNumber: docNumToUse,
          quoteId: 'preview-quote-id',
          customerId: customer.id,
          subtotal: subtotal,
          tax: tax,
          discount: 0.0,
          total: total,
          amountPaid: 0.0,
          balanceDue: total,
          paymentStatus: Constants.invoiceStatusUnpaid,
          scope: widget.quoteData['scope'] as String?,
          notes: notes,
          terms: widget.quoteData['terms'] as String?,
          dueDate: widget.quoteData['expiryDate'] as DateTime?,
          createdAt: DateTime.now(),
          customerName: customer.name,
        );
        file = await pdfService.generateInvoicePdf(
          invoice: invoice,
          customer: customer,
          items: items,
          preparedBy: preparedBy,
        );
        await Helpers.downloadPdfToLocalDisk(file, 'invoice');
      } else {
        file = await pdfService.generateQuotePdf(
          quote: quote,
          customer: customer,
          items: items,
          preparedBy: preparedBy,
        );
        await Helpers.downloadPdfToLocalDisk(file, 'quote');
      }

      setState(() => _isExporting = false);

      if (!mounted) return;

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'PDF Generated',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'PDF saved as: ${file.path.split('\\').last}',
            style: const TextStyle(fontSize: 13),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Close', style: TextStyle(fontSize: 13)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: const Text('Open File', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );

      if (result == true && mounted) {
        try {
          await Process.run('explorer', [file.path]);
        } catch (e) {
          if (mounted) {
            Helpers.showSnackBar(
              context,
              'File saved at: ${file.path}',
              backgroundColor: AppColors.info,
            );
          }
        }
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        Helpers.showError(context, 'Failed to generate PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.quoteData['customer'] as Customer?;
    final rawItems = widget.quoteData['items'] as List?;
    final items = rawItems?.cast<QuoteItem>() ?? <QuoteItem>[];
    double subtotal = (widget.quoteData['subtotal'] as num?)?.toDouble() ?? 0.0;
    double tax = (widget.quoteData['tax'] as num?)?.toDouble() ?? 0.0;
    double total = (widget.quoteData['total'] as num?)?.toDouble() ?? 0.0;

    if (subtotal <= 0 && items.isNotEmpty) {
      subtotal = items.fold(0.0, (sum, item) => sum + item.total);
    }
    final bool applyTax = widget.quoteData['applyTax'] == true || tax > 0;
    if (tax <= 0 && applyTax) {
      tax = subtotal * Constants.taxRate;
    }
    if (total <= 0) {
      total = subtotal + tax;
    }
    final notes = widget.quoteData['notes'] as String?;

    final isComplete = customer != null && items.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 550,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTitleRow(context, isComplete),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPreviewHeader(),
                            const SizedBox(height: 12),
                             _buildPreviewCustomerInfo(customer),
                             const SizedBox(height: 12),
                             if (widget.quoteData['title'] != null &&
                                 (widget.quoteData['title'] as String).isNotEmpty) ...[
                               _buildPreviewNotes(widget.quoteData['title'] as String, 'Quotation Title / RE'),
                               const SizedBox(height: 12),
                             ],
                             if (widget.quoteData['scope'] != null &&
                                 (widget.quoteData['scope'] as String).isNotEmpty) ...[
                               _buildPreviewNotes(widget.quoteData['scope'] as String, 'Scope of Works'),
                               const SizedBox(height: 12),
                             ],
                             _buildPreviewItemsTable(items),
                             const SizedBox(height: 12),
                             _buildPreviewTotals(subtotal, tax, total),
                             _buildPreviewPreparedBy(context),
                             if (notes != null && notes.isNotEmpty) ...[
                               const SizedBox(height: 10),
                               _buildPreviewNotes(notes, 'Notes'),
                             ],
                           ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildActionsRow(context, isComplete),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context, bool isComplete) {
    return Row(
      children: [
        const Icon(Icons.visibility, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          widget.isInvoice ? 'Invoice Preview' : 'Quote Preview',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const Spacer(),
        if (!isComplete)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 12,
                  color: AppColors.warning,
                ),
                SizedBox(width: 4),
                Text(
                  'Incomplete',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // FIXED: Wrapped buttons with Flexible to prevent infinite width constraint
  Widget _buildActionsRow(BuildContext context, bool isComplete) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: ElevatedButton.icon(
            onPressed: (!isComplete || _isExporting) ? null : _exportPDF,
            icon: _isExporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf, size: 14),
            label: Text(
              _isExporting ? 'Exporting...' : 'Export PDF',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              widget.isInvoice ? 'Save Invoice' : 'Save Quote',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUICKFIX PLUMBERS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Quality Plumbing Services',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                widget.isInvoice ? 'INVOICE' : 'QUOTATION',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                _docNumber.isNotEmpty
                    ? _docNumber
                    : (widget.isInvoice ? 'QPN00001' : '010A'),
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCustomerInfo(Customer? customer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CUSTOMER DETAILS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 9,
              color: AppColors.textLight,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          if (customer != null) ...[
            Text(
              customer.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 2),
            if (customer.phone != null)
              Text(
                '📞 ${customer.phone}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
            if (customer.email != null)
              Text(
                '✉️ ${customer.email}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
            if (customer.address != null)
              Text(
                '📍 ${customer.address}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textLight,
                ),
              ),
          ] else ...[
            const Text(
              'No customer selected yet',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 11,
                color: AppColors.textLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewItemsTable(List<QuoteItem> items) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUOTE ITEMS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 9,
              color: AppColors.textLight,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: const Center(
              child: Text(
                'No items added yet',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Group items by section
    final Map<String, List<QuoteItem>> groupedItems = {};
    for (final item in items) {
      final section = item.section ?? 'General';
      groupedItems.putIfAbsent(section, () => []).add(item);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.isInvoice ? 'INVOICE ITEMS' : 'QUOTE ITEMS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 9,
            color: AppColors.textLight,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
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
                // Header Row
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.primary),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: _buildPreviewHeaderCell('Item'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: _buildPreviewHeaderCell('Qty', center: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: _buildPreviewHeaderCell('Price', center: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: _buildPreviewHeaderCell('Discount', center: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: _buildPreviewHeaderCell('Total', center: true),
                    ),
                  ],
                ),
                // Grouped items
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            'Total: ${Formatters.currency(entry.value.fold(0.0, (sum, item) => sum + item.total))}',
                            style: const TextStyle(
                              fontSize: 10,
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
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              item.quantity.toString(),
                              style: const TextStyle(fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              Formatters.currency(item.unitPrice),
                              style: TextStyle(fontSize: 11, color: AppColors.textLight),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              item.discount > 0
                                  ? '${Formatters.currency(item.discount)} (${item.discountPercentage.toStringAsFixed(0)}%)'
                                  : 'KSh 0.00',
                              style: TextStyle(fontSize: 11, color: AppColors.textLight),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        TableCell(
                          verticalAlignment: TableCellVerticalAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              Formatters.currency(item.total),
                              style: const TextStyle(
                                fontSize: 11,
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
        ),
      ],
    );
  }

  Widget _buildPreviewHeaderCell(String text, {bool center = false}) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 10,
      ),
      textAlign: center ? TextAlign.center : TextAlign.left,
    );
  }

  Widget _buildPreviewTotals(double subtotal, double tax, double total) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildTotalRow('Subtotal', Formatters.currency(subtotal)),
          if (tax > 0) ...[
            const SizedBox(height: 4),
            _buildTotalRow('Tax (16%)', Formatters.currency(tax)),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(height: 1),
          ),
          _buildTotalRow(
            'Total',
            Formatters.currency(total),
            isGrandTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool isGrandTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isGrandTotal ? 12 : 11,
            fontWeight: isGrandTotal ? FontWeight.bold : FontWeight.normal,
            color: isGrandTotal ? AppColors.text : AppColors.textLight,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isGrandTotal ? 13 : 11,
            fontWeight: FontWeight.bold,
            color: isGrandTotal ? AppColors.primary : AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewNotes(String text, String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 9,
              color: AppColors.textLight,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 11, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildPreviewPreparedBy(BuildContext context) {
    final preparedBy = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'N/A';
    final dateTimeStr = Formatters.dateTime(DateTime.now());
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.3),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Served By: ',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textLight),
              ),
              Text(
                preparedBy,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: AppColors.textLight),
              const SizedBox(width: 4),
              Text(
                dateTimeStr,
                style: const TextStyle(fontSize: 10, color: AppColors.textLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
