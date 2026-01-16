// lib/screens/pending_sales_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/product.dart';
import '../services/api_service.dart';
import 'payment_screen.dart';
import 'products_screen.dart';

class PendingSalesScreen extends StatefulWidget {
  const PendingSalesScreen({super.key});

  @override
  State<PendingSalesScreen> createState() => _PendingSalesScreenState();
}

class _PendingSalesScreenState extends State<PendingSalesScreen> {
  final ApiService _apiService = ApiService();
  final numberFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  List<Sale> _pendingSales = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadPendingSales();
  }

  Future<void> _loadPendingSales() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final sales = await _apiService.getSales(status: SaleStatus.pending);
      setState(() {
        _pendingSales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      debugPrint('Pending sales API error: $e');
    }
  }

  Future<void> _resumeSale(Sale sale) async {
    // Bekleyen satışı ödeme ekranına taşı
    // Cart items'ı yeniden oluştur
    final cartItems = sale.items.map((item) => CartItem(
      product: Product(
        id: 0, // Geçici ID
        productCode: item.productCode,
        name: item.productName,
        listPrice: item.price,
        buyPriceExcludingVat: 0,
        buyPriceIncludingVat: 0,
        myPrice: item.price,
        vatRate: item.vatRate,
      ),
      quantity: item.quantity,
    )).toList();

    if (!mounted) return;

    // PaymentScreen'e git
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          cartItems: cartItems,
          pendingSale: sale,
        ),
      ),
    );

    if (result == true) {
      // Satış tamamlandı, listeyi yenile
      _loadPendingSales();
    }
  }

  Future<void> _deletePendingSale(Sale sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bekleyen Satışı Sil'),
        content: const Text('Bu bekleyen satışı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.cancelSale(sale.id);
      _loadPendingSales();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bekleyen satış silindi'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bekleyen Satışlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingSales,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Backend Hazır Değil',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Bekleyen satışlar backend implement edildikten sonra görüntülenebilecek.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadPendingSales,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : _pendingSales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bekleyen satış yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _pendingSales.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final sale = _pendingSales[index];
                        return _buildPendingSaleCard(sale);
                      },
                    ),
    );
  }

  Widget _buildPendingSaleCard(Sale sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.schedule, color: Colors.white),
        ),
        title: Text(
          numberFormat.format(sale.total),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(sale.createdAt)),
            Text(
              '${sale.items.length} ürün - ${sale.paymentMethod.displayName}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Sil',
              onPressed: () => _deletePendingSale(sale),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Colors.green),
              tooltip: 'Devam Et',
              onPressed: () => _resumeSale(sale),
            ),
          ],
        ),
      ),
    );
  }
}
