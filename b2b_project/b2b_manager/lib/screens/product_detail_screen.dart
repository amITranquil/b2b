import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/formatters.dart';
import '../services/api_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _marginController = TextEditingController();
  bool _isUpdating = false;
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _marginController.text = _currentProduct.marginPercentage.toString();
  }

  @override
  void dispose() {
    _marginController.dispose();
    super.dispose();
  }

  Future<void> _updateMargin() async {
    final newMargin = double.tryParse(_marginController.text);
    if (newMargin == null || newMargin < 0 || newMargin > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen 0-100 arası bir değer girin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUpdating = true);

    try {
      final updatedProduct = await _apiService.updateMargin(
        _currentProduct.productCode,
        newMargin,
      );

      setState(() {
        _currentProduct = updatedProduct;
        _marginController.text = updatedProduct.marginPercentage.toString();
        _isUpdating = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kar marjı güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUpdating = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürün Detayı'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ürün görseli
            if (_currentProduct.localImagePath != null &&
                _currentProduct.localImagePath!.isNotEmpty)
              Center(
                child: Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      'https://b2bapi.urlateknik.com:5000/${_currentProduct.localImagePath}',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.image_not_supported,
                          size: 100,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Ürün kodu
            _buildInfoCard(
              'Ürün Kodu',
              _currentProduct.productCode,
              Icons.qr_code,
            ),
            const SizedBox(height: 16),

            // Ürün adı
            _buildInfoCard(
              'Ürün Adı',
              _currentProduct.name,
              Icons.shopping_bag,
            ),
            const SizedBox(height: 24),

            // Fiyat bilgileri
            const Text(
              'Fiyat Bilgileri',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildPriceRow(
              'Liste Fiyatı',
              CurrencyFormatter.format(_currentProduct.listPrice),
              Colors.grey,
            ),
            const Divider(),
            _buildPriceRow(
              'Alış Fiyatı (KDV Hariç)',
              CurrencyFormatter.format(_currentProduct.buyPriceExcludingVat),
              Colors.blue,
            ),
            const Divider(),
            _buildPriceRow(
              'Alış Fiyatı (KDV Dahil)',
              CurrencyFormatter.format(_currentProduct.buyPriceIncludingVat),
              Colors.blue,
            ),
            const Divider(),
            _buildPriceRow(
              'Satış Fiyatı',
              CurrencyFormatter.format(_currentProduct.myPrice),
              Colors.green,
              isBold: true,
            ),
            const SizedBox(height: 24),

            // İskonto bilgileri
            if (_currentProduct.discount1 > 0 ||
                _currentProduct.discount2 > 0 ||
                _currentProduct.discount3 > 0) ...[
              const Text(
                'İskonto Bilgileri',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_currentProduct.discount1 > 0)
                        _buildDiscountRow(
                            'İskonto 1', _currentProduct.discount1),
                      if (_currentProduct.discount2 > 0)
                        _buildDiscountRow(
                            'İskonto 2', _currentProduct.discount2),
                      if (_currentProduct.discount3 > 0)
                        _buildDiscountRow(
                            'İskonto 3', _currentProduct.discount3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Kar marjı düzenleme
            const Text(
              'Kar Marjı Ayarla',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _marginController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Kar Marjı (%)',
                              border: OutlineInputBorder(),
                              suffixText: '%',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isUpdating ? null : _updateMargin,
                          icon: _isUpdating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Güncelle'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mevcut Kar Marjı: ${PercentageFormatter.formatWithSymbol(_currentProduct.marginPercentage)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Son güncelleme
            _buildInfoCard(
              'Son Güncelleme',
              DateTimeFormatter.format(_currentProduct.lastUpdated),
              Icons.update,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            PercentageFormatter.formatWithSymbol(value),
            style: const TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
