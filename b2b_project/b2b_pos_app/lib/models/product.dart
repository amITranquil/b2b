// lib/models/product.dart
class Product {
  final int id;
  final String productCode;
  final String name;
  final double listPrice;
  final double buyPriceExcludingVat;
  final double buyPriceIncludingVat;
  final double myPrice; // Satış fiyatı (KDV dahil)
  final double vatRate;
  final String? imageUrl;
  final String? localImagePath;

  Product({
    required this.id,
    required this.productCode,
    required this.name,
    required this.listPrice,
    required this.buyPriceExcludingVat,
    required this.buyPriceIncludingVat,
    required this.myPrice,
    required this.vatRate,
    this.imageUrl,
    this.localImagePath,
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
      vatRate: _parseDouble(json['vatRate']),
      imageUrl: json['imageUrl'] as String?,
      localImagePath: json['localImagePath'] as String?,
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

  // Satış fiyatı
  double get salePrice => myPrice;

  // Birim
  String get unit => 'Adet';
}
