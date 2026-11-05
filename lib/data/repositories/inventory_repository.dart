import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../services/firebase/firebase_service.dart';
import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../models/stock_movement_model.dart';

abstract class InventoryRepository {
  Stream<List<ProductModel>> watchProducts({String? productType, bool includeArchived = false});
  Future<List<ProductModel>> getProducts({String? productType, bool includeArchived = false});
  Future<ProductModel?> getProductById(String productId);
  Future<ProductModel?> getProductByCode(String productCode);
  Future<void> addProduct(ProductModel product, {String userId = 'admin'});
  Future<void> updateProduct(ProductModel product);
  Future<void> archiveProduct(String productId, bool archive);
  Future<void> adjustStock({
    required String productId,
    required double newQuantity,
    required String reason,
    required String userId,
  });
  Future<void> recordPurchase(PurchaseModel purchase);
  Future<void> recordStockMovements(List<StockMovementModel> movements);
  Future<void> batchAddProducts(List<ProductModel> products, {String userId = 'admin'});
  Stream<List<StockMovementModel>> watchStockMovements(String productId);
  Stream<List<PurchaseModel>> watchPurchases({String? vendorId, String? productId});
}

class FirebaseInventoryRepository implements InventoryRepository {
  final FirebaseService _firebaseService;
  final String _shopId;

  // In-memory reactive state cache
  final List<ProductModel> _localProducts = [];
  final List<StockMovementModel> _localMovements = [];
  final List<PurchaseModel> _localPurchases = [];

  final _productsController = StreamController<List<ProductModel>>.broadcast();
  final _movementsController = StreamController<List<StockMovementModel>>.broadcast();
  final _purchasesController = StreamController<List<PurchaseModel>>.broadcast();

  FirebaseInventoryRepository(
    this._firebaseService, {
    String shopId = AppConstants.defaultShopId,
  }) : _shopId = shopId {
    _initDefaultInventory();
  }

  void _initDefaultInventory() {
    if (_localProducts.isEmpty) {
      final now = DateTime.now();
      final defaultList = [
        ProductModel(
          productId: 'prod_oud_cambodi',
          productName: 'Oud Cambodi Pure Grade A',
          normalizedName: 'oud cambodi pure grade a',
          productCode: 'OUD-101',
          productType: AppConstants.productTypeOil,
          category: 'Oud',
          unit: AppConstants.unitMl,
          vendorId: 'v_ajmal',
          totalPurchased: 500.0,
          totalSold: 45.0,
          availableQuantity: 455.0,
          vendorPricePerUnit: 12.0,
          sellingPricePerUnit: 25.0,
          lowStockThreshold: 50.0,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 30)),
          updatedAt: now,
        ),
        ProductModel(
          productId: 'prod_white_musk',
          productName: 'Royal White Musk Concentrated',
          normalizedName: 'royal white musk concentrated',
          productCode: 'MSK-201',
          productType: AppConstants.productTypeOil,
          category: 'Musk',
          unit: AppConstants.unitMl,
          vendorId: 'v_swiss_arabian',
          totalPurchased: 1000.0,
          totalSold: 280.0,
          availableQuantity: 720.0,
          vendorPricePerUnit: 4.5,
          sellingPricePerUnit: 10.0,
          lowStockThreshold: 100.0,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 28)),
          updatedAt: now,
        ),
        ProductModel(
          productId: 'prod_rose_taif',
          productName: 'Dehn Al Ward Taifi (Rose)',
          normalizedName: 'dehn al ward taifi rose',
          productCode: 'ROS-301',
          productType: AppConstants.productTypeOil,
          category: 'Floral',
          unit: AppConstants.unitMl,
          vendorId: 'v_al_haramain',
          totalPurchased: 400.0,
          totalSold: 365.0,
          availableQuantity: 35.0, // Low stock demo!
          vendorPricePerUnit: 8.0,
          sellingPricePerUnit: 18.0,
          lowStockThreshold: 50.0,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 25)),
          updatedAt: now,
        ),
        ProductModel(
          productId: 'prod_amber_oud',
          productName: 'Amber Royal Oud Blend',
          normalizedName: 'amber royal oud blend',
          productCode: 'AMB-401',
          productType: AppConstants.productTypeOil,
          category: 'Amber',
          unit: AppConstants.unitMl,
          vendorId: 'v_ajmal',
          totalPurchased: 300.0,
          totalSold: 300.0,
          availableQuantity: 0.0, // Out of stock demo!
          vendorPricePerUnit: 6.0,
          sellingPricePerUnit: 15.0,
          lowStockThreshold: 30.0,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 20)),
          updatedAt: now,
        ),
        ProductModel(
          productId: 'prod_black_afgano',
          productName: 'Black Afgano Athar Oil',
          normalizedName: 'black afgano athar oil',
          productCode: 'AFG-501',
          productType: AppConstants.productTypeOil,
          category: 'Oriental',
          unit: AppConstants.unitMl,
          vendorId: 'v_swiss_arabian',
          totalPurchased: 600.0,
          totalSold: 120.0,
          availableQuantity: 480.0,
          vendorPricePerUnit: 7.0,
          sellingPricePerUnit: 16.0,
          lowStockThreshold: 40.0,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 15)),
          updatedAt: now,
        ),
        // Non-Oil Products for shared engine
        ProductModel(
          productId: 'prod_bakhoor_khas',
          productName: 'Bakhoor Khas Tablets (50g)',
          normalizedName: 'bakhoor khas tablets 50g',
          productCode: 'BKH-601',
          productType: AppConstants.productTypeNonOil,
          category: 'Bakhoor',
          unit: AppConstants.unitPiece,
          vendorId: 'v_ajmal',
          totalPurchased: 50.0,
          totalSold: 12.0,
          availableQuantity: 38.0,
          vendorPricePerUnit: 180.0,
          sellingPricePerUnit: 350.0,
          lowStockThreshold: 10.0,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now,
        ),
        ProductModel(
          productId: 'prod_spray_oud_wood',
          productName: 'Oud Wood Eau De Parfum 100ml Spray',
          normalizedName: 'oud wood eau de parfum 100ml spray',
          productCode: 'EDP-701',
          productType: AppConstants.productTypeNonOil,
          category: 'Perfume Sprays',
          unit: AppConstants.unitPiece,
          vendorId: 'v_swiss_arabian',
          totalPurchased: 30.0,
          totalSold: 8.0,
          availableQuantity: 22.0,
          vendorPricePerUnit: 600.0,
          sellingPricePerUnit: 1200.0,
          lowStockThreshold: 5.0,
          isActive: true,
          createdAt: now.subtract(const Duration(days: 8)),
          updatedAt: now,
        ),
      ];

      _localProducts.addAll(defaultList);
      _productsController.add(List.unmodifiable(_localProducts));

      // Add initial stock movements
      for (final p in defaultList) {
        _localMovements.add(
          StockMovementModel(
            movementId: 'mov_init_${p.productId}',
            productId: p.productId,
            productName: p.productName,
            movementType: AppConstants.movementOpeningStock,
            quantity: p.totalPurchased,
            unit: p.unit,
            referenceId: 'INITIAL_STOCK',
            date: now.subtract(const Duration(days: 30)).toIso8601String().split('T')[0],
            notes: 'Initial opening stock intake',
            createdBy: 'admin',
            createdAt: now.subtract(const Duration(days: 30)),
          ),
        );
      }
      _movementsController.add(List.unmodifiable(_localMovements));
    }
  }

  DocumentReference<Map<String, dynamic>>? get _shopRef {
    if (_firebaseService.isInitialized && _firebaseService.firestore != null) {
      return _firebaseService.firestore!.collection('shops').doc(_shopId);
    }
    return null;
  }

  @override
  Stream<List<ProductModel>> watchProducts({String? productType, bool includeArchived = false}) async* {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('products').orderBy('productName');
      if (productType != null) {
        query = query.where('productType', isEqualTo: productType);
      }
      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }
      yield* query.snapshots().map((snap) {
        return snap.docs.map((d) => ProductModel.fromMap(d.data(), d.id)).toList();
      });
    } else {
      yield _localProducts.where((p) {
        if (!includeArchived && !p.isActive) return false;
        if (productType != null && p.productType != productType) return false;
        return true;
      }).toList();
      yield* _productsController.stream.map((list) {
        return list.where((p) {
          if (!includeArchived && !p.isActive) return false;
          if (productType != null && p.productType != productType) return false;
          return true;
        }).toList();
      });
    }
  }

  @override
  Future<List<ProductModel>> getProducts({String? productType, bool includeArchived = false}) async {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('products').orderBy('productName');
      if (productType != null) {
        query = query.where('productType', isEqualTo: productType);
      }
      if (!includeArchived) {
        query = query.where('isActive', isEqualTo: true);
      }
      final snap = await query.get();
      return snap.docs.map((d) => ProductModel.fromMap(d.data(), d.id)).toList();
    }

    return _localProducts.where((p) {
      if (!includeArchived && !p.isActive) return false;
      if (productType != null && p.productType != productType) return false;
      return true;
    }).toList();
  }

  @override
  Future<ProductModel?> getProductById(String productId) async {
    final sRef = _shopRef;
    if (sRef != null) {
      final doc = await sRef.collection('products').doc(productId).get();
      if (doc.exists && doc.data() != null) {
        return ProductModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    }

    final match = _localProducts.where((p) => p.productId == productId);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<ProductModel?> getProductByCode(String productCode) async {
    final sRef = _shopRef;
    if (sRef != null) {
      final snap = await sRef
          .collection('products')
          .where('productCode', isEqualTo: productCode.trim().toUpperCase())
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return ProductModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
      }
      return null;
    }

    final clean = productCode.trim().toUpperCase();
    final match = _localProducts.where((p) => p.productCode.toUpperCase() == clean);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<void> addProduct(ProductModel product, {String userId = 'admin'}) async {
    final sRef = _shopRef;
    final now = DateTime.now();

    if (sRef != null) {
      final batch = _firebaseService.firestore!.batch();
      final prodDoc = sRef.collection('products').doc(product.productId);
      batch.set(prodDoc, product.toMap());

      // If initial stock > 0, log opening stock movement
      if (product.availableQuantity > 0) {
        final movDoc = sRef.collection('stock_movements').doc();
        batch.set(
          movDoc,
          StockMovementModel(
            movementId: movDoc.id,
            productId: product.productId,
            productName: product.productName,
            movementType: AppConstants.movementOpeningStock,
            quantity: product.availableQuantity,
            unit: product.unit,
            referenceId: 'OPENING_STOCK',
            date: now.toIso8601String().split('T')[0],
            notes: 'Product creation opening stock',
            createdBy: userId,
            createdAt: now,
          ).toMap(),
        );
      }
      await batch.commit();
    }

    _localProducts.removeWhere((p) => p.productId == product.productId);
    _localProducts.insert(0, product);
    _productsController.add(List.unmodifiable(_localProducts));

    if (product.availableQuantity > 0) {
      _localMovements.insert(
        0,
        StockMovementModel(
          movementId: 'mov_${DateTime.now().millisecondsSinceEpoch}',
          productId: product.productId,
          productName: product.productName,
          movementType: AppConstants.movementOpeningStock,
          quantity: product.availableQuantity,
          unit: product.unit,
          referenceId: 'OPENING_STOCK',
          date: now.toIso8601String().split('T')[0],
          notes: 'Product creation opening stock',
          createdBy: userId,
          createdAt: now,
        ),
      );
      _movementsController.add(List.unmodifiable(_localMovements));
    }
  }

  @override
  Future<void> updateProduct(ProductModel product) async {
    final sRef = _shopRef;
    if (sRef != null) {
      await sRef.collection('products').doc(product.productId).update(product.toMap());
    }

    final index = _localProducts.indexWhere((p) => p.productId == product.productId);
    if (index != -1) {
      _localProducts[index] = product;
      _productsController.add(List.unmodifiable(_localProducts));
    }
  }

  @override
  Future<void> archiveProduct(String productId, bool archive) async {
    final sRef = _shopRef;
    if (sRef != null) {
      await sRef.collection('products').doc(productId).update({
        'isActive': !archive,
        'updatedAt': Timestamp.now(),
      });
    }

    final index = _localProducts.indexWhere((p) => p.productId == productId);
    if (index != -1) {
      _localProducts[index] = _localProducts[index].copyWith(
        isActive: !archive,
        updatedAt: DateTime.now(),
      );
      _productsController.add(List.unmodifiable(_localProducts));
    }
  }

  @override
  Future<void> adjustStock({
    required String productId,
    required double newQuantity,
    required String reason,
    required String userId,
  }) async {
    final product = await getProductById(productId);
    if (product == null) throw Exception('Product $productId not found');

    final diff = newQuantity - product.availableQuantity;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];

    final updatedProduct = product.copyWith(
      availableQuantity: newQuantity,
      updatedAt: now,
    );

    final movement = StockMovementModel(
      movementId: 'mov_adj_${now.millisecondsSinceEpoch}',
      productId: productId,
      productName: product.productName,
      movementType: AppConstants.movementAdjustment,
      quantity: diff, // Signed difference
      unit: product.unit,
      referenceId: 'AUDIT_ADJUSTMENT',
      date: todayStr,
      notes: reason,
      createdBy: userId,
      createdAt: now,
    );

    final sRef = _shopRef;
    if (sRef != null) {
      final batch = _firebaseService.firestore!.batch();
      batch.update(sRef.collection('products').doc(productId), updatedProduct.toMap());
      final movDoc = sRef.collection('stock_movements').doc(movement.movementId);
      batch.set(movDoc, movement.toMap());
      await batch.commit();
    }

    final index = _localProducts.indexWhere((p) => p.productId == productId);
    if (index != -1) {
      _localProducts[index] = updatedProduct;
      _productsController.add(List.unmodifiable(_localProducts));
    }

    _localMovements.insert(0, movement);
    _movementsController.add(List.unmodifiable(_localMovements));
  }

  @override
  Future<void> recordPurchase(PurchaseModel purchase) async {
    final product = await getProductById(purchase.productId);
    if (product == null) throw Exception('Product ${purchase.productId} not found');

    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];

    final newAvailable = product.availableQuantity + purchase.purchasedQuantity;
    final newPurchased = product.totalPurchased + purchase.purchasedQuantity;

    final updatedProduct = product.copyWith(
      availableQuantity: newAvailable,
      totalPurchased: newPurchased,
      vendorPricePerUnit: purchase.purchasePricePerUnit,
      vendorId: purchase.vendorId.isNotEmpty ? purchase.vendorId : product.vendorId,
      updatedAt: now,
    );

    final movement = StockMovementModel(
      movementId: 'mov_pur_${now.millisecondsSinceEpoch}',
      productId: purchase.productId,
      productName: purchase.productName,
      movementType: AppConstants.movementPurchase,
      quantity: purchase.purchasedQuantity,
      unit: purchase.unit,
      referenceId: purchase.purchaseId,
      date: todayStr,
      notes: purchase.notes ?? 'Stock intake purchase',
      createdBy: purchase.createdBy,
      createdAt: now,
    );

    final sRef = _shopRef;
    if (sRef != null) {
      final batch = _firebaseService.firestore!.batch();
      batch.set(sRef.collection('purchases').doc(purchase.purchaseId), purchase.toMap());
      batch.update(sRef.collection('products').doc(purchase.productId), updatedProduct.toMap());
      batch.set(sRef.collection('stock_movements').doc(movement.movementId), movement.toMap());
      await batch.commit();
    }

    final index = _localProducts.indexWhere((p) => p.productId == purchase.productId);
    if (index != -1) {
      _localProducts[index] = updatedProduct;
      _productsController.add(List.unmodifiable(_localProducts));
    }

    _localPurchases.insert(0, purchase);
    _purchasesController.add(List.unmodifiable(_localPurchases));

    _localMovements.insert(0, movement);
    _movementsController.add(List.unmodifiable(_localMovements));
  }

  @override
  Future<void> batchAddProducts(List<ProductModel> products, {String userId = 'admin'}) async {
    final sRef = _shopRef;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];

    if (sRef != null) {
      // Chunk into batches of 400 (under Firestore 500 limit)
      const chunkSize = 400;
      for (var i = 0; i < products.length; i += chunkSize) {
        final end = (i + chunkSize < products.length) ? i + chunkSize : products.length;
        final chunk = products.sublist(i, end);
        final batch = _firebaseService.firestore!.batch();

        for (final p in chunk) {
          final pDoc = sRef.collection('products').doc(p.productId);
          batch.set(pDoc, p.toMap());

          if (p.availableQuantity > 0) {
            final mDoc = sRef.collection('stock_movements').doc();
            batch.set(
              mDoc,
              StockMovementModel(
                movementId: mDoc.id,
                productId: p.productId,
                productName: p.productName,
                movementType: AppConstants.movementOpeningStock,
                quantity: p.availableQuantity,
                unit: p.unit,
                referenceId: 'CSV_IMPORT',
                date: todayStr,
                notes: 'Bulk CSV opening stock import',
                createdBy: userId,
                createdAt: now,
              ).toMap(),
            );
          }
        }
        await batch.commit();
      }
    }

    for (final p in products) {
      _localProducts.removeWhere((existing) => existing.productCode == p.productCode);
      _localProducts.insert(0, p);

      if (p.availableQuantity > 0) {
        _localMovements.insert(
          0,
          StockMovementModel(
            movementId: 'mov_csv_${now.millisecondsSinceEpoch}_${p.productCode}',
            productId: p.productId,
            productName: p.productName,
            movementType: AppConstants.movementOpeningStock,
            quantity: p.availableQuantity,
            unit: p.unit,
            referenceId: 'CSV_IMPORT',
            date: todayStr,
            notes: 'Bulk CSV opening stock import',
            createdBy: userId,
            createdAt: now,
          ),
        );
      }
    }

    _productsController.add(List.unmodifiable(_localProducts));
    _movementsController.add(List.unmodifiable(_localMovements));
  }

  @override
  Future<void> recordStockMovements(List<StockMovementModel> movements) async {
    final sRef = _shopRef;
    if (sRef != null) {
      final batch = _firebaseService.firestore!.batch();
      for (final m in movements) {
        final docRef = sRef.collection('stock_movements').doc(m.movementId);
        batch.set(docRef, m.toMap());
      }
      await batch.commit();
    }

    _localMovements.insertAll(0, movements);
    _movementsController.add(List.unmodifiable(_localMovements));
  }

  @override
  Stream<List<StockMovementModel>> watchStockMovements(String productId) async* {
    final sRef = _shopRef;
    if (sRef != null) {
      yield* sRef
          .collection('stock_movements')
          .where('productId', isEqualTo: productId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((d) => StockMovementModel.fromMap(d.data(), d.id)).toList());
    } else {
      yield _localMovements.where((m) => m.productId == productId).toList();
      yield* _movementsController.stream.map((list) {
        return list.where((m) => m.productId == productId).toList();
      });
    }
  }

  @override
  Stream<List<PurchaseModel>> watchPurchases({String? vendorId, String? productId}) async* {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('purchases').orderBy('purchaseDate', descending: true);
      if (vendorId != null) query = query.where('vendorId', isEqualTo: vendorId);
      if (productId != null) query = query.where('productId', isEqualTo: productId);
      yield* query.snapshots().map((snap) => snap.docs.map((d) => PurchaseModel.fromMap(d.data(), d.id)).toList());
    } else {
      yield _localPurchases.where((p) {
        if (vendorId != null && p.vendorId != vendorId) return false;
        if (productId != null && p.productId != productId) return false;
        return true;
      }).toList();
      yield* _purchasesController.stream.map((list) {
        return list.where((p) {
          if (vendorId != null && p.vendorId != vendorId) return false;
          if (productId != null && p.productId != productId) return false;
          return true;
        }).toList();
      });
    }
  }
}
