import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/quote.dart';

class CostCalculationDialog extends StatefulWidget {
  final Quote quote;

  const CostCalculationDialog({super.key, required this.quote});

  @override
  State<CostCalculationDialog> createState() => _CostCalculationDialogState();
}

class _CostCalculationDialogState extends State<CostCalculationDialog> {
  final Set<int> _excludedItemIds = {};
  final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  // Alış fiyatını hesapla (margin'den geri hesaplama)
  double _calculatePurchasePrice(QuoteItem item) {
    // price = purchasePrice * (1 + marginPercentage / 100)
    // purchasePrice = price / (1 + marginPercentage / 100)
    return item.price / (1 + item.marginPercentage / 100);
  }

  // Item maliyetini hesapla (alış + KDV)
  double _calculateItemCost(QuoteItem item) {
    final purchasePrice = _calculatePurchasePrice(item);
    final costWithVat = purchasePrice * (1 + item.vatRate / 100);
    return costWithVat * item.quantity;
  }

  // Toplam maliyet (tüm itemlar)
  double _calculateTotalCost() {
    return widget.quote.items
        .fold(0.0, (sum, item) => sum + _calculateItemCost(item));
  }

  // Çıkarılan itemların sadece alış fiyatı (KDV hariç)
  double _calculateExcludedPurchaseCost() {
    return widget.quote.items
        .where((item) => _excludedItemIds.contains(item.id))
        .fold(0.0, (sum, item) {
          final purchasePrice = _calculatePurchasePrice(item);
          return sum + (purchasePrice * item.quantity);
        });
  }

  // Çıkarılan itemların sadece KDV'si
  double _calculateExcludedVat() {
    return widget.quote.items
        .where((item) => _excludedItemIds.contains(item.id))
        .fold(0.0, (sum, item) {
          final purchasePrice = _calculatePurchasePrice(item);
          final vatAmount = purchasePrice * item.quantity * (item.vatRate / 100);
          return sum + vatAmount;
        });
  }

  // Net maliyet = Toplam - Çıkarılan Alış Fiyatları (KDV dahil değil, çünkü KDV'yi ödüyoruz)
  double _calculateNetCost() {
    return _calculateTotalCost() - _calculateExcludedPurchaseCost();
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _calculateTotalCost();
    final excludedPurchaseCost = _calculateExcludedPurchaseCost();
    final excludedVat = _calculateExcludedVat();
    final netCost = _calculateNetCost();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calculate, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Maliyet Analizi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Açıklama
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Maliyetten çıkarmak istediğiniz kalemleri seçin:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tüm İtemlar
                    const Text(
                      'Teklif Kalemleri:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Item listesi
                    ...widget.quote.items.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final item = entry.value;
                      final isExcluded = _excludedItemIds.contains(item.id);
                      final purchasePrice = _calculatePurchasePrice(item);
                      final purchasePriceWithVat = purchasePrice * (1 + item.vatRate / 100);
                      final itemCost = _calculateItemCost(item);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: isExcluded ? 1 : 2,
                        color: isExcluded ? Colors.red.shade50 : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Checkbox ve Açıklama
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: isExcluded,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _excludedItemIds.add(item.id);
                                        } else {
                                          _excludedItemIds.remove(item.id);
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Text(
                                        '$index. ${item.description}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          decoration: isExcluded ? TextDecoration.lineThrough : null,
                                          color: isExcluded ? Colors.red.shade700 : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              const SizedBox(height: 8),

                              // Detaylar
                              Padding(
                                padding: const EdgeInsets.only(left: 48),
                                child: Column(
                                  children: [
                                    _buildDetailRow(
                                      'Miktar:',
                                      '${item.quantity} ${item.unit}',
                                      Icons.shopping_cart_outlined,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildDetailRow(
                                      'Satış Fiyatı (Birim):',
                                      currencyFormatter.format(item.price),
                                      Icons.sell_outlined,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildDetailRow(
                                      'Alış Fiyatı (Birim):',
                                      currencyFormatter.format(purchasePrice),
                                      Icons.shopping_bag_outlined,
                                      valueColor: Colors.orange,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildDetailRow(
                                      'Alış + KDV (Birim):',
                                      currencyFormatter.format(purchasePriceWithVat),
                                      Icons.receipt_outlined,
                                      valueColor: Colors.blue,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildDetailRow(
                                      'KDV Oranı:',
                                      '%${item.vatRate.toStringAsFixed(0)}',
                                      Icons.percent,
                                    ),
                                    const SizedBox(height: 6),
                                    _buildDetailRow(
                                      'Kar Marjı:',
                                      '%${item.marginPercentage.toStringAsFixed(0)}',
                                      Icons.trending_up,
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    _buildDetailRow(
                                      'TOPLAM MALİYET:',
                                      currencyFormatter.format(itemCost),
                                      Icons.account_balance_wallet,
                                      isBold: true,
                                      valueColor: isExcluded ? Colors.red : Colors.green,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // Özet
                    Card(
                      color: Colors.grey.shade50,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildSummaryRow(
                              'Toplam Maliyet:',
                              currencyFormatter.format(totalCost),
                              Colors.blue,
                            ),
                            if (excludedPurchaseCost > 0) ...[
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Çıkarılan Kalemler (Alış):',
                                '- ${currencyFormatter.format(excludedPurchaseCost)}',
                                Colors.red,
                              ),
                              const SizedBox(height: 8),
                              _buildSummaryRow(
                                'Çıkarılan Kalemlerin KDV\'si:',
                                '+ ${currencyFormatter.format(excludedVat)}',
                                Colors.orange,
                              ),
                              const SizedBox(height: 8),
                              const Divider(),
                            ],
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'NET MALİYET:',
                              currencyFormatter.format(netCost),
                              Colors.green,
                              isBold: true,
                              fontSize: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bilgilendirme
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, size: 16, color: Colors.grey.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Bilgilendirme:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• Alış fiyatı, satış fiyatından kar marjı düşülerek hesaplanır.\n'
                            '• Maliyet = Alış fiyatı × (1 + KDV%) × Miktar\n'
                            '• Seçtiğiniz kalemlerin alış fiyatları maliyetten çıkar.\n'
                            '• Ancak seçilen kalemlerin KDV\'si maliyete eklenir (devlete ödendiği için).\n'
                            '• Bu hesaplama sadece bilgilendirme amaçlıdır ve teklifi etkilemez.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
    double fontSize = 14,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
