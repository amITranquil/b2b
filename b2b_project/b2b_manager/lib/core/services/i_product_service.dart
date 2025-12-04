// lib/core/services/i_product_service.dart
import '../../models/product.dart';

/// Interface Segregation Principle (ISP)
/// Product işlemleri için ayrı interface
abstract class IProductService {
  Future<List<Product>> getProducts();
  Future<List<Product>> searchProducts(String searchTerm);
  Future<Product> getProduct(String productCode);
  Future<Product> updateMargin(String productCode, double marginPercentage);
  Future<Map<String, dynamic>> startScraping(String email, String password);
  Future<Map<String, dynamic>> stopScraping();
  Future<Map<String, dynamic>> getOutdatedProducts({int months = 3});
  Future<void> softDeleteProduct(String productCode);
  Future<void> restoreProduct(String productCode);
  Future<Map<String, dynamic>> bulkSoftDelete(List<String> productCodes);
}
