import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Quotation Numbering System Tests', () {
    test('Quote increment rolls over letters properly', () {
      final dbService = DatabaseService();

      // Basic alphanumeric increments
      expect(dbService.incrementAlphanumericQuoteNumber('010A'), '010B');
      expect(dbService.incrementAlphanumericQuoteNumber('010Y'), '010Z');

      // Z rollover increment logic (increases number, resets letter to A)
      expect(dbService.incrementAlphanumericQuoteNumber('010Z'), '011A');
      expect(dbService.incrementAlphanumericQuoteNumber('099Z'), '100A');
    });

    test('Quote increment falls back on invalid patterns', () {
      final dbService = DatabaseService();

      // Invalid format fallbacks
      expect(dbService.incrementAlphanumericQuoteNumber(''), '010A');
      expect(dbService.incrementAlphanumericQuoteNumber('010'), '010A');
      expect(dbService.incrementAlphanumericQuoteNumber('ABC'), '010A');
      expect(dbService.incrementAlphanumericQuoteNumber('010AA'), '010A');
      expect(dbService.incrementAlphanumericQuoteNumber('010#'), '010A');
    });
  });

  group('Invoice Numbering System Tests', () {
    test('Invoice increment increases sequence number incrementally', () {
      final dbService = DatabaseService();

      expect(dbService.incrementInvoiceNumber('QPN00001'), 'QPN00002');
      expect(dbService.incrementInvoiceNumber('QPN00099'), 'QPN00100');
      expect(dbService.incrementInvoiceNumber('QPN09999'), 'QPN10000');
    });

    test('Invoice increment falls back on invalid formats', () {
      final dbService = DatabaseService();

      expect(dbService.incrementInvoiceNumber(''), 'QPN00001');
      expect(dbService.incrementInvoiceNumber('QP00001'), 'QPN00001');
      expect(dbService.incrementInvoiceNumber('QPN0001'), 'QPN00001');
      expect(dbService.incrementInvoiceNumber('QPNABCDE'), 'QPN00001');
    });
  });
}
