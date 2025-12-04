import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';
import 'quote_form_screen.dart';
import 'quotes_screen.dart';
import 'manual_product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  ProductsScreenState createState() => ProductsScreenState();
}

class ProductsScreenState extends State<ProductsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  List<Product> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _error = '';
  late TabController _tabController;
  bool _hidePrices = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProducts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = '';
      });
    }

    try {
      final products = await _apiService.getAllProducts(); // Use union query
      if (mounted) {
        setState(() {
          _products = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $_error')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B2B Yönetimi'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ürün Listesi'),
            Tab(text: 'Teklifler'),
          ],
        ),
        actions: [
          // Manuel Ürün Ekle butonu
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: 'Manuel Ürün Ekle',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManualProductFormScreen(),
                ),
              );
              if (result == true) {
                _loadProducts(); // Reload products after adding
              }
            },
          ),
          // Yeni Teklif butonu
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Teklif Oluştur',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuoteFormScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(_hidePrices ? Icons.visibility_off : Icons.visibility),
            tooltip: _hidePrices ? 'Fiyatları Göster' : 'Fiyatları Gizle',
            onPressed: () {
              setState(() {
                _hidePrices = !_hidePrices;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeRight: true,
        child: TabBarView(
          controller: _tabController,
          children: [
            Container(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              child: _buildProductsList(),
            ),
            const QuotesScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    final filteredProducts = _products.where((product) {
      final search = _searchQuery.toLowerCase();
      return product.name.toLowerCase().contains(search) ||
          product.productCode.toLowerCase().contains(search);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Ürün Ara (İsim veya Kod)',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Hata: $_error'),
                          ElevatedButton(
                            onPressed: _loadProducts,
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    )
                  : _buildDataTable(filteredProducts),
        ),
      ],
    );
  }

  Widget _buildDataTable(List<Product> products) {
    if (products.isEmpty) {
      return const Center(
        child: Text('Ürün bulunamadı'),
      );
    }

    return ListView.builder(
      itemCount: products.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: product.isManual
            ? () async {
                // Manuel ürünse düzenleme formuna git
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManualProductFormScreen(
                      existingProduct: product,
                    ),
                  ),
                );
                // Eğer güncelleme veya silme yapıldıysa listeyi yenile
                if (result != null) {
                  _loadProducts();
                }
              }
            : null, // API ürünleri tıklanamaz
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ürün resmi
              _buildProductImage(product),
              const SizedBox(width: 12),

              // Ürün bilgileri
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Ürün kodu
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.productCode,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Ürün adı
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Fiyat bilgileri
                  _buildPriceInfo(product),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildProductImage(Product product) {
    return InkWell(
      onTap: () {
        if (product.localImagePath != null && product.localImagePath!.isNotEmpty) {
          _showImagePreview(product);
        }
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[100],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: product.localImagePath != null && product.localImagePath!.isNotEmpty
              ? Image.network(
                  'https://b2bapi.urlateknik.com:5000/${product.localImagePath}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.image_not_supported,
                      size: 40,
                      color: Colors.grey[400],
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                )
              : Icon(
                  product.isManual ? Icons.inventory_2 : Icons.image,
                  size: 40,
                  color: product.isManual ? Colors.blue[400] : Colors.grey[400],
                ),
        ),
      ),
    );
  }

  void _showImagePreview(Product product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 40,
                  maxHeight: MediaQuery.of(context).size.height - 40,
                ),
                child: InteractiveViewer(
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    'https://b2bapi.urlateknik.com:5000/${product.localImagePath}',
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_not_supported,
                        size: 100,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.black54,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInfo(Product product) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_hidePrices) ...[
                // Alış fiyatları açık - tüm fiyatları göster
                if (product.listPrice > 0) ...[
                  Text(
                    'Liste: ${CurrencyFormatter.format(product.listPrice)}',
                    style: TextStyle(
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  'Alış (KDV Hariç): ${CurrencyFormatter.format(product.buyPriceExcludingVat)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alış (KDV Dahil): ${CurrencyFormatter.format(product.buyPriceIncludingVat)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Satış (KDV Hariç): ${CurrencyFormatter.format(product.salePriceExcludingVat)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Satış (KDV Dahil): ${CurrencyFormatter.format(product.salePriceIncludingVat)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ] else ...[
                // Alış fiyatları gizli - sadece satış fiyatı
                Text(
                  'Satış: ${CurrencyFormatter.format(product.salePriceIncludingVat)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!_hidePrices) // Sadece fiyatlar görünürken iskonto ve kar marjını göster
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (product.discount1 > 0 || product.discount2 > 0 || product.discount3 > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDiscounts(product),
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Kar: ${PercentageFormatter.formatWithSymbol(product.marginPercentage)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _formatDiscounts(Product product) {
    List<String> discounts = [];
    if (product.discount1 > 0) discounts.add('${product.discount1}%');
    if (product.discount2 > 0) discounts.add('${product.discount2}%');
    if (product.discount3 > 0) discounts.add('${product.discount3}%');
    return discounts.isEmpty ? '-' : 'İsk: ${discounts.join('+')}';
  }
}
