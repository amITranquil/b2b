import 'dart:convert';
import 'dart:developer';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class CacheService {
  static const String _productsKey = 'cached_products';
  static const String _productsTimestampKey = 'cached_products_timestamp';
  static const Duration _cacheDuration = Duration(hours: 24); // 24 saat cache

  // Products cache
  Future<void> cacheProducts(List<Product> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = products.map((p) => p.toJson()).toList();
      final jsonString = json.encode(jsonList);

      await prefs.setString(_productsKey, jsonString);
      await prefs.setInt(_productsTimestampKey, DateTime.now().millisecondsSinceEpoch);

      log('Products cached successfully: ${products.length} items');
    } catch (e) {
      log('Error caching products: $e');
    }
  }

  Future<List<Product>?> getCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_productsKey);
      final timestamp = prefs.getInt(_productsTimestampKey);

      if (jsonString == null || timestamp == null) {
        log('No cached products found');
        return null;
      }

      // Cache süresi kontrolü
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(cacheTime);

      if (difference > _cacheDuration) {
        log('Cache expired (${difference.inHours} hours old)');
        await clearProductsCache();
        return null;
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      final products = jsonList.map((json) => Product.fromJson(json)).toList();

      log('Loaded ${products.length} products from cache (${difference.inMinutes} minutes old)');
      return products;
    } catch (e) {
      log('Error loading cached products: $e');
      return null;
    }
  }

  Future<void> clearProductsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_productsKey);
      await prefs.remove(_productsTimestampKey);
      log('Products cache cleared');
    } catch (e) {
      log('Error clearing products cache: $e');
    }
  }

  Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_productsTimestampKey);

      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(cacheTime);

      return difference <= _cacheDuration;
    } catch (e) {
      log('Error checking cache validity: $e');
      return false;
    }
  }

  Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      log('All cache cleared');
    } catch (e) {
      log('Error clearing all cache: $e');
    }
  }
}
