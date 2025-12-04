import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/formatters.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final TextEditingController _marginController = TextEditingController();
  bool _isUpdating = false;
  late Product _currentProduct;

  @override
  void initState() {
    super.initState();
    _currentProduct = widget.product;
    _marginController.text = PercentageFormatter.format(_currentProduct.marginPercentage);
  }

  @override
  void dispose() {
    _marginController.dispose();
    super.dispose();
  }

  Widget _buildProductImage() {
    if (_currentProduct.localImagePath != null && _currentProduct.localImagePath!.isNotEmpty) {
      return Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[100],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            'https://b2bapi.urlateknik.com:5000/${_currentProduct.localImagePath}',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.image_not_supported,
                color: Colors.grey[400],
                size: 40,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
          ),
        ),
      );
    }
    
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.grey[100],
      ),
      child: Icon(
        Icons.image,
        color: Colors.grey[400],
        size: 40,
      ),
    );
  }

  Future<void> _updateMargin() async {
    final marginText = _marginController.text.trim();
    if (marginText.isEmpty) {
      _showErrorDialog('Kar marjı boş olamaz');
      return;
    }

    final margin = double.tryParse(marginText);
    if (margin == null || margin < 0 || margin > 100) {
      _showErrorDialog('Kar marjı 0-100 arasında olmalıdır');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      await context.read<ProductProvider>().updateProductMargin(
        _currentProduct.productCode,
        margin,
      );

      // Güncellenmiş ürünü al
      final updatedProduct = await context.read<ProductProvider>().getProductDetail(_currentProduct.productCode);
      if (updatedProduct != null) {
        setState(() {
          _currentProduct = updatedProduct;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kar marjı başarıyla güncellendi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Kar marjı güncellenirken hata oluştu: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Panoya kopyalandı'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ürün Detayı',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: () => _copyToClipboard(_currentProduct.productCode),
            tooltip: 'Ürün kodunu kopyala',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ürün Bilgileri Kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ürün resmi
                    _buildProductImage(),
                    const SizedBox(width: 20),
                    // Ürün bilgileri
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ürün Bilgileri',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Ürün Kodu', _currentProduct.productCode, true),
                          _buildInfoRow('Ürün Adı', _currentProduct.name),
                          if (_currentProduct.vatRate > 0)
                            _buildInfoRow('KDV Oranı', PercentageFormatter.formatWithSymbol(_currentProduct.vatRate)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Fiyat Bilgileri Kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fiyat Bilgileri',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Liste fiyatı (varsa)
                    if (_currentProduct.listPrice > 0) ...[
                      _buildPriceCard(
                        'Liste Fiyatı',
                        CurrencyFormatter.format(_currentProduct.listPrice),
                        Colors.grey,
                        Icons.list_alt,
                        isStrikethrough: true,
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: _buildPriceCard(
                            'Alış (KDV Hariç)',
                            CurrencyFormatter.format(_currentProduct.buyPriceExcludingVat),
                            Colors.blue,
                            Icons.shopping_cart,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPriceCard(
                            'Alış (KDV Dahil)',
                            CurrencyFormatter.format(_currentProduct.buyPriceIncludingVat),
                            Colors.indigo,
                            Icons.shopping_cart_checkout,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildPriceCard(
                      'Satış Fiyatı',
                      CurrencyFormatter.format(_currentProduct.myPrice),
                      Colors.green,
                      Icons.sell,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // İskonto Bilgileri (varsa)
            if (_currentProduct.discount1 > 0 || _currentProduct.discount2 > 0 || _currentProduct.discount3 > 0) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İskonto Bilgileri',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_currentProduct.discount1 > 0) ...[
                            Expanded(
                              child: _buildDiscountCard('İskonto 1', _currentProduct.discount1),
                            ),
                            if (_currentProduct.discount2 > 0 || _currentProduct.discount3 > 0)
                              const SizedBox(width: 12),
                          ],
                          if (_currentProduct.discount2 > 0) ...[
                            Expanded(
                              child: _buildDiscountCard('İskonto 2', _currentProduct.discount2),
                            ),
                            if (_currentProduct.discount3 > 0)
                              const SizedBox(width: 12),
                          ],
                          if (_currentProduct.discount3 > 0) ...[
                            Expanded(
                              child: _buildDiscountCard('İskonto 3', _currentProduct.discount3),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Kar Bilgileri Kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kar Bilgileri',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kar Marjı',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                PercentageFormatter.formatWithSymbol(_currentProduct.marginPercentage),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Kar Miktarı',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.green.shade700,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(_currentProduct.myPrice - _currentProduct.buyPriceIncludingVat),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Kar Marjı Güncelleme Kartı
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kar Marjını Güncelle',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _marginController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Yeni Kar Marjı (%)',
                              hintText: '0.0 - 100.0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              suffixIcon: const Icon(Icons.percent),
                            ),
                            enabled: !_isUpdating,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isUpdating ? null : _updateMargin,
                            icon: _isUpdating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.update),
                            label: Text(_isUpdating ? 'Güncelleniyor...' : 'Güncelle'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Yeni satış fiyatı: ${CurrencyFormatter.format(_calculateNewPrice())}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Son Güncelleme Bilgisi
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Son güncelleme: ${DateTimeFormatter.format(_currentProduct.lastUpdated)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [bool copyable = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (copyable)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => _copyToClipboard(value),
                    tooltip: 'Kopyala',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(String title, String price, Color color, IconData icon, {bool isStrikethrough = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            price,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              decoration: isStrikethrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountCard(String title, double discount) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            PercentageFormatter.formatWithSymbol(discount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  double _calculateNewPrice() {
    final marginText = _marginController.text.trim();
    final margin = double.tryParse(marginText) ?? _currentProduct.marginPercentage;
    
    // Doğru hesaplama: Kar marjını KDV hariç fiyata ekle, sonra KDV uygula
    final priceWithMargin = _currentProduct.buyPriceExcludingVat * (1 + margin / 100);
    return priceWithMargin * (1 + _currentProduct.vatRate / 100);
  }
}