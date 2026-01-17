// lib/models/sale.dart
class Sale {
  final int? id; // Backend'den gelecek, yeni satışlarda null olabilir
  final DateTime createdAt;
  final List<SaleItem> items;
  final double subtotal;
  final double cardCommission; // %5 kart komisyonu
  final double total;
  final PaymentMethod paymentMethod;
  final SaleStatus status;

  Sale({
    this.id, // Artık optional
    required this.createdAt,
    required this.items,
    required this.subtotal,
    required this.cardCommission,
    required this.total,
    required this.paymentMethod,
    this.status = SaleStatus.completed,
  });

  // CopyWith metodu
  Sale copyWith({
    int? id,
    DateTime? createdAt,
    List<SaleItem>? items,
    double? subtotal,
    double? cardCommission,
    double? total,
    PaymentMethod? paymentMethod,
    SaleStatus? status,
  }) {
    return Sale(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      cardCommission: cardCommission ?? this.cardCommission,
      total: total ?? this.total,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
    );
  }

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as int?,
        createdAt: DateTime.parse(json['createdAt']),
        items: (json['items'] as List<dynamic>?)
                ?.map((item) => SaleItem.fromJson(item))
                .toList() ??
            [],
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        cardCommission: (json['cardCommission'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == json['paymentMethod'],
          orElse: () => PaymentMethod.cash,
        ),
        status: SaleStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => SaleStatus.completed,
        ),
      );

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'cardCommission': cardCommission,
      'total': total,
      'paymentMethod': paymentMethod.name,
      'status': status.name,
    };

    // ID sadece varsa ekle (güncelleme için)
    if (id != null) {
      json['id'] = id!;
    }

    return json;
  }
}

class SaleItem {
  final String productCode;
  final String productName;
  final double quantity;
  final String unit;
  final double price; // KDV dahil satış fiyatı
  final double vatRate;

  SaleItem({
    required this.productCode,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.vatRate,
  });

  double get total => quantity * price;
  double get vatAmount => total - (total / (1 + vatRate / 100));

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        productCode: json['productCode'] ?? '',
        productName: json['productName'] ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] ?? 'Adet',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        vatRate: (json['vatRate'] as num?)?.toDouble() ?? 20,
      );

  Map<String, dynamic> toJson() => {
        'productCode': productCode,
        'productName': productName,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'vatRate': vatRate,
      };
}

enum PaymentMethod {
  cash,  // Nakit
  card,  // Kart (%5 komisyon)
}

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Nakit';
      case PaymentMethod.card:
        return 'Kredi Kartı';
    }
  }

  double get commissionRate {
    switch (this) {
      case PaymentMethod.cash:
        return 0;
      case PaymentMethod.card:
        return 0.05; // %5
    }
  }
}

enum SaleStatus {
  pending,    // Bekleyen satış
  completed,  // Tamamlanmış satış
  cancelled,  // İptal edilmiş satış
}

extension SaleStatusExtension on SaleStatus {
  String get displayName {
    switch (this) {
      case SaleStatus.pending:
        return 'Bekliyor';
      case SaleStatus.completed:
        return 'Tamamlandı';
      case SaleStatus.cancelled:
        return 'İptal Edildi';
    }
  }
}
