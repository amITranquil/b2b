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
  final Set<int> _excludedServiceIds = {};
  final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

  // Hizmet itemı olup olmadığını kontrol et
  bool _isServiceItem(QuoteItem item) {
    final description = item.description.toLowerCase();
    return description.contains('işçilik') ||
        description.contains('montaj') ||
        description.contains('kurulum') ||
        description.contains('hizmet') ||
        description.contains('servis');
  }

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

  // Toplam ürün maliyetini hesapla (sadece ürünler)
  double _calculateTotalProductCost() {
    return widget.quote.items
        .where((item) => !_isServiceItem(item))
        .fold(0.0, (sum, item) => sum + _calculateItemCost(item));
  }

  // Hizmet itemlarının maliyetini hesapla
  double _calculateServiceCost(QuoteItem item) {
    // Hizmet itemları için de aynı hesaplamayı yapıyoruz
    return _calculateItemCost(item);
  }

  // Seçilen hizmetlerin toplam maliyetini hesapla
  double _calculateExcludedServicesCost() {
    return widget.quote.items
        .where((item) => _isServiceItem(item) && _excludedServiceIds.contains(item.id))
        .fold(0.0, (sum, item) => sum + _calculateServiceCost(item));
  }

  // Net maliyeti hesapla
  double _calculateNetCost() {
    final productCost = _calculateTotalProductCost();

    // Dahil edilen hizmetlerin maliyeti
    final includedServicesCost = widget.quote.items
        .where((item) => _isServiceItem(item) && !_excludedServiceIds.contains(item.id))
        .fold(0.0, (sum, item) => sum + _calculateServiceCost(item));

    return productCost + includedServicesCost;
  }

  @override
  Widget build(BuildContext context) {
    final serviceItems = widget.quote.items.where(_isServiceItem).toList();
    final totalProductCost = _calculateTotalProductCost();
    final netCost = _calculateNetCost();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
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
                    // Toplam Ürün Maliyeti
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.inventory_2, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Ürün Maliyeti (Alış + KDV):',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              currencyFormatter.format(totalProductCost),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Hizmet İtemları
                    if (serviceItems.isNotEmpty) ...[
                      const Text(
                        'Hizmet Kalemleri:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Maliyetten çıkarmak istediğiniz hizmetleri seçin:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: serviceItems.map((item) {
                              final itemCost = _calculateServiceCost(item);
                              final isExcluded = _excludedServiceIds.contains(item.id);

                              return CheckboxListTile(
                                title: Text(
                                  item.description,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  '${item.quantity} ${item.unit} × ${currencyFormatter.format(_calculatePurchasePrice(item) * (1 + item.vatRate / 100))}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                secondary: Text(
                                  currencyFormatter.format(itemCost),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isExcluded ? Colors.red : Colors.green,
                                  ),
                                ),
                                value: isExcluded,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _excludedServiceIds.add(item.id);
                                    } else {
                                      _excludedServiceIds.remove(item.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Çıkarılan Hizmetler Toplamı
                    if (_calculateExcludedServicesCost() > 0) ...[
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.remove_circle, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text(
                                    'Çıkarılan Hizmetler:',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              Text(
                                '- ${currencyFormatter.format(_calculateExcludedServicesCost())}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Net Maliyet
                    Card(
                      color: Colors.green.shade50,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance_wallet, color: Colors.green, size: 28),
                                SizedBox(width: 12),
                                Text(
                                  'NET MALİYET:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              currencyFormatter.format(netCost),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Açıklama
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
                              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade700),
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
                            '• Maliyet, ürünlerin alış fiyatı + KDV toplamından hesaplanır.\n'
                            '• Alış fiyatı, satış fiyatından kar marjı düşülerek bulunur.\n'
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
}
