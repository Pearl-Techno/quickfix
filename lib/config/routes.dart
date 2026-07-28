// lib/config/routes.dart
import 'package:flutter/material.dart';
import 'package:quickfix/config/app_colors.dart';
import 'package:quickfix/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/activation_screen.dart';
import '../screens/admin/dashboard_screen.dart';
import '../screens/admin/customers_screen.dart';
import '../screens/admin/add_customer_screen.dart';
import '../screens/admin/products_screen.dart';
import '../screens/admin/add_product_screen.dart';
import '../screens/admin/quotes_screen.dart';
import '../screens/admin/create_quote_screen.dart';
import '../screens/admin/quote_details_screen.dart';
import '../screens/admin/invoices_screen.dart';
import '../screens/admin/invoice_details_screen.dart';
import '../screens/admin/price_list_screen.dart';
import '../screens/admin/settings_screen.dart';
import '../screens/admin/reports_screen.dart';
import '../screens/admin/system_logs_screen.dart';
import '../screens/admin/approval_requests_screen.dart';
import '../screens/technician/technician_dashboard.dart';
import '../screens/technician/create_site_quote.dart';
import '../screens/technician/site_measurements.dart';
import '../screens/technician/my_quotes.dart';

// ============= ROUTE MIDDLEWARE =============
typedef RouteMiddleware = Widget Function(BuildContext context, Widget child);

class AppRoutes {
  // ============= ROUTE NAMES =============
  static const String splash = '/';
  static const String login = '/login';
  static const String activation = '/activation';

  // Admin Routes
  static const String adminDashboard = '/admin/dashboard';
  static const String customers = '/admin/customers';
  static const String addCustomer = '/admin/customers/add';
  static const String editCustomer = '/admin/customers/edit/:id';
  static const String customerDetails = '/admin/customers/:id';
  static const String products = '/admin/products';
  static const String addProduct = '/admin/products/add';
  static const String editProduct = '/admin/products/edit/:id';
  static const String priceList = '/admin/price-list';
  static const String quotes = '/admin/quotes';
  static const String createQuote = '/admin/quotes/create';
  static const String quoteDetails = '/admin/quotes/:id';
  static const String editQuote = '/admin/quotes/edit/:id';
  static const String invoices = '/admin/invoices';
  static const String createInvoice = '/admin/invoices/create';
  static const String invoiceDetails = '/admin/invoices/:id';
  static const String editInvoice = '/admin/invoices/edit/:id';
  static const String settings = '/admin/settings';
  static const String reports = '/admin/reports';
  static const String systemLogs = '/admin/logs';
  static const String approvalRequests = '/admin/approvals';

  // Technician Routes
  static const String technicianDashboard = '/technician/dashboard';
  static const String createSiteQuote = '/technician/quotes/create';
  static const String siteMeasurements = '/technician/measurements';
  static const String myQuotes = '/technician/my-quotes';
  static const String quoteStatus = '/technician/quotes/status/:id';

  // ============= ROUTE PARAMETER KEYS =============
  static const String paramId = 'id';
  static const String paramQuoteId = 'quoteId';
  static const String paramInvoiceId = 'invoiceId';
  static const String paramCustomerId = 'customerId';
  static const String paramProductId = 'productId';

  // ============= ROUTE CONFIGURATION =============
  static final Map<String, WidgetBuilder> _routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    activation: (context) => const ActivationScreen(),
    adminDashboard: (context) => const DashboardScreen(),
    customers: (context) => const CustomersScreen(),
    addCustomer: (context) => const AddCustomerScreen(),
    products: (context) => const ProductsScreen(),
    addProduct: (context) => const AddProductScreen(),
    priceList: (context) => const PriceListScreen(),
    quotes: (context) => const QuotesScreen(),
    createQuote: (context) => const CreateQuoteScreen(),
    invoices: (context) => const InvoicesScreen(),
    createInvoice: (context) => const CreateQuoteScreen(isInvoice: true),
    settings: (context) => const SettingsScreen(),
    reports: (context) => const ReportsScreen(),
    systemLogs: (context) => const SystemLogsScreen(),
    approvalRequests: (context) => const ApprovalRequestsScreen(),
    technicianDashboard: (context) => const TechnicianDashboard(),
    createSiteQuote: (context) => const CreateSiteQuote(),
    siteMeasurements: (context) => const SiteMeasurements(),
    myQuotes: (context) => const MyQuotes(),
  };

  // ============= ROUTE MIDDLEWARE =============
  static List<RouteMiddleware> middlewares = [];

  // ============= NAVIGATION METHODS =============
  static void push(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void pushReplacement(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void pushAndRemoveUntil(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool removeAll = false,
  }) {
    if (removeAll) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        routeName,
        (route) => false,
        arguments: arguments,
      );
    } else {
      Navigator.pushNamedAndRemoveUntil(
        context,
        routeName,
        (route) => route.isFirst,
        arguments: arguments,
      );
    }
  }

  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    Navigator.pop(context, result);
  }

  static void popUntilRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
  }

  // ============= ROUTE GENERATOR =============
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final String routeName = settings.name ?? '';
    final Object? arguments = settings.arguments;

    return MaterialPageRoute(
      builder: (context) {
        Widget widget = _buildRouteWithContext(context, routeName, arguments);
        // Apply middleware with actual context
        for (final middleware in middlewares.reversed) {
          widget = middleware(context, widget);
        }
        return widget;
      },
      settings: settings,
    );
  }

  static Widget _buildRouteWithContext(
    BuildContext context,
    String routeName,
    Object? arguments,
  ) {
    // Handle static routes with context
    if (_routes.containsKey(routeName)) {
      return _routes[routeName]!(context);
    }

    // Handle dynamic routes with context
    return _buildDynamicRouteWithContext(context, routeName, arguments);
  }

  static Widget _buildDynamicRouteWithContext(
    BuildContext context,
    String routeName,
    Object? arguments,
  ) {
    // Handle routes with arguments
    if (arguments != null && arguments is Map<String, dynamic>) {
      final args = arguments;

      // Quote Details with arguments
      if (routeName == quoteDetails) {
        final id = args[paramId] ?? '';
        return QuoteDetailsScreen(quoteId: id.toString());
      }

      // Invoice Details with arguments
      if (routeName == invoiceDetails) {
        final id = args[paramId] ?? '';
        return InvoiceDetailsScreen(invoiceId: id.toString());
      }

      // Edit Quote with arguments
      if (routeName == editQuote) {
        final id = args[paramId] ?? '';
        return CreateQuoteScreen(quoteId: id.toString());
      }

      // Edit Invoice with arguments
      if (routeName == editInvoice) {
        final id = args[paramId] ?? '';
        return EditInvoiceScreen(invoiceId: id.toString());
      }

      // Customer Details with arguments
      if (routeName == customerDetails) {
        final id = args[paramId] ?? '';
        return CustomerDetailsScreen(customerId: id.toString());
      }

      // Edit Customer with arguments
      if (routeName == editCustomer) {
        final id = args[paramId] ?? '';
        return EditCustomerScreen(customerId: id.toString());
      }

      // Edit Product with arguments
      if (routeName == editProduct) {
        final id = args[paramId] ?? '';
        return EditProductScreen(productId: id.toString());
      }

      // Quote Status with arguments
      if (routeName == quoteStatus) {
        final id = args[paramId] ?? '';
        return QuoteStatusScreen(quoteId: id.toString());
      }
    }

    // Quote Details: /admin/quotes/123
    if (routeName.startsWith('/admin/quotes/') &&
        routeName != '/admin/quotes' &&
        routeName != '/admin/quotes/create' &&
        !routeName.startsWith('/admin/quotes/edit/')) {
      final id = routeName.split('/').last;
      if (id.isNotEmpty && id != 'create') {
        return QuoteDetailsScreen(quoteId: id);
      }
    }

    // Invoice Details: /admin/invoices/123
    if (routeName.startsWith('/admin/invoices/') &&
        routeName != '/admin/invoices' &&
        routeName != '/admin/invoices/create' &&
        !routeName.startsWith('/admin/invoices/edit/')) {
      final id = routeName.split('/').last;
      if (id.isNotEmpty && id != 'create') {
        return InvoiceDetailsScreen(invoiceId: id);
      }
    }

    // Edit Quote: /admin/quotes/edit/123
    if (routeName.startsWith('/admin/quotes/edit/')) {
      final id = routeName.split('/').last;
      return CreateQuoteScreen(quoteId: id);
    }

    // Edit Invoice: /admin/invoices/edit/123
    if (routeName.startsWith('/admin/invoices/edit/')) {
      final id = routeName.split('/').last;
      return EditInvoiceScreen(invoiceId: id);
    }

    // Customer Details: /admin/customers/123
    if (routeName.startsWith('/admin/customers/') &&
        routeName != '/admin/customers' &&
        routeName != '/admin/customers/add') {
      final id = routeName.split('/').last;
      return CustomerDetailsScreen(customerId: id);
    }

    // Edit Customer: /admin/customers/edit/123
    if (routeName.startsWith('/admin/customers/edit/')) {
      final id = routeName.split('/').last;
      return EditCustomerScreen(customerId: id);
    }

    // Edit Product: /admin/products/edit/123
    if (routeName.startsWith('/admin/products/edit/')) {
      final id = routeName.split('/').last;
      return EditProductScreen(productId: id);
    }

    // Quote Status: /technician/quotes/status/123
    if (routeName.startsWith('/technician/quotes/status/')) {
      final id = routeName.split('/').last;
      return QuoteStatusScreen(quoteId: id);
    }

    // Route not found - Show 404
    return _buildNotFoundScreen(routeName, context);
  }

  static Widget _buildNotFoundScreen(String routeName, BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Page Not Found',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The route "$routeName" does not exist.',
                style: TextStyle(fontSize: 14, color: AppColors.textLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final authProvider = context.read<AuthProvider>();
                  final user = authProvider.currentUser;

                  if (user != null) {
                    if (user.isAdmin) {
                      Navigator.pushReplacementNamed(context, adminDashboard);
                    } else if (user.isTechnician) {
                      Navigator.pushReplacementNamed(
                        context,
                        technicianDashboard,
                      );
                    } else {
                      Navigator.pushReplacementNamed(context, login);
                    }
                  } else {
                    Navigator.pushReplacementNamed(context, login);
                  }
                },
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============= PARAMETER EXTRACTION =============
  static String extractId(String routeName, {String pattern = ':id'}) {
    final parts = routeName.split('/');
    final patternParts = pattern.split('/');
    for (int i = 0; i < parts.length && i < patternParts.length; i++) {
      if (patternParts[i].startsWith(':')) {
        return parts[i];
      }
    }
    return '';
  }

  static Map<String, String> extractParams(String routeName, String pattern) {
    final Map<String, String> params = {};
    final routeParts = routeName.split('/');
    final patternParts = pattern.split('/');

    for (int i = 0; i < routeParts.length && i < patternParts.length; i++) {
      if (patternParts[i].startsWith(':')) {
        final paramName = patternParts[i].substring(1);
        params[paramName] = routeParts[i];
      }
    }
    return params;
  }

  // ============= BUILD ROUTE PATHS =============
  static String buildRoute(String pattern, Map<String, String> params) {
    String route = pattern;
    params.forEach((key, value) {
      route = route.replaceAll(':$key', value);
    });
    return route;
  }

  // ============= CONVENIENCE NAVIGATION METHODS =============
  static void goToHome(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;

    if (user != null) {
      if (user.isAdmin) {
        pushAndRemoveUntil(context, adminDashboard, removeAll: true);
      } else if (user.isTechnician) {
        pushAndRemoveUntil(context, technicianDashboard, removeAll: true);
      } else {
        pushAndRemoveUntil(context, login, removeAll: true);
      }
    } else {
      pushAndRemoveUntil(context, login, removeAll: true);
    }
  }

  static void goToSettings(BuildContext context, {bool replace = false}) {
    if (replace) {
      pushReplacement(context, settings);
    } else {
      push(context, settings);
    }
  }

  static void goToQuoteDetails(
    BuildContext context,
    String quoteId, {
    bool replace = false,
  }) {
    final route = buildRoute(quoteDetails, {paramId: quoteId});
    if (replace) {
      pushReplacement(context, route);
    } else {
      push(context, route);
    }
  }

  static void goToInvoiceDetails(
    BuildContext context,
    String invoiceId, {
    bool replace = false,
  }) {
    final route = buildRoute(invoiceDetails, {paramId: invoiceId});
    if (replace) {
      pushReplacement(context, route);
    } else {
      push(context, route);
    }
  }

  static void goToCustomerDetails(
    BuildContext context,
    String customerId, {
    bool replace = false,
  }) {
    final route = buildRoute(customerDetails, {paramId: customerId});
    if (replace) {
      pushReplacement(context, route);
    } else {
      push(context, route);
    }
  }

  static void goToProductDetails(
    BuildContext context,
    String productId, {
    bool replace = false,
  }) {
    final route = buildRoute(editProduct, {paramId: productId});
    if (replace) {
      pushReplacement(context, route);
    } else {
      push(context, route);
    }
  }
}

// ============= ROUTE EXTENSIONS =============
extension AppRoutesExtensions on BuildContext {
  void pushRoute(String routeName, {Object? arguments}) {
    AppRoutes.push(this, routeName, arguments: arguments);
  }

  void pushReplacementRoute(String routeName, {Object? arguments}) {
    AppRoutes.pushReplacement(this, routeName, arguments: arguments);
  }

  void pushAndRemoveUntilRoute(
    String routeName, {
    Object? arguments,
    bool removeAll = false,
  }) {
    AppRoutes.pushAndRemoveUntil(
      this,
      routeName,
      arguments: arguments,
      removeAll: removeAll,
    );
  }

  void popRoute<T extends Object?>([T? result]) {
    AppRoutes.pop(this, result);
  }

  void popToRoot() {
    AppRoutes.popUntilRoot(this);
  }

  void goToHome() {
    AppRoutes.goToHome(this);
  }

  void goToSettings({bool replace = false}) {
    AppRoutes.goToSettings(this, replace: replace);
  }

  void goToQuoteDetails(String quoteId, {bool replace = false}) {
    AppRoutes.goToQuoteDetails(this, quoteId, replace: replace);
  }

  void goToInvoiceDetails(String invoiceId, {bool replace = false}) {
    AppRoutes.goToInvoiceDetails(this, invoiceId, replace: replace);
  }

  void goToCustomerDetails(String customerId, {bool replace = false}) {
    AppRoutes.goToCustomerDetails(this, customerId, replace: replace);
  }

  void goToProductDetails(String productId, {bool replace = false}) {
    AppRoutes.goToProductDetails(this, productId, replace: replace);
  }
}

// ============= PLACEHOLDER SCREENS FOR MISSING IMPLEMENTATIONS =============

class EditQuoteScreen extends StatelessWidget {
  final String quoteId;

  const EditQuoteScreen({super.key, required this.quoteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Quote'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Edit Quote Screen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quote ID: $quoteId',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditInvoiceScreen extends StatelessWidget {
  final String invoiceId;

  const EditInvoiceScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Invoice'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Edit Invoice Screen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invoice ID: $invoiceId',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomerDetailsScreen extends StatelessWidget {
  final String customerId;

  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Customer Details Screen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customer ID: $customerId',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditCustomerScreen extends StatelessWidget {
  final String customerId;

  const EditCustomerScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Customer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.edit, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Edit Customer Screen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Customer ID: $customerId',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class EditProductScreen extends StatelessWidget {
  final String productId;

  const EditProductScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Edit Product Screen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Product ID: $productId',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class QuoteStatusScreen extends StatelessWidget {
  final String quoteId;

  const QuoteStatusScreen({super.key, required this.quoteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quote Status'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assessment, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Quote Status Screen',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quote ID: $quoteId',
              style: TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
