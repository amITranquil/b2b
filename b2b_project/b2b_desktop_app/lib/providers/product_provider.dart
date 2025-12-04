import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String _error = '';
  String _searchQuery = '';
  DateTime? _lastUpdated;

  List<Product> get products => _filteredProducts.isNotEmpty ? _filteredProducts : _products;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get searchQuery => _searchQuery;
  DateTime? get lastUpdated => _lastUpdated;
  bool get hasProducts => _products.isNotEmpty;

  // Tüm ürünleri yükle
  Future<void> loadProducts() async {
    if (_isLoading) {
      if (kDebugMode) {
        print('Already loading products, skipping...');
      }
      return; // Zaten yükleme yapılıyorsa bekle
    }

    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('Loading products from API...');
      }
      _products = await _apiService.getProducts();
      if (kDebugMode) {
        print('Loaded ${_products.length} products from API');
      }
      _filteredProducts = [];
      _lastUpdated = DateTime.now();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading products: $e');
      }
      _setError(e.toString());
      // Hata durumunda da loading'i kapat
    } finally {
      _setLoading(false);
    }
  }

  // Ürün ara
  Future<void> searchProducts(String query) async {
    _searchQuery = query;
    
    if (query.trim().isEmpty) {
      _filteredProducts = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      _filteredProducts = await _apiService.searchProducts(query);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Yerel arama (API çağrısı yapmadan)
  void filterProductsLocally(String query) {
    _searchQuery = query;
    
    if (query.trim().isEmpty) {
      _filteredProducts = [];
    } else {
      final lowercaseQuery = query.toLowerCase();
      _filteredProducts = _products.where((product) {
        return product.name.toLowerCase().contains(lowercaseQuery) ||
               product.productCode.toLowerCase().contains(lowercaseQuery) ||
               (product.category?.toLowerCase().contains(lowercaseQuery) ?? false);
      }).toList();
    }
    
    notifyListeners();
  }

  // Kar marjını güncelle
  Future<void> updateProductMargin(String productCode, double marginPercentage) async {
    _setLoading(true);
    _clearError();

    try {
      final updatedProduct = await _apiService.updateMargin(productCode, marginPercentage);
      
      // Yerel listede güncelle
      final index = _products.indexWhere((p) => p.productCode == productCode);
      if (index != -1) {
        _products[index] = updatedProduct;
      }

      // Filtrelenmiş listede de güncelle
      final filteredIndex = _filteredProducts.indexWhere((p) => p.productCode == productCode);
      if (filteredIndex != -1) {
        _filteredProducts[filteredIndex] = updatedProduct;
      }

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Manuel scraping başlat
  Future<void> startScraping(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      if (kDebugMode) {
        print('Starting scraping...');
      }
      final result = await _apiService.startScraping(email, password);
      if (kDebugMode) {
        print('Scraping result: $result');
      }
      
      // Scraping tamamlandıktan sonra ürünleri yeniden yükle
      if (kDebugMode) {
        print('Reloading products after scraping...');
      }
      await loadProducts();
      if (kDebugMode) {
        print('Product count after scraping: ${_products.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Scraping error: $e');
      }
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Scraping'i durdur
  Future<void> stopScraping() async {
    try {
      if (kDebugMode) {
        print('Stopping scraping...');
      }
      final result = await _apiService.stopScraping();
      if (kDebugMode) {
        print('Stop scraping result: $result');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Stop scraping error: $e');
      }
      rethrow;
    }
  }

  // API bağlantısını test et
  Future<bool> testApiConnection() async {
    try {
      return await _apiService.testConnection();
    } catch (e) {
      return false;
    }
  }

  // Ürün detayını getir
  Future<Product?> getProductDetail(String productCode) async {
    try {
      return await _apiService.getProduct(productCode);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // Arama sorgusunu temizle
  void clearSearch() {
    _searchQuery = '';
    _filteredProducts = [];
    notifyListeners();
  }

  // Yenile
  Future<void> refresh() async {
    await loadProducts();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = '';
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}