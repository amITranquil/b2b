import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../config/api_config.dart';
import '../widgets/skeleton_loader.dart';

enum SortOption {
  none,
  priceLowToHigh,
  priceHighToLow,
}

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ThemeService _themeService = ThemeService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _error;

  // Sorting
  SortOption _currentSort = SortOption.none;

  @override
  void initState() {
    super.initState();
    _themeService.loadThemePreference();
    _checkAuthAndRedirect();
    _loadProducts();
  }

  Future<void> _checkAuthAndRedirect() async {
    final isAuth = await _authService.isAuthenticated();
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
      });

      // Direkt link ile erişim engelleme (opsiyonel - home'dan gelenleri de engellemez)
      // Sadece authentication durumunu set ediyoruz
    }
  }

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final products = await _apiService.getProducts(forceRefresh: forceRefresh);
      setState(() {
        _products = products.where((p) => !p.isDeleted).toList();
        _filteredProducts = _products;
        _sortProducts();
        _isLoading = false;
      });

      if (forceRefresh && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ürünler güncellendi'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Ürünler yüklenemedi: $e';
        _isLoading = false;
      });
    }
  }

  void _sortProducts() {
    List<Product> sorted;

    switch (_currentSort) {
      case SortOption.priceLowToHigh:
        sorted = List.from(_filteredProducts);
        sorted.sort((a, b) => a.myPrice.compareTo(b.myPrice));
        break;
      case SortOption.priceHighToLow:
        sorted = List.from(_filteredProducts);
        sorted.sort((a, b) => b.myPrice.compareTo(a.myPrice));
        break;
      case SortOption.none:
        // Orijinal listeyi kopyala
        sorted = List.from(_products);
        // Arama varsa filtrele
        if (_searchController.text.isNotEmpty) {
          final upperQuery = _toUpperCaseTurkish(_searchController.text);
          sorted = sorted.where((product) {
            return _toUpperCaseTurkish(product.name).contains(upperQuery) ||
                _toUpperCaseTurkish(product.productCode).contains(upperQuery);
          }).toList();
        }
        break;
    }

    _filteredProducts = sorted;
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onSortChanged(SortOption? newSort) {
    if (newSort == null || newSort == _currentSort) return;

    setState(() {
      _currentSort = newSort;
      _sortProducts();
    });

    _scrollToTop();
  }

  String _toUpperCaseTurkish(String text) {
    // Türkçe karakterleri koruyarak büyük harfe çevir
    return text
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .replaceAll('ş', 'Ş')
        .replaceAll('ğ', 'Ğ')
        .replaceAll('ü', 'Ü')
        .replaceAll('ö', 'Ö')
        .replaceAll('ç', 'Ç')
        .toUpperCase();
  }

  void _filterProducts(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _products;
        _sortProducts();
      });
      _scrollToTop();
      return;
    }

    final upperQuery = _toUpperCaseTurkish(query);
    setState(() {
      _filteredProducts = _products.where((product) {
        return _toUpperCaseTurkish(product.name).contains(upperQuery) ||
            _toUpperCaseTurkish(product.productCode).contains(upperQuery);
      }).toList();
      _sortProducts();
    });

    _scrollToTop();
  }

  String _formatCurrency(double value) {
    final formatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    // Theme artık MaterialApp seviyesinde yönetiliyor
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('URLA TEKNİK - Ürün Kataloğu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Ana Sayfa',
            onPressed: () => Navigator.pushNamed(context, '/'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenile',
            onPressed: _isLoading ? null : () => _loadProducts(forceRefresh: true),
          ),
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? 'Açık Tema' : 'Koyu Tema',
            onPressed: _themeService.toggleTheme,
          ),
        ],
      ),
      body: _buildBody(isDarkMode),
    );
  }

  Widget _buildBody(bool isDarkMode) {
    if (_isLoading) {
      return const SkeletonLoader(itemCount: 30);
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search Field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                return TextEditingValue(
                  text: _toUpperCaseTurkish(newValue.text),
                  selection: newValue.selection,
                );
              }),
            ],
            decoration: InputDecoration(
              labelText: 'Ürün Ara',
              hintText: 'Ürün adı veya kodu ile arama yapın',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _filterProducts('');
                      },
                    )
                  : null,
            ),
            onChanged: _filterProducts,
          ),
        ),

        // Sorting Dropdown
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.sort, size: 20),
              const SizedBox(width: 8),
              const Text('Sırala:', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<SortOption>(
                  value: _currentSort,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: SortOption.none,
                      child: Text('Varsayılan'),
                    ),
                    DropdownMenuItem(
                      value: SortOption.priceLowToHigh,
                      child: Text('Fiyat: Düşükten Yükseğe ↑'),
                    ),
                    DropdownMenuItem(
                      value: SortOption.priceHighToLow,
                      child: Text('Fiyat: Yüksekten Düşüğe ↓'),
                    ),
                  ],
                  onChanged: _onSortChanged,
                ),
              ),
            ],
          ),
        ),

        // Results count
        if (_filteredProducts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${_filteredProducts.length} ürün',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Product Grid
        Expanded(
          child: _filteredProducts.isEmpty
              ? const Center(child: Text('Ürün bulunamadı'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount;
                    if (constraints.maxWidth > 1200) {
                      crossAxisCount = 4;
                    } else if (constraints.maxWidth > 800) {
                      crossAxisCount = 3;
                    } else if (constraints.maxWidth > 600) {
                      crossAxisCount = 2;
                    } else {
                      crossAxisCount = 1;
                    }

                    return GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(_filteredProducts[index], isDarkMode);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product, bool isDarkMode) {
    final imageUrl = ApiConfig.getImageUrl(product.localImagePath ?? product.imageUrl);
    final hasImage = imageUrl.isNotEmpty &&
                     (product.localImagePath != null || product.imageUrl != null);

    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: hasImage
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  )
                : Container(
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    ),
                  ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    product.productCode,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    product.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                  ),
                  const Spacer(),
                  if (!_isAuthenticated) ...[
                    // PIN girilmemiş - Sadece Satış (KDV Dahil) göster
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.green[900]?.withValues(alpha: 0.3) : Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            'Satış Fiyatı',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode ? Colors.grey[300] : Colors.black87,
                            ),
                          ),
                          SelectableText(
                            _formatCurrency(product.salePriceIncludingVat),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.green[300] : Colors.green[700],
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // PIN girilmiş - Tüm fiyatları göster
                    _buildDetailRow('Liste Fiyatı', product.listPrice, isDarkMode),
                    const SizedBox(height: 4),
                    _buildDetailRow('Alış (KDV Hariç)', product.buyPriceExcludingVat, isDarkMode),
                    const SizedBox(height: 4),
                    _buildDetailRow('Alış (KDV Dahil)', product.buyPriceIncludingVat, isDarkMode),
                    const SizedBox(height: 4),
                    _buildDetailRow('Satış (KDV Hariç)', product.salePriceExcludingVat, isDarkMode),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.green[900]?.withValues(alpha: 0.3) : Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SelectableText(
                            'Satış (KDV Dahil)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.grey[300] : Colors.black87,
                            ),
                          ),
                          SelectableText(
                            _formatCurrency(product.salePriceIncludingVat),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.green[300] : Colors.green[700],
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.orange[900]?.withValues(alpha: 0.3) : Colors.orange[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SelectableText(
                              'İskonto: %${((product.discount1 + product.discount2 + product.discount3)).toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.orange[300] : Colors.orange[700],
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.blue[900]?.withValues(alpha: 0.3) : Colors.blue[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: SelectableText(
                              'Kar: %${product.marginPercentage.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.blue[300] : Colors.blue[700],
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, bool isDarkMode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SelectableText(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        SelectableText(
          _formatCurrency(value),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: isDarkMode ? Colors.grey[200] : Colors.black87,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
