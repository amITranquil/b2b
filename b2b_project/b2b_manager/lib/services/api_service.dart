import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/quote.dart';
import '../models/product.dart';
import '../config/api_config.dart';

class ApiService {
  final String baseUrl = ApiConfig.apiUrl;

  // ============ PRODUCT METHODS ============

  Future<List<Product>> getProducts() async {
    // Use getAllProducts to get union of API products and manual products
    return await getAllProducts();
  }

  Future<List<Product>> searchProducts(String searchTerm) async {
    try {
      if (searchTerm.trim().isEmpty) {
        return await getProducts();
      }

      final response = await http.get(
        Uri.parse('$baseUrl/products/search/${Uri.encodeComponent(searchTerm)}'),
      );

      log("Search products API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Product.fromJson(json)).toList();
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to search products: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in searchProducts: $e");
      throw Exception('Failed to search products: $e');
    }
  }

  Future<Product> getProduct(String productCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/${Uri.encodeComponent(productCode)}'),
      );

      log("Get product API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return Product.fromJson(json.decode(response.body));
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in getProduct: $e");
      throw Exception('Failed to load product: $e');
    }
  }

  Future<Product> updateMargin(String productCode, double marginPercentage) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/products/${Uri.encodeComponent(productCode)}/margin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(marginPercentage),
      );

      log("Update margin API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return Product.fromJson(json.decode(response.body));
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to update margin: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in updateMargin: $e");
      throw Exception('Failed to update margin: $e');
    }
  }

  Future<Map<String, dynamic>> startScraping(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/products/scrape'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      log("Start scraping API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to start scraping: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in startScraping: $e");
      throw Exception('Failed to start scraping: $e');
    }
  }

  Future<Map<String, dynamic>> stopScraping() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/products/stop-scraping'),
        headers: {'Content-Type': 'application/json'},
      );

      log("Stop scraping API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to stop scraping: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in stopScraping: $e");
      throw Exception('Failed to stop scraping: $e');
    }
  }

  Future<Map<String, dynamic>> getOutdatedProducts({int months = 3}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/outdated?months=$months'),
      );

      log("Get outdated products API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to get outdated products: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in getOutdatedProducts: $e");
      throw Exception('Failed to get outdated products: $e');
    }
  }

  Future<void> softDeleteProduct(String productCode) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/products/${Uri.encodeComponent(productCode)}/soft'),
      );

      log("Soft delete product API response status: ${response.statusCode}");

      if (response.statusCode != 200) {
        log("Error response body: ${response.body}");
        throw Exception('Failed to soft delete product: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in softDeleteProduct: $e");
      throw Exception('Failed to soft delete product: $e');
    }
  }

  Future<void> restoreProduct(String productCode) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/products/${Uri.encodeComponent(productCode)}/restore'),
      );

      log("Restore product API response status: ${response.statusCode}");

      if (response.statusCode != 200) {
        log("Error response body: ${response.body}");
        throw Exception('Failed to restore product: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in restoreProduct: $e");
      throw Exception('Failed to restore product: $e');
    }
  }

  Future<Map<String, dynamic>> bulkSoftDelete(List<String> productCodes) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/products/bulk-soft-delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(productCodes),
      );

      log("Bulk soft delete API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to bulk soft delete: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in bulkSoftDelete: $e");
      throw Exception('Failed to bulk soft delete: $e');
    }
  }

  Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ============ QUOTE METHODS ============

  Future<List<Quote>> getQuotes() async {
    try {
      log("Fetching quotes from $baseUrl/quotes");
      final response = await http.get(Uri.parse('$baseUrl/quotes'));
      log("Quotes API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = response.body;
        log("Quote response length: ${responseBody.length}");

        if (responseBody.isEmpty) {
          log("Empty response body from quotes API");
          return [];
        }

        try {
          List<dynamic> jsonList = json.decode(responseBody);
          final quotes = jsonList.map((json) => Quote.fromJson(json)).toList();
          log("Successfully parsed ${quotes.length} quotes");
          return quotes;
        } catch (parseError) {
          log("JSON parsing error: $parseError");
          log("Response body: $responseBody");
          throw Exception('Failed to parse quotes response: $parseError');
        }
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to load quotes: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in getQuotes: $e");
      throw Exception('Failed to connect to server: $e');
    }
  }

  Future<Quote> getQuote(String id) async {
    try {
      log("Fetching quote with id: $id");
      final response = await http.get(Uri.parse('$baseUrl/quotes/$id'));
      log("Quote API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          throw Exception('Empty response when fetching quote $id');
        }

        try {
          final quote = Quote.fromJson(json.decode(responseBody));
          log("Successfully parsed quote: ${quote.id}");
          return quote;
        } catch (parseError) {
          log("JSON parsing error: $parseError");
          log("Response body: $responseBody");
          throw Exception('Failed to parse quote response: $parseError');
        }
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to load quote: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in getQuote: $e");
      throw Exception('Failed to fetch quote: $e');
    }
  }

  Future<Quote> createQuote(Quote quote) async {
    try {
      log("Creating new quote for: ${quote.customerName}");

      // Quote model toJson'da zaten ID'leri integer'a çeviriyor
      final quoteToSend = quote.toJson();

      log("Quote request data: ${json.encode(quoteToSend)}");

      final response = await http.post(
        Uri.parse('$baseUrl/quotes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(quoteToSend),
      );

      log("Create quote response status: ${response.statusCode}");

      if (response.statusCode == 201) {
        final responseBody = response.body;
        log("Create quote response: $responseBody");

        try {
          final createdQuote = Quote.fromJson(json.decode(responseBody));
          log("Successfully created quote with ID: ${createdQuote.id}");
          return createdQuote;
        } catch (parseError) {
          log("JSON parsing error: $parseError");
          log("Response body: $responseBody");
          throw Exception('Failed to parse created quote response: $parseError');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Yetkilendirme hatası: Lütfen yeniden giriş yapın');
      } else if (response.statusCode == 403) {
        throw Exception('Bu işlem için yetkiniz bulunmuyor');
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Teklif oluşturma hatası: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log("Exception in createQuote: $e");
      throw Exception('Teklif oluşturma hatası: $e');
    }
  }

  Future<Quote> updateQuote(Quote quote) async {
    try {
      log("Updating quote with ID: ${quote.id}");

      // Quote model toJson'da zaten ID'leri integer'a çeviriyor
      final quoteToSend = quote.toJson();

      log("Quote update request data: ${json.encode(quoteToSend)}");

      final response = await http.put(
        Uri.parse('$baseUrl/quotes/${quote.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(quoteToSend),
      );

      log("Update quote response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = response.body;
        log("Update quote response: $responseBody");

        try {
          final updatedQuote = Quote.fromJson(json.decode(responseBody));
          log("Successfully updated quote with ID: ${updatedQuote.id}");
          return updatedQuote;
        } catch (parseError) {
          log("JSON parsing error: $parseError");
          log("Response body: $responseBody");
          throw Exception('Failed to parse updated quote response: $parseError');
        }
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to update quote: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      log("Exception in updateQuote: $e");
      throw Exception('Failed to update quote: $e');
    }
  }

  Future<void> deleteQuote(String id) async {
    try {
      log("Deleting quote with ID: $id");
      final response = await http.delete(Uri.parse('$baseUrl/quotes/$id'));
      log("Delete quote response status: ${response.statusCode}");

      if (response.statusCode != 204) {
        log("Error response body: ${response.body}");
        throw Exception('Failed to delete quote: ${response.statusCode}');
      }

      log("Successfully deleted quote with ID: $id");
    } catch (e) {
      log("Exception in deleteQuote: $e");
      throw Exception('Failed to connect to server: $e');
    }
  }

  Future<Quote> toggleDraftStatus(String id) async {
    try {
      log("Toggling draft status for quote ID: $id");
      final response = await http.put(
        Uri.parse('$baseUrl/quotes/$id/toggle-draft'),
        headers: {'Content-Type': 'application/json'},
      );

      log("Toggle draft response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = response.body;
        log("Toggle draft response: $responseBody");

        try {
          final updatedQuote = Quote.fromJson(json.decode(responseBody));
          log("Successfully toggled draft status: isDraft=${updatedQuote.isDraft}");
          return updatedQuote;
        } catch (parseError) {
          log("JSON parsing error: $parseError");
          log("Response body: $responseBody");
          throw Exception('Failed to parse response: $parseError');
        }
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to toggle draft status: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in toggleDraftStatus: $e");
      throw Exception('Failed to toggle draft status: $e');
    }
  }

  // ============ HELPER METHODS ============

  String handleApiError(dynamic error) {
    if (error is Exception) {
      final message = error.toString();

      if (message.contains('SocketException') ||
          message.contains('Failed host lookup')) {
        return 'Sunucuya bağlanılamadı. Lütfen internet bağlantınızı kontrol edin.';
      } else if (message.contains('401')) {
        return 'Oturum süresi dolmuş olabilir. Lütfen yeniden giriş yapın.';
      } else if (message.contains('403')) {
        return 'Bu işlem için yetkiniz bulunmuyor.';
      } else if (message.contains('timeout')) {
        return 'Sunucu yanıt vermedi. Lütfen daha sonra tekrar deneyin.';
      }
    }

    return 'Beklenmeyen bir hata oluştu: $error';
  }

  // ============ MANUAL PRODUCT METHODS ============

  /// Get all products (union of API products and manual products)
  Future<List<Product>> getAllProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products/all'));
      log("Get all products API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Product.fromJson(json)).toList();
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to load all products: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in getAllProducts: $e");
      throw Exception('Failed to load all products: $e');
    }
  }

  /// Create manual product
  Future<Product> createManualProduct(Product product) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/manualproducts'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': product.name,
          'buyPrice': product.buyPriceExcludingVat,
          'profitMargin': product.marginPercentage,
          'vatRate': product.vatRate,
        }),
      );

      log("🔍 CREATE MANUAL PRODUCT - Status: ${response.statusCode}");
      log("🔍 Response body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        log("✅ Product created successfully");
        return Product.fromJson(json.decode(response.body));
      } else if (response.statusCode == 409) {
        // Conflict - Duplicate product name
        log("❌ DUPLICATE DETECTED - Status 409");
        log("❌ Response: ${response.body}");
        final errorBody = json.decode(response.body);
        final message = errorBody['message'] ?? 'Bu isimde bir ürün zaten mevcut';
        log("❌ Throwing exception: 409 Conflict: $message");
        throw Exception('409 Conflict: $message');
      } else if (response.statusCode == 400) {
        log("❌ Bad request error: ${response.body}");
        throw Exception('400 Bad Request: ${response.body}');
      } else {
        log("❌ Error response body: ${response.body}");
        throw Exception('Failed to create manual product: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in createManualProduct: $e");
      rethrow;
    }
  }

  /// Update manual product
  Future<Product> updateManualProduct(Product product) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/manualproducts/${product.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': product.id,
          'name': product.name,
          'buyPrice': product.buyPriceExcludingVat,
          'profitMargin': product.marginPercentage,
          'vatRate': product.vatRate,
        }),
      );

      log("Update manual product API response status: ${response.statusCode}");

      if (response.statusCode == 204 || response.statusCode == 200) {
        // Return the updated product
        return product;
      } else if (response.statusCode == 409) {
        // Conflict - Duplicate product name
        log("Duplicate product error in update: ${response.body}");
        final errorBody = json.decode(response.body);
        final message = errorBody['message'] ?? 'Bu isimde bir ürün zaten mevcut';
        throw Exception('409 Conflict: $message');
      } else if (response.statusCode == 400) {
        log("Bad request error in update: ${response.body}");
        throw Exception('400 Bad Request: ${response.body}');
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to update manual product: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in updateManualProduct: $e");
      rethrow;
    }
  }

  /// Update manual product margin
  Future<void> updateManualProductMargin(int id, double profitMargin) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/manualproducts/$id/margin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(profitMargin),
      );

      log("Update manual product margin API response status: ${response.statusCode}");

      if (response.statusCode != 204 && response.statusCode != 200) {
        log("Error response body: ${response.body}");
        throw Exception('Failed to update manual product margin: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in updateManualProductMargin: $e");
      throw Exception('Failed to update manual product margin: $e');
    }
  }

  /// Delete manual product (soft delete)
  Future<void> deleteManualProduct(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/manualproducts/$id'),
        headers: {'Content-Type': 'application/json'},
      );

      log("Delete manual product API response status: ${response.statusCode}");

      if (response.statusCode != 204 && response.statusCode != 200) {
        log("Error response body: ${response.body}");
        throw Exception('Failed to delete manual product: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in deleteManualProduct: $e");
      throw Exception('Failed to delete manual product: $e');
    }
  }
}
