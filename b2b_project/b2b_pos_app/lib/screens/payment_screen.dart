// lib/screens/payment_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../services/api_service.dart';
import '../services/receipt_service.dart';
import 'products_screen.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final Sale? pendingSale; // Bekleyen satış varsa buradan gelir

  const PaymentScreen({
    super.key,
    required this.cartItems,
    this.pendingSale,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ApiService _apiService = ApiService();
  final ReceiptService _receiptService = ReceiptService();
  final numberFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Eğer pending sale varsa, payment method'u set et
    if (widget.pendingSale != null) {
      _selectedPaymentMethod = widget.pendingSale!.paymentMethod;
    }
  }

  double get _subtotal {
    return widget.cartItems.fold(0, (sum, item) => sum + item.total);
  }

  double get _cardCommission {
    return _selectedPaymentMethod == PaymentMethod.card
        ? _subtotal * 0.05
        : 0;
  }

  double get _total {
    return _subtotal + _cardCommission;
  }

  Future<void> _completeSale() async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satışı Tamamla'),
        content: Text(
          'Toplam ${numberFormat.format(_total)} tutarındaki satışı tamamlamak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tamamla'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Create sale object with completed status
      final sale = Sale(
        id: widget.pendingSale?.id, // Backend varsa ID'yi kullan, yoksa null (backend oluşturacak)
        createdAt: widget.pendingSale?.createdAt ?? DateTime.now(),
        items: widget.cartItems.map((cartItem) => SaleItem(
          productCode: cartItem.product.productCode,
          productName: cartItem.product.name,
          quantity: cartItem.quantity,
          unit: cartItem.product.unit,
          price: cartItem.product.salePrice,
          vatRate: cartItem.product.vatRate,
        )).toList(),
        subtotal: _subtotal,
        cardCommission: _cardCommission,
        total: _total,
        paymentMethod: _selectedPaymentMethod,
        status: SaleStatus.completed,
      );

      // Save to backend
      try {
        if (widget.pendingSale != null && widget.pendingSale!.id != null) {
          // Update pending sale to completed
          await _apiService.updateSale(widget.pendingSale!.id!, sale);
        } else {
          // Create new sale
          await _apiService.createSale(sale);
        }
      } catch (e) {
        // Backend not ready, continue anyway
        debugPrint('Backend not ready: $e');
      }

      // Generate receipt PDF
      if (!mounted) return;
      await _receiptService.generateReceipt(sale, context);

      if (!mounted) return;

      // Show success
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text('Satış Tamamlandı!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                numberFormat.format(_total),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedPaymentMethod.displayName,
                style: const TextStyle(fontSize: 18),
              ),
              if (_cardCommission > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Kart Komisyonu: ${numberFormat.format(_cardCommission)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context, true); // Go back to products with success
              },
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _holdSale() async {
    // Onay dialogu göster
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Satışı Beklet'),
        content: const Text(
          'Bu satışı daha sonra tamamlamak üzere bekletmek ister misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Beklet'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Create sale object with pending status
      final sale = Sale(
        id: null, // Yeni satış, backend ID oluşturacak
        createdAt: DateTime.now(),
        items: widget.cartItems.map((cartItem) => SaleItem(
          productCode: cartItem.product.productCode,
          productName: cartItem.product.name,
          quantity: cartItem.quantity,
          unit: cartItem.product.unit,
          price: cartItem.product.salePrice,
          vatRate: cartItem.product.vatRate,
        )).toList(),
        subtotal: _subtotal,
        cardCommission: _cardCommission,
        total: _total,
        paymentMethod: _selectedPaymentMethod,
        status: SaleStatus.pending,
      );

      // Save to backend as pending
      try {
        await _apiService.createSale(sale);
      } catch (e) {
        // Backend not ready
        debugPrint('Backend not ready: $e');
        throw Exception('Satış bekletilemedi. Backend bağlantısı yok.');
      }

      if (!mounted) return;

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış bekletildi'),
          backgroundColor: Colors.orange,
        ),
      );

      // Go back to products
      Navigator.pop(context, false);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

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
        title: const Text('Ödeme'),
      ),
      body: Column(
        children: [
          // Order summary
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Items list
                  const Text(
                    'Sipariş Özeti',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...widget.cartItems.map((item) => _buildOrderItem(item)),
                  const Divider(height: 32),

                  // Payment method selection
                  const Text(
                    'Ödeme Yöntemi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentMethodCard(PaymentMethod.cash),
                  const SizedBox(height: 8),
                  _buildPaymentMethodCard(PaymentMethod.card),
                  const SizedBox(height: 24),

                  // Price breakdown
                  _buildPriceRow('Ara Toplam', _subtotal),
                  if (_cardCommission > 0) ...[
                    const SizedBox(height: 8),
                    _buildPriceRow(
                      'Kart Komisyonu (%5)',
                      _cardCommission,
                      color: Colors.orange,
                    ),
                  ],
                  const Divider(height: 24),
                  _buildPriceRow(
                    'TOPLAM',
                    _total,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Beklet butonu
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _holdSale,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.schedule),
                    label: const Text(
                      'Satışı Beklet',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Tamamla butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _completeSale,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Ödemeyi Tamamla - ${numberFormat.format(_total)}'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${item.quantity.toInt()} × ${numberFormat.format(item.product.salePrice)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            numberFormat.format(item.total),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(PaymentMethod method) {
    final isSelected = _selectedPaymentMethod == method;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.green.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPaymentMethod = method;
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                method == PaymentMethod.cash
                    ? Icons.money
                    : Icons.credit_card,
                size: 32,
                color: isSelected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (method == PaymentMethod.card)
                      const Text(
                        '+%5 Komisyon',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {
    bool isTotal = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
        Text(
          numberFormat.format(amount),
          style: TextStyle(
            fontSize: isTotal ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: color ?? (isTotal ? Colors.green : null),
          ),
        ),
      ],
    );
  }
}
