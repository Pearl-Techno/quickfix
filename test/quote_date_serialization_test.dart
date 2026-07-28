import 'package:flutter_test/flutter_test.dart';
import 'package:quickfix/models/quote.dart';

void main() {
  test('quote serialization preserves dates for local persistence', () {
    final createdAt = DateTime.utc(2026, 7, 8, 10, 30);
    final updatedAt = DateTime.utc(2026, 7, 8, 11, 0);
    final expiryDate = DateTime.utc(2026, 7, 15);

    final quote = Quote(
      id: 'quote-1',
      quoteNumber: 'QF-20260708-0001',
      customerId: 'customer-1',
      userId: 'user-1',
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiryDate: expiryDate,
    );

    final json = quote.toJson();
    final map = quote.toMap();

    expect(json['created_at'], createdAt.toIso8601String());
    expect(json['updated_at'], updatedAt.toIso8601String());
    expect(json['expiry_date'], expiryDate.toIso8601String());
    expect(map['created_at'], createdAt.toIso8601String());
    expect(map['updated_at'], updatedAt.toIso8601String());
    expect(map['expiry_date'], expiryDate.toIso8601String());
  });
}
