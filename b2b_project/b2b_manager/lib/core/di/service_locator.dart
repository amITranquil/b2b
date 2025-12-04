// lib/core/di/service_locator.dart
import 'package:http/http.dart' as http;
import '../services/i_product_service.dart';
import '../services/i_quote_service.dart';
import '../services/i_quote_item_manager.dart';
import '../services/i_pdf_service.dart';
import '../../services/product_service_impl.dart';
import '../../services/quote_service_impl.dart';
import '../../services/quote_item_manager_impl.dart';
import '../../services/pdf_export_service.dart';

/// Dependency Injection Container
/// Dependency Inversion Principle (DIP) implementation
class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  // Services
  late final IProductService productService;
  late final IQuoteService quoteService;
  late final IQuoteItemManager quoteItemManager;
  late final IPdfService pdfService;

  // Configuration
  static const String baseUrl = 'https://b2bapi.urlateknik.com:5000/api';

  /// Initialize all services
  void init() {
    // Shared HTTP client for better performance
    final httpClient = http.Client();

    // Initialize services with dependency injection
    productService = ProductServiceImpl(
      baseUrl: baseUrl,
      httpClient: httpClient,
    );

    quoteService = QuoteServiceImpl(
      baseUrl: baseUrl,
      httpClient: httpClient,
    );

    quoteItemManager = QuoteItemManagerImpl();

    pdfService = PdfExportService();
  }

  /// Dispose resources
  void dispose() {
    // Clean up if needed
  }

  /// Get instance
  static ServiceLocator get instance => _instance;
}

/// Extension for easy access
extension ServiceLocatorExtension on ServiceLocator {
  IProductService get products => productService;
  IQuoteService get quotes => quoteService;
  IQuoteItemManager get quoteItems => quoteItemManager;
  IPdfService get pdf => pdfService;
}
