// lib/screens/sales_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  final ApiService _apiService = ApiService();
  final ReceiptService _receiptService = ReceiptService();
  final numberFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  List<Sale> _sales = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final sales = await _apiService.getSales();
      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      // Backend hazır değilse sadece log'a yaz, kullanıcıya hata gösterme
      debugPrint('Sales API error: $e');
      setState(() {
        _sales = []; // Boş liste göster
        _isLoading = false;
        _error = ''; // Hata mesajını temizle
      });
    }
  }

  Future<void> _viewReceipt(Sale sale) async {
    try {
      await _receiptService.generateReceipt(sale, context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fiş oluşturma hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelSale(Sale sale) async {
    if (sale.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hata: Satış ID bulunamadı'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // İptal onayı al
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satışı İptal Et'),
        content: Text(
          'Bu satışı iptal etmek istediğinize emin misiniz?\n\nTutar: ${numberFormat.format(sale.total)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.cancelSale(sale.id!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış iptal edildi'),
          backgroundColor: Colors.orange,
        ),
      );

      // Listeyi yenile
      _loadSales();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('İptal hatası: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Satış Geçmişi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSales,
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
                          'Satış geçmişi backend implement edildikten sonra görüntülenebilecek.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadSales,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : _sales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz satış yok',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _sales.length,
                      padding: const EdgeInsets.all(8),
                      itemBuilder: (context, index) {
                        final sale = _sales[index];
                        return _buildSaleCard(sale);
                      },
                    ),
    );
  }

  Widget _buildSaleCard(Sale sale) {
    final isCancelled = sale.status == SaleStatus.cancelled;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isCancelled ? Colors.red.withValues(alpha: 0.1) : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: isCancelled
              ? Colors.red
              : (sale.paymentMethod == PaymentMethod.cash
                  ? Colors.green
                  : Colors.blue),
          child: Icon(
            isCancelled
                ? Icons.cancel
                : (sale.paymentMethod == PaymentMethod.cash
                    ? Icons.money
                    : Icons.credit_card),
            color: Colors.white,
          ),
        ),
        title: Text(
          numberFormat.format(sale.total),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            decoration: isCancelled ? TextDecoration.lineThrough : null,
            color: isCancelled ? Colors.red : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateFormat.format(sale.createdAt)),
            Row(
              children: [
                Text(
                  sale.paymentMethod.displayName,
                  style: TextStyle(
                    fontSize: 12,
                    color: sale.paymentMethod == PaymentMethod.card
                        ? Colors.blue
                        : Colors.green,
                  ),
                ),
                if (isCancelled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'İPTAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCancelled && sale.status == SaleStatus.completed)
              IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red),
                tooltip: 'İptal Et',
                onPressed: () => _cancelSale(sale),
              ),
            IconButton(
              icon: const Icon(Icons.receipt),
              tooltip: 'Fişi Görüntüle',
              onPressed: () => _viewReceipt(sale),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ürünler:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ...sale.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${item.quantity} × ${numberFormat.format(item.price)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        numberFormat.format(item.total),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(),
                const SizedBox(height: 8),
                _buildTotalRow('Ara Toplam', sale.subtotal),
                if (sale.cardCommission > 0) ...[
                  const SizedBox(height: 4),
                  _buildTotalRow(
                    'Kart Komisyonu (%5)',
                    sale.cardCommission,
                    color: Colors.orange,
                  ),
                ],
                const SizedBox(height: 8),
                _buildTotalRow(
                  'TOPLAM',
                  sale.total,
                  isTotal: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {
    bool isTotal = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          numberFormat.format(amount),
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: color ?? (isTotal ? Colors.green : null),
          ),
        ),
      ],
    );
  }
}
