import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:quickfix/models/customer.dart';
import 'package:quickfix/models/invoice.dart';
import 'package:quickfix/models/quote.dart';
import 'package:quickfix/models/quote_item.dart';
import 'package:quickfix/utils/formatters.dart';
import 'package:quickfix/services/database_helper.dart';

// Simple logging function
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

class PdfService {
  pw.Font? _font;
  pw.Font? _boldFont;
  pw.MemoryImage? _logo;
  bool _fontsLoaded = false;

  // Modern Slate & Royal Blue theme colors
  static final PdfColor primaryColor = PdfColor.fromHex('#1e3a8a'); // Premium Navy Blue
  static final PdfColor accentColor = PdfColor.fromHex('#2563eb'); // Accent Blue
  static final PdfColor textDark = PdfColor.fromHex('#1e293b'); // Dark slate text
  static final PdfColor textMuted = PdfColor.fromHex('#64748b'); // Muted slate text
  static final PdfColor lightBgColor = PdfColor.fromHex('#f8fafc'); // Light card bg
  static final PdfColor borderCol = PdfColor.fromHex('#cbd5e1'); // Border slate 300

  // ============================================
  // FONT LOADING
  // ============================================

  Future<void> _loadFonts() async {
    if (_fontsLoaded) return;

    _font = pw.Font.helvetica();
    _boldFont = pw.Font.helveticaBold();

    // Load logo
    try {
      final imageData = await rootBundle.load(
        'assets/images/quickfix_logo.jpeg',
      );
      _logo = pw.MemoryImage(imageData.buffer.asUint8List());
      _log('✅ Loaded logo');
    } catch (e) {
      _log('⚠️ Logo not found: $e');
    }

    _fontsLoaded = true;
  }

  // ============================================
  // TEXT HELPER - Removes emojis for PDF compatibility
  // ============================================

  pw.Text _createText(
    String text, {
    double fontSize = 10,
    pw.FontWeight? fontWeight,
    PdfColor? color,
    pw.TextAlign? textAlign,
    bool isBold = false,
  }) {
    final effectiveFont = isBold ? _boldFont : _font;
    final effectiveWeight =
        fontWeight ?? (isBold ? pw.FontWeight.bold : pw.FontWeight.normal);

    // Clean text of emojis for PDF compatibility
    final cleanedText = _cleanText(text);

    return pw.Text(
      cleanedText,
      style: pw.TextStyle(
        font:
            effectiveFont ??
            (isBold ? pw.Font.helveticaBold() : pw.Font.helvetica()),
        fontSize: fontSize,
        fontWeight: effectiveWeight,
        color: color ?? textDark,
      ),
      textAlign: textAlign,
    );
  }

  String _cleanText(String text) {
    // Replace emojis with text labels for PDF compatibility
    return text
        .replaceAll('📞', 'Phone: ')
        .replaceAll('📧', 'Email: ')
        .replaceAll('📍', 'Location: ')
        .replaceAll('🏢', 'Office: ')
        .replaceAll('👤', 'Name: ')
        .replaceAll('🏗️', 'Site: ')
        .replaceAll('📅', 'Date: ')
        .replaceAll('📊', 'Status: ')
        .replaceAll('📦', 'Items: ')
        .replaceAll('📄', 'Quote: ')
        .replaceAll('⚠️', 'WARNING: ')
        .replaceAll('💰', 'Amount: ')
        .replaceAll('💳', 'Payment: ')
        .replaceAll('🕐', 'Time: ')
        .replaceAll('🏦', 'Bank: ')
        .replaceAll('💵', 'Currency: ')
        .replaceAll('🔑', 'Reference: ')
        .replaceAll('✅', '✓ ')
        .replaceAll('❌', '✗ ')
        .replaceAll('⭐', '* ')
        .replaceAll('🔔', 'Notice: ')
        .replaceAll('📌', 'Note: ')
        .replaceAll('📝', 'Notes: ')
        .replaceAll('🔧', 'Service: ')
        .replaceAll('📱', 'Mobile: ')
        .replaceAll('💻', 'Computer: ');
  }

  // ============================================
  // PRODUCT SKU LOOKUP HELPER
  // ============================================

  Future<Map<String, String>> _loadProductSkus(List<QuoteItem> items) async {
    final skus = <String, String>{};
    try {
      final dbHelper = DatabaseHelper();
      for (final item in items) {
        if (item.productId != null && item.productId!.isNotEmpty) {
          final productMap = await dbHelper.getProduct(item.productId!);
          if (productMap != null) {
            final sku = productMap['sku']?.toString();
            if (sku != null && sku.isNotEmpty) {
              skus[item.productId!] = sku;
            }
          }
        }
      }
    } catch (e) {
      _log('⚠️ Error loading product SKUs: $e');
    }
    return skus;
  }

  // ============================================
  // PUBLIC METHODS
  // ============================================

  Future<File> generateQuotePdf({
    required Quote quote,
    required Customer customer,
    required List<QuoteItem> items,
    String? preparedBy,
  }) async {
    await _loadFonts();
    final productSkus = await _loadProductSkus(items);
    final qrData = _buildQuoteQrData(quote, customer, items);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData(
          defaultTextStyle: pw.TextStyle(
            font: _font ?? pw.Font.helvetica(),
            fontSize: 10,
          ),
        ),
        build: (context) => [
          _buildHeader('QUOTATION', quote.quoteNumber),
          _buildInfoSection(
            customer: customer,
            title: 'Quote Details',
            dateLabel: 'Date:',
            dateVal: _formatDate(quote.createdAt),
            rightHeader: 'Valid Until:',
            rightVal: _formatDate(quote.createdAt?.add(Duration(days: quote.validityDays))),
            status: quote.displayStatus,
            preparedBy: preparedBy,
            documentDate: quote.createdAt,
          ),
          _buildScopeOfWorks(quote.scope),
          _buildItemsTable(items, productSkus),
          _buildBottomSection(quote, qrData),
          _buildSignatureSection(preparedBy: preparedBy, documentDate: quote.createdAt),
        ],
        footer: (context) => _buildFooter(),
      ),
    );

    final bytes = await pdf.save();
    final file = File('quote_${quote.quoteNumber}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> generateInvoicePdf({
    required Invoice invoice,
    required Customer customer,
    required List<QuoteItem> items,
    String? preparedBy,
  }) async {
    await _loadFonts();
    final productSkus = await _loadProductSkus(items);
    final qrData = _buildInvoiceQrData(invoice, customer, items);
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData(
          defaultTextStyle: pw.TextStyle(
            font: _font ?? pw.Font.helvetica(),
            fontSize: 10,
          ),
        ),
        build: (context) => [
          _buildHeader('INVOICE', invoice.invoiceNumber),
          _buildInfoSection(
            customer: customer,
            title: 'Invoice Details',
            dateLabel: 'Date:',
            dateVal: _formatDate(invoice.createdAt),
            rightHeader: 'Due Date:',
            rightVal: _formatDate(invoice.dueDate),
            status: invoice.displayStatus,
            preparedBy: preparedBy,
            documentDate: invoice.createdAt,
          ),
          _buildItemsTable(items, productSkus),
          _buildBottomSectionFromInvoice(invoice, qrData),
          _buildSignatureSection(preparedBy: preparedBy, documentDate: invoice.createdAt),
        ],
        footer: (context) => _buildFooter(),
      ),
    );

    final bytes = await pdf.save();
    final file = File('invoice_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<File> generateInvoiceReceiptPdf({
    required Invoice invoice,
    required Customer customer,
    required List<QuoteItem> items,
    String? preparedBy,
  }) async {
    await _loadFonts();
    final productSkus = await _loadProductSkus(items);
    final qrData = _buildInvoiceQrData(invoice, customer, items);
    final pdf = pw.Document();

    // Calculate dynamic height based on the items list length:
    final double calculatedHeight = 120.0 + 60.0 + 30.0 + (items.length * 25.0) + 120.0 + 160.0;
    final double receiptHeight = calculatedHeight < 430.0 ? 430.0 : calculatedHeight;

    final pageFormat = PdfPageFormat(
      80 * PdfPageFormat.mm,
      receiptHeight,
      marginAll: 4 * PdfPageFormat.mm,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: pw.ThemeData(
          defaultTextStyle: pw.TextStyle(
            font: _font ?? pw.Font.helvetica(),
            fontSize: 8.5,
          ),
        ),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildReceiptHeader(invoice),
            _buildReceiptCustomerInfo(customer),
            _buildReceiptScope(invoice.scope),
            _buildReceiptItemsTable(items, productSkus),
            _buildReceiptTotals(invoice),
            _buildReceiptPaymentInstructions(),
            _buildReceiptFooter(invoice, preparedBy: preparedBy, qrData: qrData),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    final file = File('receipt_${invoice.invoiceNumber}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  pw.Widget _buildReceiptHeader(Invoice invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (_logo != null && _logo!.bytes.isNotEmpty) ...[
          pw.Container(
            width: 65,
            height: 38,
            child: pw.Image(
              _logo!,
              fit: pw.BoxFit.contain,
            ),
          ),
          pw.SizedBox(height: 4),
        ],
        _createText(
          'Plumbing | Bathrooms | Shower Cubicles',
          fontSize: 7.5,
          color: textMuted,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        _createText(
          'Tel: +254703335788 | Web: www.quickfixplumbers.co.ke',
          fontSize: 7,
          color: textMuted,
          textAlign: pw.TextAlign.center,
        ),
        _createText(
          'Nairobi, Westlands Commercial Centre Block A 2nd Floor',
          fontSize: 7,
          color: textMuted,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 6),
        _createText(
          'RECEIPT',
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
          isBold: true,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        _createText(
          'No: ${invoice.invoiceNumber}',
          fontSize: 8.5,
          fontWeight: pw.FontWeight.bold,
          color: textDark,
          isBold: true,
          textAlign: pw.TextAlign.center,
        ),
        _createText(
          'Date: ${_formatDate(invoice.createdAt)}',
          fontSize: 7.5,
          color: textMuted,
          textAlign: pw.TextAlign.center,
        ),
        pw.Divider(thickness: 0.5, color: borderCol),
      ],
    );
  }

  pw.Widget _buildReceiptCustomerInfo(Customer customer) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _createText('CUSTOMER DETAILS:', fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textMuted, isBold: true),
        pw.SizedBox(height: 2),
        _createText(customer.name, fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
        if (customer.phone != null)
          _createText('Phone: ${customer.phone}', fontSize: 7.5, color: textDark),
        if (customer.email != null)
          _createText('Email: ${customer.email}', fontSize: 7.5, color: textDark),
        pw.Divider(thickness: 0.5, color: borderCol),
      ],
    );
  }

  pw.Widget _buildReceiptScope(String? scope) {
    if (scope == null || scope.isEmpty) {
      return pw.SizedBox.shrink();
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _createText('SCOPE OF WORKS / SERVICE:', fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textMuted, isBold: true),
        pw.SizedBox(height: 2),
        _createText(scope, fontSize: 7.5, color: textDark),
        pw.Divider(thickness: 0.5, color: borderCol),
      ],
    );
  }

  pw.Widget _buildReceiptItemsTable(List<QuoteItem> items, Map<String, String> productSkus) {
    if (items.isEmpty) {
      return pw.SizedBox.shrink();
    }

    final Map<String, List<QuoteItem>> groupedItems = {};
    for (var item in items) {
      final section = item.section ?? 'General';
      groupedItems.putIfAbsent(section, () => []).add(item);
    }

    final rows = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: _createText('Description', fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
          ),
          _createText('Qty', fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
          pw.SizedBox(width: 15),
          _createText('Total', fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
        ],
      ),
      pw.Divider(thickness: 0.5, color: borderCol),
    ];

    groupedItems.forEach((sectionName, sectionItems) {
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: _createText(
            sectionName.toUpperCase(),
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            isBold: true,
            color: primaryColor,
          ),
        ),
      );

      for (var item in sectionItems) {
        final sku = item.productId != null ? (productSkus[item.productId] ?? '') : '';
        rows.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _createText(item.description, fontSize: 7.5, color: textDark),
                        if (sku.isNotEmpty)
                          _createText('Code: $sku', fontSize: 6.5, color: textMuted),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                _createText('${item.quantity}', fontSize: 7.5, color: textDark),
                pw.SizedBox(width: 15),
                _createText('KSh ${item.total.toStringAsFixed(2)}', fontSize: 7.5, color: textDark),
              ],
            ),
          ),
        );
      }
    });

    rows.add(pw.Divider(thickness: 0.5, color: borderCol));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: rows,
    );
  }

  pw.Widget _buildReceiptTotals(Invoice invoice) {
    return pw.Column(
      children: [
        if (invoice.subtotal > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _createText('Subtotal:', fontSize: 7.5, color: textMuted),
              _createText('KSh ${invoice.subtotal.toStringAsFixed(2)}', fontSize: 7.5, color: textDark),
            ],
          ),
        if (invoice.tax > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _createText('Tax (16%):', fontSize: 7.5, color: textMuted),
              _createText('KSh ${invoice.tax.toStringAsFixed(2)}', fontSize: 7.5, color: textDark),
            ],
          ),
        if (invoice.discount > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _createText('Discount:', fontSize: 7.5, color: textMuted),
              _createText('KSh ${invoice.discount.toStringAsFixed(2)}', fontSize: 7.5, color: textDark),
            ],
          ),
        if (invoice.amountPaid > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _createText('Amount Paid:', fontSize: 7.5, color: textMuted),
              _createText('KSh ${invoice.amountPaid.toStringAsFixed(2)}', fontSize: 7.5, color: textDark),
            ],
          ),
        if (invoice.balanceDue > 0)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _createText('Balance Due:', fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
              _createText('KSh ${invoice.balanceDue.toStringAsFixed(2)}', fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
            ],
          ),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _createText('GRAND TOTAL:', fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor, isBold: true),
            _createText('KSh ${invoice.total.toStringAsFixed(2)}', fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor, isBold: true),
          ],
        ),
        pw.Divider(thickness: 0.5, color: borderCol),
      ],
    );
  }

  pw.Widget _buildReceiptFooter(Invoice invoice, {String? preparedBy, String? qrData}) {
    final statusText = invoice.isPaid
        ? 'PAID'
        : invoice.isOverdue
        ? 'OVERDUE'
        : 'PARTIALLY PAID / UNPAID';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (qrData != null && qrData.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _buildQrWidget(qrData, size: 45),
          pw.SizedBox(height: 4),
        ],
        _createText(
          'PAYMENT STATUS: $statusText',
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
          isBold: true,
          textAlign: pw.TextAlign.center,
        ),
        if (preparedBy != null && preparedBy.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          _createText(
            'Served By: $preparedBy on ${Formatters.dateTime(invoice.createdAt ?? DateTime.now())}',
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: textDark,
            isBold: true,
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 6),
        _createText(
          'Thank you for choosing Quickfix Plumbers!',
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: primaryColor,
          isBold: true,
          textAlign: pw.TextAlign.center,
        ),
        pw.SizedBox(height: 2),
        _createText(
          '© ${DateTime.now().year} Quickfix Plumbers. All rights reserved.',
          fontSize: 6,
          color: textMuted,
          textAlign: pw.TextAlign.center,
        ),
        _createText(
          'Generated on ${_formatDateTime(DateTime.now())}',
          fontSize: 6,
          color: textMuted,
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  Future<File> generateCombinedPdf({
    required Quote quote,
    required Invoice invoice,
    required Customer customer,
    required List<QuoteItem> items,
    String? preparedBy,
  }) async {
    await _loadFonts();
    final productSkus = await _loadProductSkus(items);
    final quoteQrData = _buildQuoteQrData(quote, customer, items);
    final invoiceQrData = _buildInvoiceQrData(invoice, customer, items);
    final pdf = pw.Document();

    // Page 1: Quote
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData(
          defaultTextStyle: pw.TextStyle(
            font: _font ?? pw.Font.helvetica(),
            fontSize: 10,
          ),
        ),
        build: (context) => [
          _buildHeader('QUOTATION', quote.quoteNumber),
          _buildInfoSection(
            customer: customer,
            title: 'Quote Details',
            dateLabel: 'Date:',
            dateVal: _formatDate(quote.createdAt),
            rightHeader: 'Valid Until:',
            rightVal: _formatDate(quote.createdAt?.add(Duration(days: quote.validityDays))),
            status: quote.displayStatus,
            preparedBy: preparedBy,
            documentDate: quote.createdAt,
          ),
          _buildScopeOfWorks(quote.scope),
          _buildItemsTable(items, productSkus),
          _buildBottomSection(quote, quoteQrData),
          _buildSignatureSection(preparedBy: preparedBy, documentDate: quote.createdAt),
        ],
        footer: (context) => _buildFooter(),
      ),
    );

    // Page 2: Invoice
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData(
          defaultTextStyle: pw.TextStyle(
            font: _font ?? pw.Font.helvetica(),
            fontSize: 10,
          ),
        ),
        build: (context) => [
          _buildHeader('INVOICE', invoice.invoiceNumber),
          _buildInfoSection(
            customer: customer,
            title: 'Invoice Details',
            dateLabel: 'Date:',
            dateVal: _formatDate(invoice.createdAt),
            rightHeader: 'Due Date:',
            rightVal: _formatDate(invoice.dueDate),
            status: invoice.displayStatus,
            preparedBy: preparedBy,
            documentDate: invoice.createdAt,
          ),
          _buildItemsTable(items, productSkus),
          _buildBottomSectionFromInvoice(invoice, invoiceQrData),
          _buildSignatureSection(preparedBy: preparedBy, documentDate: invoice.createdAt),
        ],
        footer: (context) => _buildFooter(),
      ),
    );

    final bytes = await pdf.save();
    final file = File('quote_invoice_${quote.quoteNumber}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  // ============================================
  // QR CODE HELPERS
  // ============================================

  String _buildQuoteQrData(Quote quote, Customer customer, List<QuoteItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('QUICKFIX PLUMBERS - QUOTATION');
    buffer.writeln('-----------------------------');
    buffer.writeln('Quote Number: ${quote.quoteNumber}');
    buffer.writeln('Date: ${_formatDate(quote.createdAt)}');
    buffer.writeln('Valid Until: ${_formatDate(quote.createdAt?.add(Duration(days: quote.validityDays)))}');
    buffer.writeln('Status: ${quote.displayStatus}');
    buffer.writeln('');
    buffer.writeln('CUSTOMER INFORMATION:');
    buffer.writeln('Name: ${customer.name}');
    if (customer.phone != null && customer.phone!.isNotEmpty) {
      buffer.writeln('Phone: ${customer.phone}');
    }
    if (customer.email != null && customer.email!.isNotEmpty) {
      buffer.writeln('Email: ${customer.email}');
    }
    if (customer.siteLocation != null && customer.siteLocation!.isNotEmpty) {
      buffer.writeln('Site Location: ${customer.siteLocation}');
    }
    buffer.writeln('');
    buffer.writeln('FINANCIAL DETAILS:');
    buffer.writeln('Subtotal: KSh ${quote.subtotal.toStringAsFixed(2)}');
    if (quote.tax > 0) {
      buffer.writeln('Tax (16%): KSh ${quote.tax.toStringAsFixed(2)}');
    }
    if (quote.discount > 0) {
      buffer.writeln('Discount: KSh ${quote.discount.toStringAsFixed(2)}');
    }
    buffer.writeln('Grand Total: KSh ${quote.grandTotal.toStringAsFixed(2)}');
    if (items.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('ITEMS LIST (${items.length}):');
      for (int i = 0; i < items.length; i++) {
        buffer.writeln('${i + 1}. ${items[i].description} | Qty: ${items[i].quantity} | Unit: KSh ${items[i].unitPrice.toStringAsFixed(2)} | Total: KSh ${items[i].total.toStringAsFixed(2)}');
      }
    }
    return buffer.toString();
  }

  String _buildInvoiceQrData(Invoice invoice, Customer customer, List<QuoteItem> items) {
    final buffer = StringBuffer();
    buffer.writeln('QUICKFIX PLUMBERS - INVOICE');
    buffer.writeln('---------------------------');
    buffer.writeln('Invoice Number: ${invoice.invoiceNumber}');
    buffer.writeln('Date: ${_formatDate(invoice.createdAt)}');
    buffer.writeln('Due Date: ${_formatDate(invoice.dueDate)}');
    buffer.writeln('Status: ${invoice.displayStatus.toUpperCase()}');
    buffer.writeln('');
    buffer.writeln('CUSTOMER INFORMATION:');
    buffer.writeln('Name: ${customer.name}');
    if (customer.phone != null && customer.phone!.isNotEmpty) {
      buffer.writeln('Phone: ${customer.phone}');
    }
    if (customer.email != null && customer.email!.isNotEmpty) {
      buffer.writeln('Email: ${customer.email}');
    }
    if (customer.siteLocation != null && customer.siteLocation!.isNotEmpty) {
      buffer.writeln('Site Location: ${customer.siteLocation}');
    }
    buffer.writeln('');
    buffer.writeln('FINANCIAL DETAILS:');
    buffer.writeln('Subtotal: KSh ${invoice.subtotal.toStringAsFixed(2)}');
    if (invoice.tax > 0) {
      buffer.writeln('Tax (16%): KSh ${invoice.tax.toStringAsFixed(2)}');
    }
    if (invoice.discount > 0) {
      buffer.writeln('Discount: KSh ${invoice.discount.toStringAsFixed(2)}');
    }
    buffer.writeln('Grand Total: KSh ${invoice.total.toStringAsFixed(2)}');
    buffer.writeln('Amount Paid: KSh ${invoice.amountPaid.toStringAsFixed(2)}');
    buffer.writeln('Balance Due: KSh ${invoice.balanceDue.toStringAsFixed(2)}');
    if (items.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('ITEMS LIST (${items.length}):');
      for (int i = 0; i < items.length; i++) {
        buffer.writeln('${i + 1}. ${items[i].description} | Qty: ${items[i].quantity} | Unit: KSh ${items[i].unitPrice.toStringAsFixed(2)} | Total: KSh ${items[i].total.toStringAsFixed(2)}');
      }
    }
    return buffer.toString();
  }

  pw.Widget _buildQrWidget(String qrData, {double size = 48.0}) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(2),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: borderCol, width: 0.5),
            borderRadius: pw.BorderRadius.circular(3),
          ),
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: size,
            height: size,
            drawText: false,
          ),
        ),
        pw.SizedBox(height: 2),
        _createText(
          'Scan for details',
          fontSize: 6,
          color: textMuted,
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  pw.Widget _buildRightQrWidget(String qrData, {double size = 50.0}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            _createText(
              'SCAN FOR DETAILS',
              fontSize: 7.5,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
              isBold: true,
            ),
            pw.SizedBox(height: 2),
            _createText(
              'Scan with smartphone camera\nto view full details & items.',
              fontSize: 6.5,
              color: textMuted,
              textAlign: pw.TextAlign.right,
            ),
          ],
        ),
        pw.SizedBox(width: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(3),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            border: pw.Border.all(color: borderCol, width: 0.5),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrData,
            width: size,
            height: size,
            drawText: false,
          ),
        ),
      ],
    );
  }

  // ============================================
  // HEADER BUILDERS
  // ============================================

  pw.Widget _buildInfoSection({
    required Customer customer,
    required String title,
    required String dateLabel,
    required String dateVal,
    required String rightHeader,
    required String rightVal,
    String? status,
    String? preparedBy,
    DateTime? documentDate,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left Card: Customer Details
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: lightBgColor,
                border: pw.Border(
                  left: pw.BorderSide(color: accentColor, width: 3),
                  top: pw.BorderSide(color: borderCol, width: 0.5),
                  right: pw.BorderSide(color: borderCol, width: 0.5),
                  bottom: pw.BorderSide(color: borderCol, width: 0.5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _createText(
                    'CUSTOMER DETAILS',
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: textMuted,
                    isBold: true,
                  ),
                  pw.SizedBox(height: 4),
                  _createText(customer.name, fontSize: 10, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
                  pw.SizedBox(height: 3),
                  if (customer.phone != null && customer.phone!.isNotEmpty)
                    _buildIconLabelRow('Phone:', customer.phone!, fontSize: 8),
                  if (customer.email != null && customer.email!.isNotEmpty)
                    _buildIconLabelRow('Email:', customer.email!, fontSize: 8),
                  if (customer.address != null && customer.address!.isNotEmpty)
                    _buildIconLabelRow('Address:', customer.address!, fontSize: 8),
                  if (customer.siteLocation != null && customer.siteLocation!.isNotEmpty)
                    _buildIconLabelRow('Site:', customer.siteLocation!, fontSize: 8),
                ],
              ),
            ),
          ),
          pw.SizedBox(width: 15),
          // Right Card: Document Details
          pw.Expanded(
            flex: 1,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: lightBgColor,
                border: pw.Border(
                  left: pw.BorderSide(color: primaryColor, width: 3),
                  top: pw.BorderSide(color: borderCol, width: 0.5),
                  right: pw.BorderSide(color: borderCol, width: 0.5),
                  bottom: pw.BorderSide(color: borderCol, width: 0.5),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _createText(
                    title.toUpperCase(),
                    fontSize: 8.5,
                    fontWeight: pw.FontWeight.bold,
                    color: textMuted,
                    isBold: true,
                  ),
                  pw.SizedBox(height: 4),
                  _buildDetailRow(dateLabel, dateVal),
                  _buildDetailRow(rightHeader, rightVal),
                  if (status != null)
                    _buildDetailRow('Status:', status),
                  if (preparedBy != null && preparedBy.isNotEmpty) ...[
                    _buildDetailRow('Served By:', preparedBy),
                    if (documentDate != null)
                      _buildDetailRow('Served At:', Formatters.dateTime(documentDate)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _createText(label, fontSize: 8, color: textMuted),
          _createText(value, fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
        ],
      ),
    );
  }

  pw.Widget _buildIconLabelRow(String label, String value, {double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _createText(label, fontSize: fontSize, color: textMuted),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: _createText(value, fontSize: fontSize, color: textDark),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildHeader(String title, String number) {
    return pw.Column(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: primaryColor, width: 2),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              // Left: Logo & Company Info
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (_logo != null && _logo!.bytes.isNotEmpty)
                    pw.Container(
                      width: 190,
                      height: 85,
                      margin: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(_logo!, fit: pw.BoxFit.contain),
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _createText(
                        'Plumbing | Bathrooms | Shower Cubicles',
                        fontSize: 9.5,
                        color: textMuted,
                      ),
                      pw.SizedBox(height: 2),
                      _createText(
                        'Tel: +254703335788  |  Web: www.quickfixplumbers.co.ke',
                        fontSize: 8,
                        color: textMuted,
                      ),
                      _createText(
                        'Nairobi, Westlands Commercial Centre Block A 2nd Floor',
                        fontSize: 8,
                        color: textMuted,
                      ),
                    ],
                  ),
                ],
              ),
              // Right: Title & Number Badge
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: _createText(
                      title,
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      isBold: true,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  _createText(
                    'No: $number',
                    fontSize: 11,
                    color: textDark,
                    fontWeight: pw.FontWeight.bold,
                    isBold: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 15),
      ],
    );
  }

  pw.Widget _buildScopeOfWorks(String? scope) {
    if (scope == null || scope.isEmpty) {
      return pw.SizedBox.shrink();
    }
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 8),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: lightBgColor,
        border: pw.Border(
          left: pw.BorderSide(color: accentColor, width: 3),
          top: pw.BorderSide(color: borderCol, width: 0.5),
          right: pw.BorderSide(color: borderCol, width: 0.5),
          bottom: pw.BorderSide(color: borderCol, width: 0.5),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _createText(
            'SCOPE OF WORKS / SERVICE',
            isBold: true,
            fontSize: 9,
            color: primaryColor,
          ),
          pw.SizedBox(height: 6),
          _createText(
            scope,
            fontSize: 8.5,
            color: textDark,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildItemsTable(List<QuoteItem> items, Map<String, String> productSkus) {
    if (items.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        child: _createText(
          'No items in this document',
          color: textMuted,
          textAlign: pw.TextAlign.center,
          fontSize: 9.5,
        ),
      );
    }

    // Group items by section
    final Map<String, List<QuoteItem>> groupedItems = {};
    for (final item in items) {
      final section = item.section ?? 'General';
      groupedItems.putIfAbsent(section, () => []).add(item);
    }

    final tableRows = <pw.TableRow>[
      // Table Header Row
      pw.TableRow(
        decoration: pw.BoxDecoration(
          color: primaryColor,
          borderRadius: const pw.BorderRadius.only(
            topLeft: pw.Radius.circular(4),
            topRight: pw.Radius.circular(4),
          ),
        ),
        children: [
          _buildTableHeaderCell('#', textAlign: pw.TextAlign.center),
          _buildTableHeaderCell('Code', textAlign: pw.TextAlign.left),
          _buildTableHeaderCell('Item Description', textAlign: pw.TextAlign.left),
          _buildTableHeaderCell('Qty', textAlign: pw.TextAlign.center),
          _buildTableHeaderCell('Unit Price', textAlign: pw.TextAlign.right),
          _buildTableHeaderCell('Discount', textAlign: pw.TextAlign.right),
          _buildTableHeaderCell('Total', textAlign: pw.TextAlign.right),
        ],
      ),
    ];

    // Add rows for each group
    groupedItems.forEach((sectionName, sectionItems) {
      final sectionTotal = sectionItems.fold(0.0, (sum, item) => sum + item.total);

      // Category Header Row
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#e2e8f0'),
          ),
          children: [
            _buildSectionHeaderCell(''),
            _buildSectionHeaderCell(''),
            _buildSectionHeaderCell(sectionName.toUpperCase(), color: primaryColor),
            _buildSectionHeaderCell(''),
            _buildSectionHeaderCell(''),
            _buildSectionHeaderCell(''),
            _buildSectionHeaderCell(''),
          ],
        ),
      );

      for (var i = 0; i < sectionItems.length; i++) {
        final item = sectionItems[i];
        final isEven = i % 2 == 0;
        final sku = item.productId != null ? (productSkus[item.productId] ?? '-') : '-';

        tableRows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : PdfColor.fromHex('#f8fafc'),
            ),
            children: [
              _buildTableCell('${i + 1}', textAlign: pw.TextAlign.center),
              _buildTableCell(sku, color: textMuted),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _createText(item.description, fontSize: 8.5, color: textDark),
                    if (item.productName != null && item.productName != item.description)
                      _createText(
                        '(${item.productName})',
                        fontSize: 7.5,
                        color: textMuted,
                      ),
                  ],
                ),
              ),
              _buildTableCell('${item.quantity}', textAlign: pw.TextAlign.center),
              _buildTableCell('KSh ${item.unitPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right),
              _buildTableCell(
                item.discount > 0
                    ? 'KSh ${item.discount.toStringAsFixed(2)}\n(${item.discountPercentage.toStringAsFixed(0)}%)'
                    : 'KSh 0.00',
                textAlign: pw.TextAlign.right,
              ),
              _buildTableCell(
                'KSh ${item.total.toStringAsFixed(2)}',
                textAlign: pw.TextAlign.right,
                fontWeight: pw.FontWeight.bold,
                isBold: true,
                color: textDark,
              ),
            ],
          ),
        );
      }

      // Category Subtotal Row
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#f1f5f9'),
            border: pw.Border(
              bottom: pw.BorderSide(color: borderCol, width: 0.5),
            ),
          ),
          children: [
            _buildTableCell('', fontSize: 8.5),
            _buildTableCell('', fontSize: 8.5),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: _createText(
                'Subtotal for ${sectionName.toUpperCase()}',
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                isBold: true,
                color: textMuted,
              ),
            ),
            _buildTableCell('', fontSize: 8.5),
            _buildTableCell('', fontSize: 8.5),
            _buildTableCell('', fontSize: 8.5),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: _createText(
                'KSh ${sectionTotal.toStringAsFixed(2)}',
                fontSize: 8.5,
                fontWeight: pw.FontWeight.bold,
                isBold: true,
                color: primaryColor,
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
      );
    });

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6, bottom: 10),
      child: pw.Table(
        border: pw.TableBorder(
          horizontalInside: pw.BorderSide(color: borderCol, width: 0.5),
          bottom: pw.BorderSide(color: borderCol, width: 0.5),
          left: pw.BorderSide(color: borderCol, width: 0.5),
          right: pw.BorderSide(color: borderCol, width: 0.5),
        ),
        columnWidths: const {
          0: pw.FixedColumnWidth(25),  // #
          1: pw.FixedColumnWidth(65),  // Code
          2: pw.FlexColumnWidth(),     // Description
          3: pw.FixedColumnWidth(30),  // Qty
          4: pw.FixedColumnWidth(80),  // Unit Price
          5: pw.FixedColumnWidth(85),  // Discount
          6: pw.FixedColumnWidth(80),  // Total
        },
        children: tableRows,
      ),
    );
  }

  pw.Widget _buildTableHeaderCell(String text, {pw.TextAlign textAlign = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: _createText(
        text,
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        isBold: true,
        textAlign: textAlign,
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign textAlign = pw.TextAlign.left,
    double fontSize = 8.5,
    pw.FontWeight? fontWeight,
    bool isBold = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: _createText(
        text,
        fontSize: fontSize,
        fontWeight: fontWeight,
        isBold: isBold,
        color: color ?? textDark,
        textAlign: textAlign,
      ),
    );
  }

  pw.Widget _buildSectionHeaderCell(
    String text, {
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: _createText(
        text,
        fontSize: 8.5,
        fontWeight: pw.FontWeight.bold,
        isBold: true,
        color: color ?? textDark,
      ),
    );
  }

  pw.Widget _buildBottomSection(Quote quote, [String? qrData]) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 15),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Payment & Terms
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: lightBgColor,
                    border: pw.Border(
                      left: pw.BorderSide(color: accentColor, width: 3),
                      top: pw.BorderSide(color: borderCol, width: 0.5),
                      right: pw.BorderSide(color: borderCol, width: 0.5),
                      bottom: pw.BorderSide(color: borderCol, width: 0.5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _createText('PAYMENT INSTRUCTIONS', fontSize: 8.5, fontWeight: pw.FontWeight.bold, isBold: true, color: primaryColor),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          _createText('Mpesa Paybill: ', fontSize: 8, color: textMuted),
                          _createText('400200', fontSize: 8.5, fontWeight: pw.FontWeight.bold, isBold: true, color: textDark),
                        ],
                      ),
                      pw.Row(
                        children: [
                          _createText('Account: ', fontSize: 8, color: textMuted),
                          _createText('40063912', fontSize: 8.5, fontWeight: pw.FontWeight.bold, isBold: true, color: textDark),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: lightBgColor,
                    border: pw.Border(
                      left: pw.BorderSide(color: textMuted, width: 3),
                      top: pw.BorderSide(color: borderCol, width: 0.5),
                      right: pw.BorderSide(color: borderCol, width: 0.5),
                      bottom: pw.BorderSide(color: borderCol, width: 0.5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _createText('TERMS & CONDITIONS', fontSize: 8.5, fontWeight: pw.FontWeight.bold, isBold: true, color: primaryColor),
                      pw.SizedBox(height: 4),
                      _createText('1. Valid for ${quote.validityDays} days from date.', fontSize: 7.5, color: textMuted),
                      _createText('2. Materials remain property of Quickfix until paid.', fontSize: 7.5, color: textMuted),
                      _createText('3. Warranty: 12 months on workmanship/materials.', fontSize: 7.5, color: textMuted),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 15),
          // Right: Totals & QR Code
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: lightBgColor,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderCol, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildNewTotalRow('Subtotal:', quote.subtotal),
                      if (quote.tax > 0)
                        _buildNewTotalRow('Tax (16%):', quote.tax),
                      if (quote.discount > 0)
                        _buildNewTotalRow('Discount:', quote.discount),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Divider(thickness: 1, color: borderCol),
                      ),
                      _buildNewTotalRow('Total:', quote.grandTotal, isGrandTotal: true),
                    ],
                  ),
                ),
                if (qrData != null && qrData.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _buildRightQrWidget(qrData),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBottomSectionFromInvoice(Invoice invoice, [String? qrData]) {
    final statusBgColor = invoice.isPaid
        ? PdfColor.fromHex('#ecfdf5')
        : invoice.isOverdue
            ? PdfColor.fromHex('#fef2f2')
            : PdfColor.fromHex('#fffbeb');

    final statusTextColor = invoice.isPaid
        ? PdfColor.fromHex('#10b981')
        : invoice.isOverdue
            ? PdfColor.fromHex('#ef4444')
            : PdfColor.fromHex('#d97706');

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 15),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Payment & Status
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: lightBgColor,
                    border: pw.Border(
                      left: pw.BorderSide(color: accentColor, width: 3),
                      top: pw.BorderSide(color: borderCol, width: 0.5),
                      right: pw.BorderSide(color: borderCol, width: 0.5),
                      bottom: pw.BorderSide(color: borderCol, width: 0.5),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _createText('PAYMENT INSTRUCTIONS', fontSize: 8.5, fontWeight: pw.FontWeight.bold, isBold: true, color: primaryColor),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          _createText('Mpesa Paybill: ', fontSize: 8, color: textMuted),
                          _createText('400200', fontSize: 8.5, fontWeight: pw.FontWeight.bold, isBold: true, color: textDark),
                        ],
                      ),
                      pw.Row(
                        children: [
                          _createText('Account: ', fontSize: 8, color: textMuted),
                          _createText('40063912', fontSize: 8.5, fontWeight: pw.FontWeight.bold, isBold: true, color: textDark),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: statusBgColor,
                    border: pw.Border.all(color: statusTextColor, width: 1),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      _createText(
                        'STATUS: ',
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: statusTextColor,
                        isBold: true,
                      ),
                      _createText(
                        invoice.displayStatus.toUpperCase(),
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: statusTextColor,
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 15),
          // Right: Totals & QR Code
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: lightBgColor,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderCol, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (invoice.subtotal > 0)
                        _buildNewTotalRow('Subtotal:', invoice.subtotal),
                      if (invoice.tax > 0)
                        _buildNewTotalRow('Tax (16%):', invoice.tax),
                      if (invoice.discount > 0)
                        _buildNewTotalRow('Discount:', invoice.discount),
                      if (invoice.amountPaid > 0)
                        _buildNewTotalRow('Amount Paid:', invoice.amountPaid),
                      if (invoice.balanceDue > 0)
                        _buildNewTotalRow('Balance Due:', invoice.balanceDue),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Divider(thickness: 1, color: borderCol),
                      ),
                      _buildNewTotalRow('Total:', invoice.total, isGrandTotal: true),
                    ],
                  ),
                ),
                if (qrData != null && qrData.isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  _buildRightQrWidget(qrData),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNewTotalRow(String label, double amount, {bool isGrandTotal = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _createText(
            label,
            fontSize: isGrandTotal ? 11 : 8.5,
            fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isGrandTotal ? primaryColor : textMuted,
            isBold: isGrandTotal,
          ),
          _createText(
            'KSh ${amount.toStringAsFixed(2)}',
            fontSize: isGrandTotal ? 11 : 8.5,
            fontWeight: isGrandTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isGrandTotal ? primaryColor : textDark,
            isBold: isGrandTotal,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptPaymentInstructions() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        color: lightBgColor,
        border: pw.Border(
          left: pw.BorderSide(color: accentColor, width: 2),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _createText('PAYMENT INSTRUCTIONS', fontSize: 7.5, fontWeight: pw.FontWeight.bold, isBold: true, color: primaryColor),
          pw.SizedBox(height: 2),
          _createText('Mpesa Paybill: 400200', fontSize: 7, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
          _createText('Account: 40063912', fontSize: 7, fontWeight: pw.FontWeight.bold, color: textDark, isBold: true),
        ],
      ),
    );
  }

  pw.Widget _buildSignatureSection({String? preparedBy, DateTime? documentDate}) {
    return pw.SizedBox.shrink();
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: borderCol, width: 0.5)),
      ),
      child: pw.Column(
        children: [
          _createText(
            'Thank you for choosing Quickfix Plumbers',
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
            isBold: true,
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 3),
          _createText(
            '© ${DateTime.now().year} Quickfix Plumbers. All rights reserved.  |  Generated on ${_formatDateTime(DateTime.now())}',
            fontSize: 7.5,
            color: textMuted,
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
