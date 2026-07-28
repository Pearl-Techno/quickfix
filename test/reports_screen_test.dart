import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quickfix/providers/quote_provider.dart';
import 'package:quickfix/providers/invoice_provider.dart';
import 'package:quickfix/providers/customer_provider.dart';
import 'package:quickfix/providers/auth_provider.dart';
import 'package:quickfix/models/quote.dart';
import 'package:quickfix/models/invoice.dart';
import 'package:quickfix/models/customer.dart';
import 'package:quickfix/models/user.dart';
import 'package:quickfix/screens/admin/reports_screen.dart';
import 'package:quickfix/services/database_service.dart';
import 'package:intl/date_symbol_data_local.dart';

class MockQuoteProvider extends ChangeNotifier implements QuoteProvider {
  @override
  List<Quote> get allQuotes => [
    Quote(
      id: 'q1',
      quoteNumber: 'QPN00001',
      customerId: 'c1',
      total: 5000,
      grandTotal: 5000,
      status: 'approved',
      createdAt: DateTime.now(),
    ),
    Quote(
      id: 'q2',
      quoteNumber: 'QPN00002',
      customerId: 'c2',
      total: 8000,
      grandTotal: 8000,
      status: 'converted',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<void> loadQuotes({bool forceRefresh = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockInvoiceProvider extends ChangeNotifier implements InvoiceProvider {
  @override
  List<Invoice> get allInvoices => [
    Invoice(
      id: 'inv1',
      invoiceNumber: 'INV00001',
      quoteId: 'q2',
      customerId: 'c2',
      total: 8000,
      amountPaid: 8000,
      balanceDue: 0,
      paymentStatus: 'paid',
      customerName: 'Alice Smith',
      createdAt: DateTime.now(),
    ),
    Invoice(
      id: 'inv2',
      invoiceNumber: 'INV00002',
      quoteId: '',
      customerId: 'c1',
      total: 4000,
      amountPaid: 1000,
      balanceDue: 3000,
      paymentStatus: 'partial',
      customerName: 'Bob Jones',
      createdAt: DateTime.now(),
    ),
  ];

  @override
  Future<void> loadInvoices({bool forceRefresh = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCustomerProvider extends ChangeNotifier implements CustomerProvider {
  @override
  List<Customer> get allCustomers => [
    Customer(id: 'c1', name: 'Bob Jones', createdAt: DateTime.now()),
    Customer(id: 'c2', name: 'Alice Smith', createdAt: DateTime.now()),
  ];

  @override
  Future<void> loadCustomers({bool forceRefresh = false}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  User? get currentUser => User(
    id: 'admin1',
    name: 'Admin User',
    email: 'admin@quickfix.com',
    role: 'admin',
    createdAt: DateTime.now(),
  );

  @override
  bool get canViewReports => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en', null);
    DatabaseService().dispose();
  });

  tearDownAll(() {
    DatabaseService().dispose();
  });

  testWidgets('ReportsScreen renders summary cards, charts, and customer lists', (WidgetTester tester) async {
    final mockQuoteProvider = MockQuoteProvider();
    final mockInvoiceProvider = MockInvoiceProvider();
    final mockCustomerProvider = MockCustomerProvider();
    final mockAuthProvider = MockAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<QuoteProvider>.value(value: mockQuoteProvider),
          ChangeNotifierProvider<InvoiceProvider>.value(value: mockInvoiceProvider),
          ChangeNotifierProvider<CustomerProvider>.value(value: mockCustomerProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify page title
    expect(find.text('Reports & Analytics'), findsOneWidget);

    // Verify summary metric cards are rendered
    expect(find.text('Gross Sales'), findsOneWidget);
    expect(find.text('Payments Collected'), findsOneWidget);
    expect(find.text('Outstanding Balance'), findsOneWidget);
    expect(find.text('Quote Conversion'), findsOneWidget);
    
    // Verify leaderboard titles
    expect(find.text('Top Customers by Revenue'), findsOneWidget);
    expect(find.text('Highest Value Invoices'), findsOneWidget);

    // Verify calculated totals: 8000 + 4000 = 12000
    expect(find.textContaining('12000.00'), findsOneWidget);
  });
}
