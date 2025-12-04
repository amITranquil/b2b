import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/quote.dart';
import '../config/api_config.dart';

class ApiService {
  final String baseUrl = ApiConfig.apiUrl;
  final http.Client _client = http.Client();

  Future<List<Product>> getProducts() async {
    try {
      // Union endpoint - hem API ürünleri hem manuel ürünleri getirir
      final response = await _client.get(Uri.parse('$baseUrl/products/all'));
      log("Products API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Product.fromJson(json)).toList();
      } else {
        log("Error loading products: status ${response.statusCode}");
        throw Exception('Ürünler yüklenemedi');
      }
    } catch (e) {
      log("Exception in getProducts: ${e.runtimeType}");
      throw Exception('Sunucuya bağlanılamadı');
    }
  }

  Future<List<Product>> searchProducts(String searchTerm) async {
    try {
      if (searchTerm.trim().isEmpty) {
        return await getProducts();
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/products/search/${Uri.encodeComponent(searchTerm)}'),
      );

      log("Search products API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Product.fromJson(json)).toList();
      } else {
        log("Error searching products: status ${response.statusCode}");
        throw Exception('Ürün araması başarısız');
      }
    } catch (e) {
      log("Exception in searchProducts: ${e.runtimeType}");
      throw Exception('Arama yapılamadı');
    }
  }

  // Quote endpoints
  Future<List<Quote>> getQuotes() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/quotes'));
      log("Quotes API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Quote.fromJson(json)).toList();
      } else {
        log("Error loading quotes: status ${response.statusCode}");
        throw Exception('Teklifler yüklenemedi');
      }
    } catch (e) {
      log("Exception in getQuotes: ${e.runtimeType}");
      throw Exception('Sunucuya bağlanılamadı');
    }
  }

  Future<Quote> getQuote(int id) async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/quotes/$id'));
      log("Quote API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        return Quote.fromJson(json.decode(response.body));
      } else {
        log("Error loading quote: status ${response.statusCode}");
        throw Exception('Teklif yüklenemedi');
      }
    } catch (e) {
      log("Exception in getQuote: ${e.runtimeType}");
      throw Exception('Sunucuya bağlanılamadı');
    }
  }

  Future<List<Quote>> searchQuotesByCustomer(String customerName) async {
    try {
      if (customerName.trim().isEmpty) {
        return await getQuotes();
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/quotes/customer/${Uri.encodeComponent(customerName)}'),
      );

      log("Search quotes API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Quote.fromJson(json)).toList();
      } else {
        log("Error searching quotes: status ${response.statusCode}");
        throw Exception('Teklif araması başarısız');
      }
    } catch (e) {
      log("Exception in searchQuotesByCustomer: ${e.runtimeType}");
      throw Exception('Arama yapılamadı');
    }
  }

  void dispose() {
    _client.close();
  }
}
