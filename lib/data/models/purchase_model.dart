import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/currency_formatter.dart';

class PurchaseModel {
  final String purchaseId;
  final String vendorId;
  final String vendorName;
  final DateTime purchaseDate;
  final String productId;
  final String productName;
  final double purchasedQuantity;
  final String unit;
  final double purchasePricePerUnit;
  final double totalAmount;
  final String? notes;
  final String? paymentMethod; // 'cash' | 'online' | 'unpaid'
  final String createdBy;
  final DateTime createdAt;

  const PurchaseModel({
    required this.purchaseId,
    required this.vendorId,
    required this.vendorName,
    required this.purchaseDate,
    required this.productId,
    required this.productName,
    required this.purchasedQuantity,
    required this.unit,
    required this.purchasePricePerUnit,
    required this.totalAmount,
    this.notes,
    this.paymentMethod,
    required this.createdBy,
    required this.createdAt,
  });

  factory PurchaseModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return PurchaseModel(
      purchaseId: id,
      vendorId: map['vendorId'] as String? ?? '',
      vendorName: map['vendorName'] as String? ?? '',
      purchaseDate: parseDate(map['purchaseDate']),
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      purchasedQuantity: (map['purchasedQuantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'ml',
      purchasePricePerUnit: (map['purchasePricePerUnit'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'purchaseId': purchaseId,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'productId': productId,
      'productName': productName,
      'purchasedQuantity': purchasedQuantity,
      'unit': unit,
      'purchasePricePerUnit': purchasePricePerUnit,
      'totalAmount': CurrencyFormatter.round(totalAmount),
      'notes': notes,
      'paymentMethod': paymentMethod,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

