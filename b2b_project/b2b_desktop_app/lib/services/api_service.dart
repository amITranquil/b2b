import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';

class ApiService {
  static const String baseUrl = 'https://b2bapi.urlateknik.com:5000/api';
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(hours: 2), // Büyük pagination scraping için 2 saat timeout
      sendTimeout: const Duration(hours: 2),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Sadece debug modda loglama yap ve hassas bilgileri gizle
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: false, // Credentials koruması için kapatıldı
        responseBody: false, // Performans için kapatıldı
        requestHeader: false, // Headers'da token olabilir
        // ignore: avoid_print
        logPrint: (obj) => print('[API] $obj'),
      ));
    }
  }

  // Tüm ürünleri getir
  Future<List<Product>> getProducts() async {
    try {
      final response = await _dio.get('/products');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load products: $e');
    }
  }

  // Ürün arama
  Future<List<Product>> searchProducts(String searchTerm) async {
    try {
      if (searchTerm.trim().isEmpty) {
        return await getProducts();
      }

      final response = await _dio.get('/products/search/${Uri.encodeComponent(searchTerm)}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Product.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to search products: $e');
    }
  }

  // Belirli bir ürünü getir
  Future<Product> getProduct(String productCode) async {
    try {
      final response = await _dio.get('/products/${Uri.encodeComponent(productCode)}');
      
      if (response.statusCode == 200) {
        return Product.fromJson(response.data);
      } else {
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to load product: $e');
    }
  }

  // Kar marjını güncelle
  Future<Product> updateMargin(String productCode, double marginPercentage) async {
    try {
      final response = await _dio.put(
        '/products/${Uri.encodeComponent(productCode)}/margin',
        data: marginPercentage,
      );
      
      if (response.statusCode == 200) {
        return Product.fromJson(response.data);
      } else {
        throw Exception('Failed to update margin: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to update margin: $e');
    }
  }

  // Manuel scraping başlat
  Future<Map<String, dynamic>> startScraping(String email, String password) async {
    try {
      final response = await _dio.post(
        '/products/scrape',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to start scraping: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to start scraping: $e');
    }
  }

  // Scraping'i durdur
  Future<Map<String, dynamic>> stopScraping() async {
    try {
      final response = await _dio.post('/products/stop-scraping');
      
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to stop scraping: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to stop scraping: $e');
    }
  }

  // API bağlantısını test et
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/products', queryParameters: {'limit': 1});
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 3 aydan eski ürünleri getir
  Future<Map<String, dynamic>> getOutdatedProducts({int months = 3}) async {
    try {
      final response = await _dio.get('/products/outdated', queryParameters: {'months': months});

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get outdated products: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to get outdated products: $e');
    }
  }

  // Ürünü soft delete yap
  Future<void> softDeleteProduct(String productCode) async {
    try {
      final response = await _dio.delete('/products/${Uri.encodeComponent(productCode)}/soft');

      if (response.statusCode != 200) {
        throw Exception('Failed to soft delete product: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to soft delete product: $e');
    }
  }

  // Silinmiş ürünü geri yükle
  Future<void> restoreProduct(String productCode) async {
    try {
      final response = await _dio.put('/products/${Uri.encodeComponent(productCode)}/restore');

      if (response.statusCode != 200) {
        throw Exception('Failed to restore product: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to restore product: $e');
    }
  }

  // Toplu soft delete
  Future<Map<String, dynamic>> bulkSoftDelete(List<String> productCodes) async {
    try {
      final response = await _dio.post('/products/bulk-soft-delete', data: productCodes);

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw Exception('Failed to bulk soft delete: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      throw Exception('Failed to bulk soft delete: $e');
    }
  }

  void dispose() {
    _dio.close();
  }
}