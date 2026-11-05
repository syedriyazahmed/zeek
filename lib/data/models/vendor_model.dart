import 'package:cloud_firestore/cloud_firestore.dart';

class VendorModel {
  final String vendorId;
  final String vendorName;
  final String phoneNumber;
  final String address;
  final String companyName;
  final String notes;
  final DateTime createdDate;
  final bool isActive;

  const VendorModel({
    required this.vendorId,
    required this.vendorName,
    this.phoneNumber = '',
    this.address = '',
    this.companyName = '',
    this.notes = '',
    required this.createdDate,
    this.isActive = true,
  });

  factory VendorModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return VendorModel(
      vendorId: id,
      vendorName: map['vendorName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      address: map['address'] as String? ?? '',
      companyName: map['companyName'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      createdDate: parseDate(map['createdDate']),
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'phoneNumber': phoneNumber,
      'address': address,
      'companyName': companyName,
      'notes': notes,
      'createdDate': Timestamp.fromDate(createdDate),
      'isActive': isActive,
    };
  }

  VendorModel copyWith({
    String? vendorId,
    String? vendorName,
    String? phoneNumber,
    String? address,
    String? companyName,
    String? notes,
    DateTime? createdDate,
    bool? isActive,
  }) {
    return VendorModel(
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      companyName: companyName ?? this.companyName,
      notes: notes ?? this.notes,
      createdDate: createdDate ?? this.createdDate,
      isActive: isActive ?? this.isActive,
    );
  }
}

