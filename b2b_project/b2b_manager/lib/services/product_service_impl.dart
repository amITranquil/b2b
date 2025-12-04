// lib/services/product_service_impl.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/error/error_handler.dart';
import '../core/error/exceptions.dart';
import '../core/services/i_product_service.dart';
import '../models/product.dart';

/// Dependency Inversion Principle (DIP)
/// Concrete implementation of IProductService
class ProductServiceImpl implements IProductService {
  final String baseUrl;
  final http.Client httpClient;

  ProductServiceImpl({
    required this.baseUrl,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  @override
  Future<List<Product>> getProducts() async {
    try {
      final response = await httpClient.get(Uri.parse('$baseUrl/products'));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Product.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to load products',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.getProducts');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.getProducts');
      rethrow;
    }
  }

  @override
  Future<List<Product>> searchProducts(String searchTerm) async {
    try {
      if (searchTerm.trim().isEmpty) {
        return await getProducts();
      }

      final response = await httpClient.get(
        Uri.parse('$baseUrl/products/search/${Uri.encodeComponent(searchTerm)}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Product.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to search products',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.searchProducts');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.searchProducts');
      rethrow;
    }
  }

  @override
  Future<Product> getProduct(String productCode) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/products/${Uri.encodeComponent(productCode)}'),
      );

      if (response.statusCode == 200) {
        return Product.fromJson(json.decode(response.body));
      } else if (response.statusCode == 404) {
        throw NotFoundException('Ürün bulunamadı: $productCode');
      } else {
        throw ApiException(
          'Failed to load product',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.getProduct');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.getProduct');
      rethrow;
    }
  }

  @override
  Future<Product> updateMargin(String productCode, double marginPercentage) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/products/${Uri.encodeComponent(productCode)}/margin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(marginPercentage),
      );

      if (response.statusCode == 200) {
        return Product.fromJson(json.decode(response.body));
      } else {
        throw ApiException(
          'Failed to update margin',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.updateMargin');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.updateMargin');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> startScraping(String email, String password) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/products/scrape'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to start scraping',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.startScraping');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.startScraping');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> stopScraping() async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/products/stop-scraping'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to stop scraping',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.stopScraping');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.stopScraping');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getOutdatedProducts({int months = 3}) async {
    try {
      final response = await httpClient.get(
        Uri.parse('$baseUrl/products/outdated?months=$months'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to get outdated products',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.getOutdatedProducts');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.getOutdatedProducts');
      rethrow;
    }
  }

  @override
  Future<void> softDeleteProduct(String productCode) async {
    try {
      final response = await httpClient.delete(
        Uri.parse('$baseUrl/products/${Uri.encodeComponent(productCode)}/soft'),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to soft delete product',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.softDeleteProduct');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.softDeleteProduct');
      rethrow;
    }
  }

  @override
  Future<void> restoreProduct(String productCode) async {
    try {
      final response = await httpClient.put(
        Uri.parse('$baseUrl/products/${Uri.encodeComponent(productCode)}/restore'),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          'Failed to restore product',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.restoreProduct');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.restoreProduct');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> bulkSoftDelete(List<String> productCodes) async {
    try {
      final response = await httpClient.post(
        Uri.parse('$baseUrl/products/bulk-soft-delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(productCodes),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw ApiException(
          'Failed to bulk soft delete',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.bulkSoftDelete');
      throw NetworkException('Sunucuya bağlanılamadı', originalError: e);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProductService.bulkSoftDelete');
      rethrow;
    }
  }
}
