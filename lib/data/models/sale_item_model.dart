import '../../core/utils/currency_formatter.dart';

class SaleItemModel {
  final String productId;
  final String productName;
  final String productType; // 'Oil' | 'Non-Oil'
  final double quantity;
  final String unit; // 'ml' | 'piece'
  final double unitPrice;
  final double unitCostAtSale;
  final double totalPrice;

  const SaleItemModel({
    required this.productId,
    required this.productName,
    required this.productType,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.unitCostAtSale = 0.0,
    required this.totalPrice,
  });

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      productType: map['productType'] as String? ?? 'Oil',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'ml',
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      unitCostAtSale: (map['unitCostAtSale'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productType': productType,
      'quantity': quantity,
      'unit': unit,
      'unitPrice': unitPrice,
      'unitCostAtSale': unitCostAtSale,
      'totalPrice': totalPrice,
    };
  }

  SaleItemModel copyWith({
    String? productId,
    String? productName,
    String? productType,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? unitCostAtSale,
    double? totalPrice,
  }) {
    return SaleItemModel(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productType: productType ?? this.productType,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      unitCostAtSale: unitCostAtSale ?? this.unitCostAtSale,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  double get profit => CurrencyFormatter.round(totalPrice - (unitCostAtSale * quantity));
}

