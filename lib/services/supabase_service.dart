import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  static SupabaseService get instance => _instance;
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await dotenv.load(fileName: ".env");

      final supabaseUrl = dotenv.env['SUPABASE_URL'];
      final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (supabaseUrl == null || supabaseAnonKey == null) {
        throw Exception(
          'Missing Supabase credentials. Please check your .env file.\n'
          'Required: SUPABASE_URL and SUPABASE_ANON_KEY',
        );
      }

      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
        debug: kDebugMode,
      );

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ Supabase initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Supabase initialization failed: $e');
      }
      rethrow;
    }
  }

  SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception(
        'SupabaseService not initialized. '
        'Please call SupabaseService.initialize() first.',
      );
    }
    return Supabase.instance.client;
  }

  // Table names
  static const String usersTable = 'users';
  static const String customersTable = 'customers';
  static const String productsTable = 'products';
  static const String quotesTable = 'quotes';
  static const String quoteItemsTable = 'quote_items';
  static const String invoicesTable = 'invoices';
  static const String sitesTable = 'sites';
  static const String photosTable = 'photos';
  static const String syncQueueTable = 'sync_queue';

  // Storage buckets
  static const String photosBucket = 'photos';
}
