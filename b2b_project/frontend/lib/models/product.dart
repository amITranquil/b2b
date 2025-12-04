class Product {
  final int id;
  final String productCode;
  final String name;
  final double listPrice;
  final double buyPriceExcludingVat;
  final double buyPriceIncludingVat;
  final double myPrice;
  final double discount1;
  final double discount2;
  final double discount3;
  final double vatRate;
  final String? imageUrl;
  final String? localImagePath;
  final double marginPercentage;
  final DateTime lastUpdated;
  final bool isDeleted;
  final DateTime? deletedAt;

  Product({
    required this.id,
    required this.productCode,
    required this.name,
    required this.listPrice,
    required this.buyPriceExcludingVat,
    required this.buyPriceIncludingVat,
    required this.myPrice,
    required this.discount1,
    required this.discount2,
    required this.discount3,
    required this.vatRate,
    this.imageUrl,
    this.localImagePath,
    required this.marginPercentage,
    required this.lastUpdated,
    this.isDeleted = false,
    this.deletedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      productCode: json['productCode'] as String,
      name: json['name'] as String,
      listPrice: _parseDouble(json['listPrice']),
      buyPriceExcludingVat: _parseDouble(json['buyPriceExcludingVat']),
      buyPriceIncludingVat: _parseDouble(json['buyPriceIncludingVat']),
      myPrice: _parseDouble(json['myPrice']),
      discount1: _parseDouble(json['discount1']),
      discount2: _parseDouble(json['discount2']),
      discount3: _parseDouble(json['discount3']),
      vatRate: _parseDouble(json['vatRate']),
      imageUrl: json['imageUrl'] as String?,
      localImagePath: json['localImagePath'] as String?,
      marginPercentage: _parseDouble(json['marginPercentage']),
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null ? DateTime.parse(json['deletedAt'] as String) : null,
    );
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

  double get salePriceExcludingVat => vatRate > 0 ? myPrice / (1 + vatRate / 100) : myPrice;
  double get salePriceIncludingVat => myPrice;
}
