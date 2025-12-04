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

  // Null-safe double parsing helper
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productCode': productCode,
      'name': name,
      'listPrice': listPrice,
      'buyPriceExcludingVat': buyPriceExcludingVat,
      'buyPriceIncludingVat': buyPriceIncludingVat,
      'myPrice': myPrice,
      'discount1': discount1,
      'discount2': discount2,
      'discount3': discount3,
      'vatRate': vatRate,
      'imageUrl': imageUrl,
      'localImagePath': localImagePath,
      'marginPercentage': marginPercentage,
      'lastUpdated': lastUpdated.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  Product copyWith({
    int? id,
    String? productCode,
    String? name,
    double? listPrice,
    double? buyPriceExcludingVat,
    double? buyPriceIncludingVat,
    double? myPrice,
    double? discount1,
    double? discount2,
    double? discount3,
    double? vatRate,
    String? imageUrl,
    String? localImagePath,
    double? marginPercentage,
    DateTime? lastUpdated,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return Product(
      id: id ?? this.id,
      productCode: productCode ?? this.productCode,
      name: name ?? this.name,
      listPrice: listPrice ?? this.listPrice,
      buyPriceExcludingVat: buyPriceExcludingVat ?? this.buyPriceExcludingVat,
      buyPriceIncludingVat: buyPriceIncludingVat ?? this.buyPriceIncludingVat,
      myPrice: myPrice ?? this.myPrice,
      discount1: discount1 ?? this.discount1,
      discount2: discount2 ?? this.discount2,
      discount3: discount3 ?? this.discount3,
      vatRate: vatRate ?? this.vatRate,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      marginPercentage: marginPercentage ?? this.marginPercentage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  // Geriye uyumluluk için legacy field'lar
  double get buyPrice => buyPriceExcludingVat;
  int get stock => 0; // Artık kullanılmıyor
  String? get category => null; // Artık kullanılmıyor

  @override
  String toString() {
    return 'Product{id: $id, productCode: $productCode, name: $name, listPrice: $listPrice, buyPriceExcludingVat: $buyPriceExcludingVat, buyPriceIncludingVat: $buyPriceIncludingVat, myPrice: $myPrice, marginPercentage: $marginPercentage}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          productCode == other.productCode;

  @override
  int get hashCode => id.hashCode ^ productCode.hashCode;
}