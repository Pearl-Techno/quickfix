import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/pdf_service.dart';
import 'package:quickfix/models/quote.dart';
import 'package:quickfix/models/invoice.dart';
import 'package:quickfix/models/customer.dart';
import 'package:quickfix/models/quote_item.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en', null);
  });

  group('PDF Generation Tests', () {
    final customer = Customer(
      id: 'cust-123',
      name: 'John Doe',
      phone: '+254712345678',
      email: 'john.doe@example.com',
      address: '123 Main St, Nairobi',
      siteLocation: 'Westlands Block C',
      createdAt: DateTime.now(),
    );

    final quote = Quote(
      id: 'quote-123',
      quoteNumber: 'QPN00001',
      customerId: 'cust-123',
      status: 'approved',
      subtotal: 10000,
      tax: 1600,
      discount: 500,
      total: 11100,
      grandTotal: 11100,
      validityDays: 14,
      scope: 'Standard installation of pipes and shower box.',
      createdAt: DateTime.now(),
    );

    final invoice = Invoice(
      id: 'inv-123',
      invoiceNumber: 'INV00001',
      quoteId: 'quote-123',
      customerId: 'cust-123',
      subtotal: 10000,
      tax: 1600,
      discount: 500,
      total: 11100,
      amountPaid: 5000,
      balanceDue: 6100,
      paymentStatus: 'partial',
      dueDate: DateTime.now().add(const Duration(days: 7)),
      createdAt: DateTime.now(),
    );

    final items = [
      QuoteItem(
        id: 'item-1',
        quoteId: 'quote-123',
        productId: 'prod-1',
        itemType: 'stock',
        description: 'PPR Pipe 25mm PN20',
        quantity: 10,
        unitPrice: 500,
        total: 5000,
        section: 'Materials',
        productName: 'PPR Pipe 25mm',
      ),
      QuoteItem(
        id: 'item-2',
        quoteId: 'quote-123',
        itemType: 'service',
        description: 'Labour charge for pipe fixing',
        quantity: 1,
        unitPrice: 5000,
        total: 5000,
        section: 'Labour',
      ),
    ];

    test('generateQuotePdf builds and saves quote successfully', () async {
      final pdfService = PdfService();
      final file = await pdfService.generateQuotePdf(
        quote: quote,
        customer: customer,
        items: items,
        preparedBy: 'Technician Alex',
      );

      expect(file, isNotNull);
      expect(await file.exists(), isTrue);
      expect(await file.length(), isPositive);

      // Cleanup
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('generateInvoicePdf builds and saves invoice successfully', () async {
      final pdfService = PdfService();
      final file = await pdfService.generateInvoicePdf(
        invoice: invoice,
        customer: customer,
        items: items,
        preparedBy: 'Technician Alex',
      );

      expect(file, isNotNull);
      expect(await file.exists(), isTrue);
      expect(await file.length(), isPositive);

      // Cleanup
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('generateInvoiceReceiptPdf builds and saves thermal receipt successfully', () async {
      final pdfService = PdfService();
      final file = await pdfService.generateInvoiceReceiptPdf(
        invoice: invoice,
        customer: customer,
        items: items,
        preparedBy: 'Technician Alex',
      );

      expect(file, isNotNull);
      expect(await file.exists(), isTrue);
      expect(await file.length(), isPositive);

      // Cleanup
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('generateCombinedPdf builds and saves multiple pages successfully', () async {
      final pdfService = PdfService();
      final file = await pdfService.generateCombinedPdf(
        quote: quote,
        invoice: invoice,
        customer: customer,
        items: items,
        preparedBy: 'Technician Alex',
      );

      expect(file, isNotNull);
      expect(await file.exists(), isTrue);
      expect(await file.length(), isPositive);

      // Cleanup
      if (await file.exists()) {
        await file.delete();
      }
    });
  });
}
