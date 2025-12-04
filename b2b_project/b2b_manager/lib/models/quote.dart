class Quote {
  final String id;
  final String customerName;
  final String representative;
  final String paymentTerm;
  final String phone;
  final String note;
  final String? extraNote; // Opsiyonel alan olarak tanımladık
  final DateTime createdAt;
  final DateTime? modifiedAt;
  final List<QuoteItem> items;
  final double totalAmount;
  final double vatAmount;
  final bool isDraft;

  Quote({
    required this.id,
    required this.customerName,
    required this.representative,
    required this.paymentTerm,
    required this.phone,
    required this.note,
    this.extraNote, // Opsiyonel olduğu için required yapmadık
    required this.createdAt,
    this.modifiedAt,
    required this.items,
    required this.totalAmount,
    required this.vatAmount,
    this.isDraft = false,
  });

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        id: json['id'].toString(),
        customerName: json['customerName'] ?? '',
        representative: json['representative'] ?? '',
        paymentTerm: json['paymentTerm'] ?? '',
        phone: json['phone'] ?? '',
        note: json['note'] ?? '',
        extraNote: json['extraNote'],
        createdAt: DateTime.parse(json['createdAt']),
        modifiedAt: json['modifiedAt'] != null
            ? DateTime.parse(json['modifiedAt'])
            : null,
        items: (json['items'] as List<dynamic>?)
                ?.map((item) => QuoteItem.fromJson(item))
                .toList() ??
            [],
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
        vatAmount: (json['vatAmount'] as num?)?.toDouble() ?? 0,
        isDraft: json['isDraft'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': int.tryParse(id) ?? 0, // Backend integer ID bekliyor
        'customerName': customerName,
        'representative': representative,
        'paymentTerm': paymentTerm,
        'phone': phone,
        'note': note,
        'extraNote': extraNote ?? '', // null ise boş string gönder
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt?.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'totalAmount': totalAmount,
        'vatAmount': vatAmount,
        'isDraft': isDraft,
      };
}

class QuoteItem {
  final String id;
  final String quoteId;
  final String description;
  final double quantity;
  final String unit;
  final double price;
  final double vatRate; // KDV oranı
  final double marginPercentage; // Kar marjı oranı

  QuoteItem({
    required this.id,
    required this.quoteId,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.price,
    this.vatRate = 20, // Default %20
    this.marginPercentage = 40, // Default %40
  });

  double get total => quantity * price;

  factory QuoteItem.fromJson(Map<String, dynamic> json) => QuoteItem(
        id: json['id'].toString(),
        quoteId: json['quoteId'].toString(),
        description: json['description'] ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] ?? '',
        price: (json['price'] as num?)?.toDouble() ?? 0,
        vatRate: (json['vatRate'] as num?)?.toDouble() ?? 20,
        marginPercentage: (json['marginPercentage'] as num?)?.toDouble() ?? 40,
      );

  Map<String, dynamic> toJson() => {
        'id': int.tryParse(id) ?? 0, // Backend integer ID bekliyor
        'quoteId': int.tryParse(quoteId) ?? 0, // Backend integer ID bekliyor
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'price': price,
        'vatRate': vatRate,
        'marginPercentage': marginPercentage,
      };
}
