import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'config/app_theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/quote_provider.dart';
import 'providers/product_provider.dart';
import 'providers/customer_provider.dart';
import 'providers/invoice_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/log_provider.dart';
import 'providers/approval_provider.dart';
import 'services/supabase_service.dart';
import 'services/database_helper.dart';
import 'services/database_service.dart';
import 'screens/auth/splash_screen.dart';

// Simple logging function
void _log(String message) {
  if (kDebugMode) {
    print('[Quickfix] $message');
  }
}

void _logError(String message, [dynamic error, StackTrace? stackTrace]) {
  if (kDebugMode) {
    print('[Quickfix ERROR] $message');
    if (error != null) print('Error: $error');
    if (stackTrace != null) print('StackTrace: $stackTrace');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_KE', null);

  try {
    // Initialize Hive for local storage
    await Hive.initFlutter();
    _log('✅ Hive initialized successfully');
  } catch (e, stackTrace) {
    _logError('Failed to initialize Hive', e, stackTrace);
  }

  try {
    // Initialize Supabase
    await SupabaseService.initialize();
    _log('✅ Supabase initialized successfully');
  } catch (e, stackTrace) {
    _logError('Failed to initialize Supabase', e, stackTrace);
  }

  try {
    // Initialize Database
    final dbHelper = DatabaseHelper();
    await dbHelper.database;
    _log('✅ Database initialized successfully');

    // Sync data with foreign keys disabled
    try {
      final dbService = DatabaseService();
      await dbService.syncWithForeignKeysDisabled();
      _log('✅ Database sync completed successfully');

      // Run repair to fix any remaining foreign key issues
      await dbService.repairAndCleanup();
      _log('✅ Database repair completed successfully');
    } catch (e, stackTrace) {
      _logError('Error during sync/repair', e, stackTrace);
      // Continue running the app even if sync fails
      // The app will fall back to local data
    }
  } catch (e, stackTrace) {
    _logError('Failed to initialize database', e, stackTrace);
    // Continue running the app even if database fails
    // The app will try to recover later
  }

  runApp(const QuickfixApp());
}

class QuickfixApp extends StatelessWidget {
  const QuickfixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => QuoteProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CustomerProvider()),
        ChangeNotifierProvider(create: (_) => InvoiceProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LogProvider()),
        ChangeNotifierProvider(create: (_) => ApprovalProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Quickfix Plumbers',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settingsProvider.darkModeEnabled
                ? ThemeMode.dark
                : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            onUnknownRoute: (settings) {
              _logError('Unknown route: ${settings.name}');
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Page Not Found',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The page you\'re looking for doesn\'t exist.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () {
                            final authProvider = context.read<AuthProvider>();
                            final user = authProvider.currentUser;

                            if (user != null) {
                              if (user.isAdmin) {
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.adminDashboard,
                                );
                              } else if (user.isTechnician) {
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.technicianDashboard,
                                );
                              } else {
                                Navigator.pushReplacementNamed(
                                  context,
                                  AppRoutes.login,
                                );
                              }
                            } else {
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.login,
                              );
                            }
                          },
                          child: const Text('Go to Dashboard'),
                        ),
                      ],
                    ),
                  ),
                ),
                settings: settings,
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
