class Quote {
  final int id;
  final String customerName;
  final String representative;
  final String paymentTerm;
  final String phone;
  final String note;
  final String? extraNote;
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final double totalAmount;
  final double vatAmount;
  final bool isDraft;
  final List<QuoteItem> items;

  Quote({
    required this.id,
    required this.customerName,
    required this.representative,
    required this.paymentTerm,
    required this.phone,
    required this.note,
    this.extraNote,
    required this.createdAt,
    this.modifiedAt,
    required this.totalAmount,
    required this.vatAmount,
    required this.isDraft,
    required this.items,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as int,
      customerName: json['customerName'] as String? ?? '',
      representative: json['representative'] as String? ?? '',
      paymentTerm: json['paymentTerm'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      note: json['note'] as String? ?? '',
      extraNote: json['extraNote'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.parse(json['modifiedAt'] as String)
          : null,
      totalAmount: _parseDouble(json['totalAmount']),
      vatAmount: _parseDouble(json['vatAmount']),
      isDraft: json['isDraft'] as bool? ?? false,
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => QuoteItem.fromJson(item as Map<String, dynamic>))
              .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerName': customerName,
      'representative': representative,
      'paymentTerm': paymentTerm,
      'phone': phone,
      'note': note,
      'extraNote': extraNote,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt?.toIso8601String(),
      'totalAmount': totalAmount,
      'vatAmount': vatAmount,
      'isDraft': isDraft,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  double get grandTotal => totalAmount + vatAmount;
}

class QuoteItem {
  final int id;
  final int quoteId;
  final String description;
  final double quantity;
  final String unit;
  final double price;
  final double vatRate;
  final double marginPercentage;

  QuoteItem({
    required this.id,
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.price,
    required this.vatRate,
    required this.marginPercentage,
  });

  factory QuoteItem.fromJson(Map<String, dynamic> json) {
    return QuoteItem(
      id: json['id'] as int,
      quoteId: json['quoteId'] as int,
      description: json['description'] as String? ?? '',
      quantity: _parseDouble(json['quantity']),
      unit: json['unit'] as String? ?? '',
      price: _parseDouble(json['price']),
      vatRate: _parseDouble(json['vatRate']),
      marginPercentage: _parseDouble(json['marginPercentage']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quoteId': quoteId,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'price': price,
      'vatRate': vatRate,
      'marginPercentage': marginPercentage,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  double get total => quantity * price;
}
