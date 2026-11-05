import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import 'sale_item_model.dart';

class SaleModel {
  final String saleId;
  final String invoiceNumber;
  final String date; // YYYY-MM-DD
  final DateTime timestamp;
  final List<SaleItemModel> items;
  final double subtotal;
  final double discount;
  final double grandTotal;
  final String paymentType; // 'cash' | 'online' | 'split'
  final double cashAmount;
  final double onlineAmount;
  final String status; // 'completed' | 'cancelled'
  final String createdBy;
  final String? createdByName;
  final String? cancellationReason;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  const SaleModel({
    required this.saleId,
    required this.invoiceNumber,
    required this.date,
    required this.timestamp,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    required this.grandTotal,
    required this.paymentType,
    required this.cashAmount,
    required this.onlineAmount,
    this.status = AppConstants.saleStatusCompleted,
    required this.createdBy,
    this.createdByName,
    this.cancellationReason,
    this.cancelledAt,
    this.cancelledBy,
  });

  bool get isCompleted => status == AppConstants.saleStatusCompleted;
  bool get isCancelled => status == AppConstants.saleStatusCancelled;

  double get totalQuantity =>
      items.fold(0.0, (acc, item) => acc + item.quantity);

  double get totalProfit =>
      items.fold(0.0, (acc, item) => acc + item.profit);

  factory SaleModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((e) => SaleItemModel.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();

    return SaleModel(
      saleId: id,
      invoiceNumber: map['invoiceNumber'] as String? ?? id,
      date: map['date'] as String? ?? '',
      timestamp: parseDate(map['timestamp']),
      items: itemsList,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paymentType: map['paymentType'] as String? ?? AppConstants.paymentCash,
      cashAmount: (map['cashAmount'] as num?)?.toDouble() ?? 0.0,
      onlineAmount: (map['onlineAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? AppConstants.saleStatusCompleted,
      createdBy: map['createdBy'] as String? ?? '',
      createdByName: map['createdByName'] as String?,
      cancellationReason: map['cancellationReason'] as String?,
      cancelledAt: map['cancelledAt'] != null ? parseDate(map['cancelledAt']) : null,
      cancelledBy: map['cancelledBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'saleId': saleId,
      'invoiceNumber': invoiceNumber,
      'date': date,
      'timestamp': Timestamp.fromDate(timestamp),
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': CurrencyFormatter.round(subtotal),
      'discount': CurrencyFormatter.round(discount),
      'grandTotal': CurrencyFormatter.round(grandTotal),
      'paymentType': paymentType,
      'cashAmount': CurrencyFormatter.round(cashAmount),
      'onlineAmount': CurrencyFormatter.round(onlineAmount),
      'status': status,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'cancellationReason': cancellationReason,
      'cancelledAt': cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'cancelledBy': cancelledBy,
    };
  }
}
