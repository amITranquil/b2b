// lib/services/api_service.dart
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../models/sale.dart';
import '../config/api_config.dart';

class ApiService {
  final String baseUrl = ApiConfig.apiUrl;

  // ============ PRODUCT METHODS ============

  /// Get all products
  Future<List<Product>> getProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products/all'));
      log("Get products API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        List<dynamic> jsonList = json.decode(response.body);
        return jsonList.map((json) => Product.fromJson(json)).toList();
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to load products: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in getProducts: $e");
      throw Exception('Failed to load products: $e');
    }
  }

  /// Search products
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

  // ============ SALES METHODS ============
  // TODO: Backend implement edilince bu methodlar aktif olacak

  /// Create a new sale
  Future<Sale> createSale(Sale sale) async {
    try {
      log("Creating new sale");

      final response = await http.post(
        Uri.parse('$baseUrl/sales'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(sale.toJson()),
      );

      log("Create sale response status: ${response.statusCode}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        final createdSale = Sale.fromJson(json.decode(response.body));
        log("Successfully created sale with ID: ${createdSale.id}");
        return createdSale;
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to create sale: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in createSale: $e");
      throw Exception('Failed to create sale: $e');
    }
  }

  /// Get all sales
  Future<List<Sale>> getSales({SaleStatus? status}) async {
    try {
      String url = '$baseUrl/sales';
      if (status != null) {
        url += '?status=${status.name}';
      }

      log("Fetching sales from $url");
      final response = await http.get(Uri.parse(url));
      log("Sales API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = response.body;

        if (responseBody.isEmpty) {
          log("Empty response body from sales API");
          return [];
        }

        List<dynamic> jsonList = json.decode(responseBody);
        final sales = jsonList.map((json) => Sale.fromJson(json)).toList();
        log("Successfully parsed ${sales.length} sales");
        return sales;
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to load sales: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in getSales: $e");
      throw Exception('Failed to load sales: $e');
    }
  }

  /// Get sale by ID
  Future<Sale> getSale(String id) async {
    try {
      log("Fetching sale with id: $id");
      final response = await http.get(Uri.parse('$baseUrl/sales/$id'));
      log("Sale API response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final responseBody = response.body;
        if (responseBody.isEmpty) {
          throw Exception('Empty response when fetching sale $id');
        }

        final sale = Sale.fromJson(json.decode(responseBody));
        log("Successfully parsed sale: ${sale.id}");
        return sale;
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to load sale: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in getSale: $e");
      throw Exception('Failed to fetch sale: $e');
    }
  }

  /// Update sale (change status)
  Future<Sale> updateSale(String id, Sale sale) async {
    try {
      log("Updating sale with id: $id");

      final response = await http.put(
        Uri.parse('$baseUrl/sales/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(sale.toJson()),
      );

      log("Update sale response status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final updatedSale = Sale.fromJson(json.decode(response.body));
        log("Successfully updated sale with ID: ${updatedSale.id}");
        return updatedSale;
      } else {
        log("Error response body: ${response.body}");
        throw Exception('Failed to update sale: ${response.statusCode}');
      }
    } catch (e) {
      log("Exception in updateSale: $e");
      throw Exception('Failed to update sale: $e');
    }
  }

  /// Cancel sale (update status to cancelled)
  Future<Sale> cancelSale(String id) async {
    try {
      log("Cancelling sale with id: $id");

      // Önce satışı çek
      final sale = await getSale(id);

      // Status'u cancelled yap
      final cancelledSale = Sale(
        id: sale.id,
        createdAt: sale.createdAt,
        items: sale.items,
        subtotal: sale.subtotal,
        cardCommission: sale.cardCommission,
        total: sale.total,
        paymentMethod: sale.paymentMethod,
        status: SaleStatus.cancelled,
      );

      // Güncelle
      return await updateSale(id, cancelledSale);
    } catch (e) {
      log("Exception in cancelSale: $e");
      throw Exception('Failed to cancel sale: $e');
    }
  }

  /// Test connection
  Future<bool> testConnection() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
