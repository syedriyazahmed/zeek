import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';

class ProductModel {
  final String productId;
  final String productName;
  final String normalizedName;
  final String productCode;
  final String productType; // 'Oil' | 'Non-Oil'
  final String category;
  final String unit; // 'ml' | 'piece'
  final String? vendorId;
  final double totalPurchased;
  final double totalSold;
  final double availableQuantity;
  final double vendorPricePerUnit;
  final double sellingPricePerUnit;
  final double lowStockThreshold;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.productId,
    required this.productName,
    required this.normalizedName,
    required this.productCode,
    required this.productType,
    required this.category,
    required this.unit,
    this.vendorId,
    this.totalPurchased = 0.0,
    this.totalSold = 0.0,
    this.availableQuantity = 0.0,
    this.vendorPricePerUnit = 0.0,
    required this.sellingPricePerUnit,
    this.lowStockThreshold = 10.0,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOil => productType == AppConstants.productTypeOil;
  bool get isNonOil => productType == AppConstants.productTypeNonOil;
  bool get isOutOfStock => availableQuantity <= 0.001;
  bool get isLowStock => availableQuantity <= lowStockThreshold && !isOutOfStock;

  double get potentialSellingValue =>
      CurrencyFormatter.round(availableQuantity * sellingPricePerUnit);

  double get totalPurchaseCost =>
      CurrencyFormatter.round(totalPurchased * vendorPricePerUnit);

  double get currentStockCost =>
      CurrencyFormatter.round(availableQuantity * vendorPricePerUnit);

  double get expectedMargin =>
      CurrencyFormatter.round(potentialSellingValue - currentStockCost);

  factory ProductModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ProductModel(
      productId: id,
      productName: map['productName'] as String? ?? '',
      normalizedName: map['normalizedName'] as String? ??
          (map['productName'] as String? ?? '').toLowerCase().trim(),
      productCode: map['productCode'] as String? ?? '',
      productType: map['productType'] as String? ?? AppConstants.productTypeOil,
      category: map['category'] as String? ?? 'General',
      unit: map['unit'] as String? ??
          (map['productType'] == AppConstants.productTypeNonOil
              ? AppConstants.unitPiece
              : AppConstants.unitMl),
      vendorId: map['vendorId'] as String?,
      totalPurchased: (map['totalPurchased'] as num?)?.toDouble() ?? 0.0,
      totalSold: (map['totalSold'] as num?)?.toDouble() ?? 0.0,
      availableQuantity: (map['availableQuantity'] as num?)?.toDouble() ?? 0.0,
      vendorPricePerUnit: (map['vendorPricePerUnit'] as num?)?.toDouble() ?? 0.0,
      sellingPricePerUnit: (map['sellingPricePerUnit'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toDouble() ?? 10.0,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'normalizedName': normalizedName,
      'productCode': productCode,
      'productType': productType,
      'category': category,
      'unit': unit,
      'vendorId': vendorId,
      'totalPurchased': totalPurchased,
      'totalSold': totalSold,
      'availableQuantity': availableQuantity,
      'vendorPricePerUnit': vendorPricePerUnit,
      'sellingPricePerUnit': sellingPricePerUnit,
      'lowStockThreshold': lowStockThreshold,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ProductModel copyWith({
    String? productId,
    String? productName,
    String? normalizedName,
    String? productCode,
    String? productType,
    String? category,
    String? unit,
    String? vendorId,
    double? totalPurchased,
    double? totalSold,
    double? availableQuantity,
    double? vendorPricePerUnit,
    double? sellingPricePerUnit,
    double? lowStockThreshold,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      normalizedName: normalizedName ?? this.normalizedName,
      productCode: productCode ?? this.productCode,
      productType: productType ?? this.productType,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      vendorId: vendorId ?? this.vendorId,
      totalPurchased: totalPurchased ?? this.totalPurchased,
      totalSold: totalSold ?? this.totalSold,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      vendorPricePerUnit: vendorPricePerUnit ?? this.vendorPricePerUnit,
      sellingPricePerUnit: sellingPricePerUnit ?? this.sellingPricePerUnit,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

