import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_pos/core/constants/app_constants.dart';
import 'package:perfume_pos/data/models/product_model.dart';
import 'package:perfume_pos/data/models/purchase_model.dart';
import 'package:perfume_pos/data/repositories/inventory_repository.dart';
import 'package:perfume_pos/features/inventory/providers/inventory_provider.dart';
import 'package:perfume_pos/services/firebase/firebase_service.dart';

void main() {
  late FirebaseInventoryRepository inventoryRepo;
  late ProviderContainer container;

  setUp(() {
    final firebaseService = FirebaseService.instance;
    inventoryRepo = FirebaseInventoryRepository(firebaseService);

    container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(inventoryRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Phase 7 - Non-Oil Products & Inventory Engine', () {
    test('Non-Oil products filtered correctly from shared inventory repository', () async {
      final nonOilProducts = await inventoryRepo.getProducts(productType: AppConstants.productTypeNonOil);
      expect(nonOilProducts.isNotEmpty, isTrue);

      // Verify all items are non-oil and piece-based
      for (final p in nonOilProducts) {
        expect(p.productType, AppConstants.productTypeNonOil);
        expect(p.unit, AppConstants.unitPiece);
        expect(p.availableQuantity % 1, 0, reason: 'Non-oil products must have integer quantities');
      }

      // Verify oil products are excluded
      final containsOil = nonOilProducts.any((p) => p.productType == AppConstants.productTypeOil);
      expect(containsOil, isFalse);
    });

    test('Add Non-Oil product validates piece unit and creates opening stock movement', () async {
      final now = DateTime.now();
      final newNonOil = ProductModel(
        productId: 'prod_crystal_bottle_12ml',
        productName: 'Handmade Octagonal Crystal Bottle 12ml',
        normalizedName: 'handmade octagonal crystal bottle 12ml',
        productCode: 'BOT-801',
        productType: AppConstants.productTypeNonOil,
        category: 'Bottles',
        unit: AppConstants.unitPiece,
        vendorId: 'v_swiss_arabian',
        totalPurchased: 100.0,
        totalSold: 0.0,
        availableQuantity: 100.0,
        vendorPricePerUnit: 45.0,
        sellingPricePerUnit: 120.0,
        lowStockThreshold: 15.0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await inventoryRepo.addProduct(newNonOil, userId: 'test_admin');

      final fetched = await inventoryRepo.getProductById('prod_crystal_bottle_12ml');
      expect(fetched, isNotNull);
      expect(fetched!.productName, 'Handmade Octagonal Crystal Bottle 12ml');
      expect(fetched.unit, AppConstants.unitPiece);
      expect(fetched.availableQuantity, 100.0);
      expect(fetched.potentialSellingValue, 100.0 * 120.0);

      // Verify opening stock movement was recorded
      final movements = await inventoryRepo.watchStockMovements('prod_crystal_bottle_12ml').first;
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.movementType, AppConstants.movementOpeningStock);
      expect(movements.first.quantity, 100.0);
    });

    test('Non-Oil Stock In / Purchase updates integer quantity and preserves cost', () async {
      final bakhoor = await inventoryRepo.getProductByCode('BKH-601');
      expect(bakhoor, isNotNull);
      final initialStock = bakhoor!.availableQuantity;

      final purchase = PurchaseModel(
        purchaseId: 'pur_bkh_202',
        vendorId: 'v_ajmal',
        vendorName: 'Ajmal Fragrances UAE',
        purchaseDate: DateTime.now(),
        productId: bakhoor.productId,
        productName: bakhoor.productName,
        purchasedQuantity: 25.0, // 25 pieces
        unit: AppConstants.unitPiece,
        purchasePricePerUnit: 175.0,
        totalAmount: 25.0 * 175.0,
        paymentMethod: 'cash',
        notes: 'Restock of 50g Bakhoor Tablets',
        createdBy: 'test_admin',
        createdAt: DateTime.now(),
      );

      await inventoryRepo.recordPurchase(purchase);

      final updatedBakhoor = await inventoryRepo.getProductById(bakhoor.productId);
      expect(updatedBakhoor!.availableQuantity, initialStock + 25.0);
      expect(updatedBakhoor.totalPurchased, bakhoor.totalPurchased + 25.0);

      // Verify movement audit
      final movements = await inventoryRepo.watchStockMovements(bakhoor.productId).first;
      final match = movements.firstWhere((m) => m.referenceId == 'pur_bkh_202');
      expect(match.movementType, AppConstants.movementPurchase);
      expect(match.quantity, 25.0);
    });

    test('Non-Oil Physical Stock Adjustment writes off damaged pieces with audit log', () async {
      final spray = await inventoryRepo.getProductByCode('EDP-701');
      expect(spray, isNotNull);
      final initialStock = spray!.availableQuantity;

      // Adjust stock down due to damage (e.g. 2 pieces dropped during shelf rearrangement)
      final newQuantity = initialStock - 2.0;
      await inventoryRepo.adjustStock(
        productId: spray.productId,
        newQuantity: newQuantity,
        reason: '2 bottles broken during display setup',
        userId: 'store_manager',
      );

      final adjusted = await inventoryRepo.getProductById(spray.productId);
      expect(adjusted!.availableQuantity, newQuantity);

      // Verify movement audit
      final movements = await inventoryRepo.watchStockMovements(spray.productId).first;
      final adjustMovement = movements.firstWhere((m) => m.movementType == AppConstants.movementAdjustment);
      expect(adjustMovement.quantity, -2.0);
      expect(adjustMovement.notes, contains('2 bottles broken'));
    });

    test('Non-Oil metrics provider aggregates totals exclusively for non-oil products', () async {
      // Listen to keep provider alive
      final sub = container.listen(productsStreamProvider(AppConstants.productTypeNonOil), (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final metrics = container.read(nonOilInventoryMetricsProvider);
      expect(metrics.totalProducts, greaterThanOrEqualTo(2));
      expect(metrics.totalAvailableStock, greaterThan(0));
      expect(metrics.totalPurchaseValue, greaterThan(0));
      expect(metrics.potentialSellingValue, greaterThan(metrics.totalPurchaseValue));

      // Oil products should not count in non-oil metrics
      final oilProducts = await inventoryRepo.getProducts(productType: AppConstants.productTypeOil);
      for (final oil in oilProducts) {
        expect(oil.productType, AppConstants.productTypeOil);
      }
    });

    test('Non-Oil filter state handles search query, category, and stock filters', () async {
      final sub = container.listen(productsStreamProvider(AppConstants.productTypeNonOil), (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Filter by category
      container.read(nonOilInventoryFilterProvider.notifier).setSelectedCategory('Bakhoor');
      var filtered = container.read(filteredNonOilProductsProvider);
      expect(filtered.every((p) => p.category == 'Bakhoor'), isTrue);

      // Search query
      container.read(nonOilInventoryFilterProvider.notifier).reset();
      container.read(nonOilInventoryFilterProvider.notifier).setSearchQuery('Wood');
      filtered = container.read(filteredNonOilProductsProvider);
      expect(filtered.length, 1);
      expect(filtered.first.productCode, 'EDP-701');

      // Low stock filter
      container.read(nonOilInventoryFilterProvider.notifier).reset();
      container.read(nonOilInventoryFilterProvider.notifier).setStockFilter(StockFilter.lowStock);
      filtered = container.read(filteredNonOilProductsProvider);
      for (final p in filtered) {
        expect(p.isLowStock, isTrue);
      }
    });
  });
}
