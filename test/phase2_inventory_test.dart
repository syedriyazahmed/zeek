import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_pos/core/constants/app_constants.dart';
import 'package:perfume_pos/data/models/product_model.dart';
import 'package:perfume_pos/data/models/purchase_model.dart';
import 'package:perfume_pos/data/models/vendor_model.dart';
import 'package:perfume_pos/data/repositories/inventory_repository.dart';
import 'package:perfume_pos/data/repositories/vendor_repository.dart';
import 'package:perfume_pos/services/csv/csv_service.dart';
import 'package:perfume_pos/services/firebase/firebase_service.dart';

void main() {
  late FirebaseInventoryRepository inventoryRepo;
  late FirebaseVendorRepository vendorRepo;

  setUp(() {
    final firebaseService = FirebaseService.instance;
    inventoryRepo = FirebaseInventoryRepository(firebaseService);
    vendorRepo = FirebaseVendorRepository(firebaseService);
  });

  group('Phase 2 - Product CRUD & Inventory Operations', () {
    test('Default products initialized correctly with accurate stock levels', () async {
      final products = await inventoryRepo.getProducts(productType: AppConstants.productTypeOil);
      expect(products.isNotEmpty, isTrue);

      final cambodi = products.firstWhere((p) => p.productCode == 'OUD-101');
      expect(cambodi.productName, contains('Oud Cambodi'));
      expect(cambodi.availableQuantity, 455.0);
      expect(cambodi.unit, AppConstants.unitMl);
      expect(cambodi.sellingPricePerUnit, 25.0);
      expect(cambodi.potentialSellingValue, 11375.0); // 455 * 25
    });

    test('Add Product creates product and initial opening stock movement', () async {
      final now = DateTime.now();
      final newProduct = ProductModel(
        productId: 'prod_test_amber',
        productName: 'Royal Ambergris Supreme',
        normalizedName: 'royal ambergris supreme',
        productCode: 'AMB-999',
        productType: AppConstants.productTypeOil,
        category: 'Amber',
        unit: AppConstants.unitMl,
        totalPurchased: 200.0,
        totalSold: 0.0,
        availableQuantity: 200.0,
        vendorPricePerUnit: 20.0,
        sellingPricePerUnit: 45.0,
        lowStockThreshold: 20.0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await inventoryRepo.addProduct(newProduct, userId: 'test_admin');

      final fetched = await inventoryRepo.getProductById('prod_test_amber');
      expect(fetched, isNotNull);
      expect(fetched!.productName, 'Royal Ambergris Supreme');
      expect(fetched.availableQuantity, 200.0);

      // Verify movement recorded
      final movements = await inventoryRepo.watchStockMovements('prod_test_amber').first;
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.movementType, AppConstants.movementOpeningStock);
      expect(movements.first.quantity, 200.0);
    });

    test('Stock In / Purchase updates inventory quantity and logs purchase record', () async {
      final initialProduct = await inventoryRepo.getProductByCode('OUD-101');
      expect(initialProduct, isNotNull);
      final initialStock = initialProduct!.availableQuantity;

      final purchase = PurchaseModel(
        purchaseId: 'pur_test_101',
        vendorId: 'v_ajmal',
        vendorName: 'Ajmal Fragrances UAE',
        purchaseDate: DateTime.now(),
        productId: initialProduct.productId,
        productName: initialProduct.productName,
        purchasedQuantity: 100.0,
        unit: initialProduct.unit,
        purchasePricePerUnit: 14.0,
        totalAmount: 1400.0,
        paymentMethod: 'cash',
        notes: 'Test batch purchase',
        createdBy: 'test_admin',
        createdAt: DateTime.now(),
      );

      await inventoryRepo.recordPurchase(purchase);

      final updatedProduct = await inventoryRepo.getProductById(initialProduct.productId);
      expect(updatedProduct!.availableQuantity, initialStock + 100.0);
      expect(updatedProduct.totalPurchased, initialProduct.totalPurchased + 100.0);

      // Verify movement recorded
      final movements = await inventoryRepo.watchStockMovements(initialProduct.productId).first;
      final purchaseMovement = movements.firstWhere((m) => m.referenceId == 'pur_test_101');
      expect(purchaseMovement.movementType, AppConstants.movementPurchase);
      expect(purchaseMovement.quantity, 100.0);
    });

    test('Stock Adjustment updates quantity and records signed difference audit trail', () async {
      final product = await inventoryRepo.getProductByCode('MSK-201');
      expect(product, isNotNull);
      final oldStock = product!.availableQuantity;

      // New physical count is 50 ml lower due to spillage
      final newPhysicalStock = oldStock - 50.0;

      await inventoryRepo.adjustStock(
        productId: product.productId,
        newQuantity: newPhysicalStock,
        reason: 'Spillage / Leakage: damaged bottle',
        userId: 'audit_manager',
      );

      final updated = await inventoryRepo.getProductById(product.productId);
      expect(updated!.availableQuantity, newPhysicalStock);

      final movements = await inventoryRepo.watchStockMovements(product.productId).first;
      final adjMovement = movements.firstWhere((m) => m.movementType == AppConstants.movementAdjustment);
      expect(adjMovement.quantity, -50.0); // Signed negative deduction
      expect(adjMovement.notes, contains('Spillage'));
    });

    test('Archive Product hides it from active listings but preserves history', () async {
      final product = await inventoryRepo.getProductByCode('AFG-501');
      expect(product, isNotNull);

      await inventoryRepo.archiveProduct(product!.productId, true);

      final activeList = await inventoryRepo.getProducts(includeArchived: false);
      expect(activeList.any((p) => p.productId == product.productId), isFalse);

      final fullList = await inventoryRepo.getProducts(includeArchived: true);
      expect(fullList.any((p) => p.productId == product.productId), isTrue);
    });
  });

  group('Phase 2 - Vendor Management', () {
    test('Vendor CRUD operations work correctly', () async {
      final vendors = await vendorRepo.getVendors();
      expect(vendors.isNotEmpty, isTrue);

      final newVendor = VendorModel(
        vendorId: 'v_arabian_oud',
        vendorName: 'Arabian Oud KSA',
        phoneNumber: '+966 11 234 5678',
        address: 'Riyadh, Saudi Arabia',
        companyName: 'Arabian Oud Perfumes',
        notes: 'Premium Agarwood distillation specialists',
        createdDate: DateTime.now(),
        isActive: true,
      );

      await vendorRepo.addVendor(newVendor);

      final fetched = await vendorRepo.getVendorById('v_arabian_oud');
      expect(fetched, isNotNull);
      expect(fetched!.vendorName, 'Arabian Oud KSA');

      await vendorRepo.updateVendor(fetched.copyWith(phoneNumber: '+966 11 999 8888'));
      final updated = await vendorRepo.getVendorById('v_arabian_oud');
      expect(updated!.phoneNumber, '+966 11 999 8888');
    });
  });

  group('Phase 2 - CSV Import & Export', () {
    test('CSV parsing validates valid products and reports errors for invalid rows', () {
      const csvData = '''
Product Name,Product Code,Product Type,Category,Unit,Selling Price,Vendor Price,Available Quantity,Low Stock Threshold
Silver Musk,SLV-001,Oil,Musk,ml,10.00,6.00,100,20
Amber Gold,AMB-002,Oil,Amber,ml,15.00,8.00,150,25
Invalid Product,,Oil,General,ml,12.00,5.00,50,10
Negative Price,NEG-001,Oil,General,ml,-5.00,5.00,50,10
Piece Non Whole,PC-001,Non-Oil,Sprays,piece,500.00,300.00,12.5,5
''';

      final result = CsvService.instance.parseAndValidateCsv(csvData);

      expect(result.validCount, 2);
      expect(result.validProducts.first.productCode, 'SLV-001');
      expect(result.validProducts[1].productCode, 'AMB-002');

      expect(result.hasErrors, isTrue);
      expect(result.errors.length, 3);
      // Empty code
      expect(result.errors.any((e) => e.reason.contains('code/SKU cannot be empty')), isTrue);
      // Negative price
      expect(result.errors.any((e) => e.reason.contains('Selling price must be greater than 0')), isTrue);
      // Non-whole piece quantity
      expect(result.errors.any((e) => e.reason.contains('whole number quantities')), isTrue);
    });

    test('CSV export outputs valid CSV string with all expected columns', () {
      final products = [
        ProductModel(
          productId: 'prod_exp_1',
          productName: 'Rose Taif Extra',
          normalizedName: 'rose taif extra',
          productCode: 'ROS-999',
          productType: 'Oil',
          category: 'Floral',
          unit: 'ml',
          availableQuantity: 50.0,
          sellingPricePerUnit: 20.0,
          vendorPricePerUnit: 10.0,
          lowStockThreshold: 15.0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final csvString = CsvService.instance.exportProductsToCsv(products);
      expect(csvString, contains('Rose Taif Extra'));
      expect(csvString, contains('ROS-999'));
      expect(csvString, contains('20.0'));
    });
  });
}

