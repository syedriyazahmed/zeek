import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/currency_formatter.dart';

class AccountEntryModel {
  final String entryId;
  final String date;
  final String transactionType;
  final String referenceId;
  final double cashAmount;
  final double onlineAmount;
  final String description;
  final String status;
  final String createdBy;
  final DateTime createdAt;

  const AccountEntryModel({
    required this.entryId,
    required this.date,
    required this.transactionType,
    required this.referenceId,
    required this.cashAmount,
    required this.onlineAmount,
    required this.description,
    this.status = 'active',
    required this.createdBy,
    required this.createdAt,
  });

  double get totalAmount => CurrencyFormatter.round(cashAmount + onlineAmount);

  factory AccountEntryModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AccountEntryModel(
      entryId: id,
      date: map['date'] as String? ?? '',
      transactionType: map['transactionType'] as String? ?? '',
      referenceId: map['referenceId'] as String? ?? '',
      cashAmount: (map['cashAmount'] as num?)?.toDouble() ?? 0.0,
      onlineAmount: (map['onlineAmount'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String? ?? '',
      status: map['status'] as String? ?? 'active',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parseDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entryId': entryId,
      'date': date,
      'transactionType': transactionType,
      'referenceId': referenceId,
      'cashAmount': CurrencyFormatter.round(cashAmount),
      'onlineAmount': CurrencyFormatter.round(onlineAmount),
      'description': description,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

