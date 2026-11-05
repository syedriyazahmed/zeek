import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';

class ExpenseModel {
  final String expenseId;
  final String date; // YYYY-MM-DD
  final String reason;
  final String category;
  final double totalAmount;
  final String paymentMethod; // 'cash' | 'online' | 'split'
  final double cashAmount;
  final double onlineAmount;
  final String? description;
  final String createdBy;
  final DateTime createdAt;

  const ExpenseModel({
    required this.expenseId,
    required this.date,
    required this.reason,
    required this.category,
    required this.totalAmount,
    required this.paymentMethod,
    required this.cashAmount,
    required this.onlineAmount,
    this.description,
    required this.createdBy,
    required this.createdAt,
  });

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ExpenseModel(
      expenseId: id,
      date: map['date'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      category: map['category'] as String? ?? 'Other',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? AppConstants.paymentCash,
      cashAmount: (map['cashAmount'] as num?)?.toDouble() ?? 0.0,
      onlineAmount: (map['onlineAmount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'date': date,
      'reason': reason,
      'category': category,
      'totalAmount': CurrencyFormatter.round(totalAmount),
      'paymentMethod': paymentMethod,
      'cashAmount': CurrencyFormatter.round(cashAmount),
      'onlineAmount': CurrencyFormatter.round(onlineAmount),
      'description': description,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

