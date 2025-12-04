import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class OutdatedProductsScreen extends StatefulWidget {
  const OutdatedProductsScreen({super.key});

  @override
  State<OutdatedProductsScreen> createState() => _OutdatedProductsScreenState();
}

class _OutdatedProductsScreenState extends State<OutdatedProductsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String _error = '';
  List<Product> _outdatedProducts = [];
  DateTime? _thresholdDate;
  int _thresholdMonths = 3;
  final Set<String> _selectedProducts = {};

  @override
  void initState() {
    super.initState();
    _loadOutdatedProducts();
  }

  Future<void> _loadOutdatedProducts() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final result = await _apiService.getOutdatedProducts(months: _thresholdMonths);
      final List<dynamic> productsData = result['products'];

      setState(() {
        _outdatedProducts = productsData.map((json) => Product.fromJson(json)).toList();
        _thresholdDate = DateTime.parse(result['thresholdDate']);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _bulkSoftDelete() async {
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen silinecek ürünleri seçin')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onay'),
        content: Text('${_selectedProducts.length} ürün silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final result = await _apiService.bulkSoftDelete(_selectedProducts.toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['deletedCount']} ürün başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
      }

      setState(() {
        _selectedProducts.clear();
      });

      _loadOutdatedProducts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getTimeSinceUpdate(DateTime lastUpdated) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdated);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years yıl önce';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months ay önce';
    } else {
      return '${difference.inDays} gün önce';
    }
  }

  Widget _buildProductCard(Product product) {
    final isSelected = _selectedProducts.contains(product.productCode);

    return Card(
      color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (selected) {
          setState(() {
            if (selected == true) {
              _selectedProducts.add(product.productCode);
            } else {
              _selectedProducts.remove(product.productCode);
            }
          });
        },
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Ürün Kodu: ${product.productCode}'),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  'Son güncelleme: ${_getTimeSinceUpdate(product.lastUpdated)}',
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Satış Fiyatı: ${CurrencyFormatter.format(product.myPrice)}',
              style: const TextStyle(color: Colors.green),
            ),
          ],
        ),
        secondary: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.warning_amber, color: Colors.orange, size: 30),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Eski Ürünler',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedProducts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_selectedProducts.length} seçili',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOutdatedProducts,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtre kartı
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtreleme Kriteri',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Son güncelleme: $_thresholdMonths ay ve üzeri',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (_thresholdDate != null)
                          Text(
                            'Tarihten önce: ${DateTimeFormatter.formatDate(_thresholdDate!)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          ),
                      ],
                    ),
                  ),
                  DropdownButton<int>(
                    value: _thresholdMonths,
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('1 ay')),
                      DropdownMenuItem(value: 2, child: Text('2 ay')),
                      DropdownMenuItem(value: 3, child: Text('3 ay')),
                      DropdownMenuItem(value: 6, child: Text('6 ay')),
                      DropdownMenuItem(value: 12, child: Text('1 yıl')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _thresholdMonths = value;
                        });
                        _loadOutdatedProducts();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // İçerik
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Hata: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadOutdatedProducts,
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      )
                    : _outdatedProducts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.green.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Harika! Eski ürün bulunmadı',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tüm ürünler güncel durumda',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey,
                                      ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: [
                              // İstatistik
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${_outdatedProducts.length} eski ürün bulundu',
                                      style: const TextStyle(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Ürün listesi
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _outdatedProducts.length,
                                  itemBuilder: (context, index) {
                                    return _buildProductCard(_outdatedProducts[index]);
                                  },
                                ),
                              ),
                            ],
                          ),
          ),
        ],
      ),
      floatingActionButton: _selectedProducts.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _bulkSoftDelete,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.delete_forever),
              label: Text('Sil (${_selectedProducts.length})'),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}
