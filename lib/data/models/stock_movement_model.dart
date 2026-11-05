import 'package:cloud_firestore/cloud_firestore.dart';

class StockMovementModel {
  final String movementId;
  final String productId;
  final String productName;
  final String movementType;
  final double quantity; // Signed convention: positive for additions, negative for deductions
  final String unit;
  final String referenceId;
  final String date;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;

  const StockMovementModel({
    required this.movementId,
    required this.productId,
    required this.productName,
    required this.movementType,
    required this.quantity,
    required this.unit,
    required this.referenceId,
    required this.date,
    this.notes,
    required this.createdBy,
    required this.createdAt,
  });

  bool get isAddition => quantity > 0;
  bool get isDeduction => quantity < 0;

  factory StockMovementModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return StockMovementModel(
      movementId: id,
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      movementType: map['movementType'] as String? ?? 'STOCK_ADJUSTMENT',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: map['unit'] as String? ?? 'ml',
      referenceId: map['referenceId'] as String? ?? '',
      date: map['date'] as String? ?? '',
      notes: map['notes'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'movementId': movementId,
      'productId': productId,
      'productName': productName,
      'movementType': movementType,
      'quantity': quantity,
      'unit': unit,
      'referenceId': referenceId,
      'date': date,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

