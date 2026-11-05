import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../services/firebase/firebase_service.dart';
import '../models/vendor_model.dart';

abstract class VendorRepository {
  Stream<List<VendorModel>> watchVendors({bool includeArchived = false});
  Future<List<VendorModel>> getVendors({bool includeArchived = false});
  Future<VendorModel?> getVendorById(String vendorId);
  Future<void> addVendor(VendorModel vendor);
  Future<void> updateVendor(VendorModel vendor);
  Future<void> archiveVendor(String vendorId, bool archive);
}

class FirebaseVendorRepository implements VendorRepository {
  final FirebaseService _firebaseService;
  final String _shopId;

  // In-memory fallback/cache
  final List<VendorModel> _localVendors = [];
  final _vendorsStreamController = StreamController<List<VendorModel>>.broadcast();

  FirebaseVendorRepository(this._firebaseService, {String shopId = AppConstants.defaultShopId})
      : _shopId = shopId {
    _initDefaultVendors();
  }

  void _initDefaultVendors() {
    if (_localVendors.isEmpty) {
      _localVendors.addAll([
        VendorModel(
          vendorId: 'v_ajmal',
          vendorName: 'Ajmal Fragrances UAE',
          phoneNumber: '+971 4 286 1111',
          address: 'Deira Perfume Souq, Dubai',
          companyName: 'Ajmal Perfumes LLC',
          notes: 'Primary supplier for natural Oud oils, Dahn Al Oudh, and Dehn Al Ward.',
          createdDate: DateTime.now().subtract(const Duration(days: 60)),
          isActive: true,
        ),
        VendorModel(
          vendorId: 'v_swiss_arabian',
          vendorName: 'Swiss Arabian Perfumes',
          phoneNumber: '+971 6 534 8888',
          address: 'Industrial Area 3, Sharjah',
          companyName: 'Swiss Arabian Fragrances Group',
          notes: 'Specialist for White Musk, Black Musk, and French-Oriental blends.',
          createdDate: DateTime.now().subtract(const Duration(days: 45)),
          isActive: true,
        ),
        VendorModel(
          vendorId: 'v_al_haramain',
          vendorName: 'Al Haramain Perfumes',
          phoneNumber: '+971 6 742 2222',
          address: 'Amman Street, Ajman',
          companyName: 'Al Haramain Trading Co.',
          notes: 'Supplier of pure Taifi Rose, Amber Cashmere, and crystal bottles.',
          createdDate: DateTime.now().subtract(const Duration(days: 30)),
          isActive: true,
        ),
      ]);
      _vendorsStreamController.add(List.unmodifiable(_localVendors));
    }
  }

  CollectionReference<Map<String, dynamic>>? get _collection {
    if (_firebaseService.isInitialized && _firebaseService.firestore != null) {
      return _firebaseService.firestore!
          .collection('shops')
          .doc(_shopId)
          .collection('vendors');
    }
    return null;
  }

  @override
  Stream<List<VendorModel>> watchVendors({bool includeArchived = false}) async* {
    final col = _collection;
    if (col != null) {
      Query<Map<String, dynamic>> query = col.orderBy('createdDate', descending: true);
      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }
      yield* query.snapshots().map((snap) {
        return snap.docs.map((d) => VendorModel.fromMap(d.data(), d.id)).toList();
      });
    } else {
      yield includeArchived
          ? List.unmodifiable(_localVendors)
          : _localVendors.where((v) => v.isActive).toList();
      yield* _vendorsStreamController.stream.map((list) {
        if (includeArchived) return list;
        return list.where((v) => v.isActive).toList();
      });
    }
  }

  @override
  Future<List<VendorModel>> getVendors({bool includeArchived = false}) async {
    final col = _collection;
    if (col != null) {
      Query<Map<String, dynamic>> query = col.orderBy('createdDate', descending: true);
      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }
      final snap = await query.get();
      return snap.docs.map((d) => VendorModel.fromMap(d.data(), d.id)).toList();
    }

    if (includeArchived) return List.unmodifiable(_localVendors);
    return _localVendors.where((v) => v.isActive).toList();
  }

  @override
  Future<VendorModel?> getVendorById(String vendorId) async {
    final col = _collection;
    if (col != null) {
      final doc = await col.doc(vendorId).get();
      if (doc.exists && doc.data() != null) {
        return VendorModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    }

    final match = _localVendors.where((v) => v.vendorId == vendorId);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<void> addVendor(VendorModel vendor) async {
    final col = _collection;
    if (col != null) {
      await col.doc(vendor.vendorId).set(vendor.toMap());
    }

    _localVendors.removeWhere((v) => v.vendorId == vendor.vendorId);
    _localVendors.insert(0, vendor);
    _vendorsStreamController.add(List.unmodifiable(_localVendors));
  }

  @override
  Future<void> updateVendor(VendorModel vendor) async {
    final col = _collection;
    if (col != null) {
      await col.doc(vendor.vendorId).update(vendor.toMap());
    }

    final index = _localVendors.indexWhere((v) => v.vendorId == vendor.vendorId);
    if (index != -1) {
      _localVendors[index] = vendor;
      _vendorsStreamController.add(List.unmodifiable(_localVendors));
    }
  }

  @override
  Future<void> archiveVendor(String vendorId, bool archive) async {
    final col = _collection;
    if (col != null) {
      await col.doc(vendorId).update({'isActive': !archive});
    }

    final index = _localVendors.indexWhere((v) => v.vendorId == vendorId);
    if (index != -1) {
      _localVendors[index] = _localVendors[index].copyWith(isActive: !archive);
      _vendorsStreamController.add(List.unmodifiable(_localVendors));
    }
  }
}
