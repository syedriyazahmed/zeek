import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_pos/core/constants/app_constants.dart';
import 'package:perfume_pos/core/exceptions/app_exceptions.dart';
import 'package:perfume_pos/data/models/product_model.dart';
import 'package:perfume_pos/data/models/sale_item_model.dart';
import 'package:perfume_pos/data/models/sale_model.dart';
import 'package:perfume_pos/data/repositories/inventory_repository.dart';
import 'package:perfume_pos/data/repositories/sales_repository.dart';
import 'package:perfume_pos/features/pos/providers/cart_provider.dart';
import 'package:perfume_pos/services/firebase/firebase_service.dart';
import 'package:perfume_pos/services/invoice/invoice_service.dart';

void main() {
  late FirebaseInventoryRepository inventoryRepo;
  late FirebaseSalesRepository salesRepo;

  setUp(() {
    final firebaseService = FirebaseService.instance;
    inventoryRepo = FirebaseInventoryRepository(firebaseService);
    salesRepo = FirebaseSalesRepository(firebaseService, inventoryRepo);
  });

  group('Phase 3 - POS Cart Management Tests', () {
    test('Cart accurately calculates subtotal, discounts, and decimal oil quantities', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cartProvider.notifier);

      final p1 = ProductModel(
        productId: 'prod_oud',
        productName: 'Oud Premium',
        normalizedName: 'oud premium',
        productCode: 'OUD-01',
        productType: 'Oil',
        category: 'Oud',
        unit: 'ml',
        availableQuantity: 100.0,
        sellingPricePerUnit: 25.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final p2 = ProductModel(
        productId: 'prod_spray',
        productName: 'Rose Spray 50ml',
        normalizedName: 'rose spray 50ml',
        productCode: 'RSE-01',
        productType: 'Non-Oil',
        category: 'Spray',
        unit: 'piece',
        availableQuantity: 20.0,
        sellingPricePerUnit: 500.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add 10 ml of Oud (10 * 25 = 250)
      notifier.addProduct(p1, 10.0);
      expect(container.read(cartProvider).subtotal, 250.0);
      expect(container.read(cartProvider).grandTotal, 250.0);
      expect(container.read(cartProvider).cashAmount, 250.0);

      // Add 2 pieces of Spray (2 * 500 = 1000)
      notifier.addProduct(p2, 2.0);
      expect(container.read(cartProvider).subtotal, 1250.0);
      expect(container.read(cartProvider).grandTotal, 1250.0);
      expect(container.read(cartProvider).cashAmount, 1250.0);

      // Apply ₹50 discount
      notifier.setDiscount(50.0);
      expect(container.read(cartProvider).discount, 50.0);
      expect(container.read(cartProvider).grandTotal, 1200.0);
      expect(container.read(cartProvider).cashAmount, 1200.0);
    });

    test('Split payment validation: correctly validates cash + online == grandTotal', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(cartProvider.notifier);

      final product = ProductModel(
        productId: 'prod_musk',
        productName: 'White Musk',
        normalizedName: 'white musk',
        productCode: 'MSK-01',
        productType: 'Oil',
        category: 'Musk',
        unit: 'ml',
        availableQuantity: 50.0,
        sellingPricePerUnit: 10.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 50 ml @ ₹10 = ₹500
      notifier.addProduct(product, 50.0);
      expect(container.read(cartProvider).grandTotal, 500.0);

      // Switch to Split
      notifier.setPaymentType(AppConstants.paymentSplit);
      expect(container.read(cartProvider).isSplitValid, isTrue);

      // Set Cash = ₹200 -> Online auto-balances to ₹300
      notifier.setCashAmount(200.0);
      expect(container.read(cartProvider).cashAmount, 200.0);
      expect(container.read(cartProvider).onlineAmount, 300.0);
      expect(container.read(cartProvider).isSplitValid, isTrue);
      expect(container.read(cartProvider).canCheckout, isTrue);

      // Mismatch test: directly construct invalid split
      final invalidCart = container.read(cartProvider).copyWith(cashAmount: 200.0, onlineAmount: 250.0);
      expect(invalidCart.isSplitValid, isFalse);
      expect(invalidCart.canCheckout, isFalse);
    });
  });

  group('Phase 3 - Sales Transaction & Stock Deductions', () {
    test('Successful sale atomically deducts stock and records movement & ledger entry', () async {
      final cambodi = await inventoryRepo.getProductByCode('OUD-101');
      expect(cambodi, isNotNull);
      final initialStock = cambodi!.availableQuantity;
      final initialSold = cambodi.totalSold;

      const saleQty = 25.0; // 25 ml
      final unitPrice = cambodi.sellingPricePerUnit; // ₹25/ml
      final grandTotal = saleQty * unitPrice; // ₹625

      final now = DateTime.now();
      final sale = SaleModel(
        saleId: 'sale_test_001',
        invoiceNumber: 'INV-TEST-001',
        date: now.toIso8601String().split('T')[0],
        timestamp: now,
        items: [
          SaleItemModel(
            productId: cambodi.productId,
            productName: cambodi.productName,
            productType: cambodi.productType,
            quantity: saleQty,
            unit: cambodi.unit,
            unitPrice: unitPrice,
            unitCostAtSale: cambodi.vendorPricePerUnit,
            totalPrice: grandTotal,
          ),
        ],
        subtotal: grandTotal,
        discount: 0.0,
        grandTotal: grandTotal,
        paymentType: AppConstants.paymentSplit,
        cashAmount: 225.0,
        onlineAmount: 400.0,
        status: AppConstants.saleStatusCompleted,
        createdBy: 'staff_1',
        createdByName: 'Staff Member',
      );

      final confirmed = await salesRepo.completeSale(sale, idempotencyKey: 'idem_key_001');
      expect(confirmed.invoiceNumber, 'INV-TEST-001');

      // Verify product stock decreased
      final updatedProduct = await inventoryRepo.getProductById(cambodi.productId);
      expect(updatedProduct!.availableQuantity, initialStock - saleQty);
      expect(updatedProduct.totalSold, initialSold + saleQty);

      // Verify stock movement logged (negative quantity)
      final movements = await inventoryRepo.watchStockMovements(cambodi.productId).first;
      final saleMovement = movements.firstWhere((m) => m.referenceId == 'sale_test_001');
      expect(saleMovement.movementType, AppConstants.movementSale);
      expect(saleMovement.quantity, -saleQty);

      // Verify idempotency: re-running with same key returns existing sale
      final duplicateAttempt = await salesRepo.completeSale(sale, idempotencyKey: 'idem_key_001');
      expect(duplicateAttempt.saleId, confirmed.saleId);
      // Stock should NOT be deducted twice
      final productAfterDuplicate = await inventoryRepo.getProductById(cambodi.productId);
      expect(productAfterDuplicate!.availableQuantity, initialStock - saleQty);
    });

    test('Sale rejects transaction if requested quantity exceeds available stock', () async {
      final product = await inventoryRepo.getProductByCode('ROS-301');
      expect(product, isNotNull);
      final available = product!.availableQuantity;

      final now = DateTime.now();
      final excessiveSale = SaleModel(
        saleId: 'sale_excessive',
        invoiceNumber: 'INV-FAIL-01',
        date: now.toIso8601String().split('T')[0],
        timestamp: now,
        items: [
          SaleItemModel(
            productId: product.productId,
            productName: product.productName,
            productType: product.productType,
            quantity: available + 100.0, // Exceeds stock!
            unit: product.unit,
            unitPrice: product.sellingPricePerUnit,
            totalPrice: (available + 100.0) * product.sellingPricePerUnit,
          ),
        ],
        subtotal: (available + 100.0) * product.sellingPricePerUnit,
        grandTotal: (available + 100.0) * product.sellingPricePerUnit,
        paymentType: AppConstants.paymentCash,
        cashAmount: (available + 100.0) * product.sellingPricePerUnit,
        onlineAmount: 0.0,
        status: AppConstants.saleStatusCompleted,
        createdBy: 'staff_1',
      );

      expect(
        () async => await salesRepo.completeSale(excessiveSale),
        throwsA(isA<InsufficientStockException>()),
      );

      // Verify stock was not changed
      final checkProduct = await inventoryRepo.getProductById(product.productId);
      expect(checkProduct!.availableQuantity, available);
    });

    test('Sale rejects transaction if payment split does not equal Grand Total', () async {
      final product = (await inventoryRepo.getProductByCode('MSK-201'))!;

      final now = DateTime.now();
      final invalidSplitSale = SaleModel(
        saleId: 'sale_bad_split',
        invoiceNumber: 'INV-BAD-01',
        date: now.toIso8601String().split('T')[0],
        timestamp: now,
        items: [
          SaleItemModel(
            productId: product.productId,
            productName: product.productName,
            productType: product.productType,
            quantity: 10.0,
            unit: product.unit,
            unitPrice: 10.0,
            totalPrice: 100.0,
          ),
        ],
        subtotal: 100.0,
        grandTotal: 100.0,
        paymentType: AppConstants.paymentSplit,
        cashAmount: 50.0,
        onlineAmount: 40.0, // 50 + 40 = 90 != 100
        status: AppConstants.saleStatusCompleted,
        createdBy: 'staff_1',
      );

      expect(
        () async => await salesRepo.completeSale(invalidSplitSale),
        throwsA(isA<InvalidPaymentSplitException>()),
      );
    });

    test('InvoiceService generates printable PDF byte document successfully', () async {
      final now = DateTime.now();
      final sampleSale = SaleModel(
        saleId: 'sale_pdf_01',
        invoiceNumber: 'INV-109988',
        date: now.toIso8601String().split('T')[0],
        timestamp: now,
        items: [
          const SaleItemModel(
            productId: 'p1',
            productName: 'Oud Cambodi Pure Grade A',
            productType: 'Oil',
            quantity: 12.0,
            unit: 'ml',
            unitPrice: 25.0,
            totalPrice: 300.0,
          ),
          const SaleItemModel(
            productId: 'p2',
            productName: 'Dehn Al Ward Taifi',
            productType: 'Oil',
            quantity: 6.0,
            unit: 'ml',
            unitPrice: 18.0,
            totalPrice: 108.0,
          ),
        ],
        subtotal: 408.0,
        discount: 8.0,
        grandTotal: 400.0,
        paymentType: AppConstants.paymentSplit,
        cashAmount: 200.0,
        onlineAmount: 200.0,
        status: AppConstants.saleStatusCompleted,
        createdBy: 'admin',
        createdByName: 'Shop Administrator',
      );

      final pdfBytes = await InvoiceService.instance.generateInvoicePdf(sampleSale);
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      expect(pdfBytes.length, greaterThan(1000)); // Non-empty valid PDF bytes
    });
  });
}
