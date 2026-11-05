import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_pos/core/constants/app_constants.dart';
import 'package:perfume_pos/core/exceptions/app_exceptions.dart';
import 'package:perfume_pos/data/models/expense_model.dart';
import 'package:perfume_pos/data/models/product_model.dart';
import 'package:perfume_pos/data/models/sale_item_model.dart';
import 'package:perfume_pos/data/models/sale_model.dart';
import 'package:perfume_pos/data/repositories/accounts_repository.dart';
import 'package:perfume_pos/data/repositories/inventory_repository.dart';
import 'package:perfume_pos/data/repositories/sales_repository.dart';
import 'package:perfume_pos/features/accounts/providers/accounts_provider.dart';
import 'package:perfume_pos/features/inventory/providers/inventory_provider.dart';
import 'package:perfume_pos/features/pos/providers/cart_provider.dart';
import 'package:perfume_pos/features/sales/providers/sales_provider.dart';
import 'package:perfume_pos/features/stock_sold/providers/stock_sold_provider.dart';
import 'package:perfume_pos/services/firebase/firebase_service.dart';

void main() {
  late FirebaseInventoryRepository inventoryRepo;
  late FirebaseAccountsRepository accountsRepo;
  late FirebaseSalesRepository salesRepo;
  late ProviderContainer container;

  final now = DateTime.now();
  final todayStr = now.toIso8601String().split('T')[0];

  setUp(() async {
    final firebaseService = FirebaseService.instance;
    inventoryRepo = FirebaseInventoryRepository(firebaseService);
    accountsRepo = FirebaseAccountsRepository(firebaseService);
    salesRepo = FirebaseSalesRepository(
      firebaseService,
      inventoryRepo,
      accountsRepository: accountsRepo,
    );

    // Initialize clean opening balance for today
    await accountsRepo.setOpeningBalance(
      date: todayStr,
      cashOpening: 10000.0,
      onlineOpening: 25000.0,
      userId: 'test_admin',
    );

    container = ProviderContainer(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(inventoryRepo),
        accountsRepositoryProvider.overrideWithValue(accountsRepo),
        salesRepositoryProvider.overrideWithValue(salesRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Phase 8 - Master End-to-End System Integration', () {
    test('Scenario 1: New Product Registration & POS Visibility', () async {
      // 1. Register new perfume product
      final newProduct = ProductModel(
        productId: 'prod_royal_khas',
        productName: 'Al-Abeer Royal Khas Blend',
        normalizedName: 'al-abeer royal khas blend',
        productCode: 'ROY-901',
        productType: AppConstants.productTypeOil,
        category: 'Oud Blends',
        unit: AppConstants.unitMl,
        vendorId: 'v_ajmal',
        totalPurchased: 100.0,
        totalSold: 0.0,
        availableQuantity: 100.0,
        vendorPricePerUnit: 50.0,
        sellingPricePerUnit: 120.0,
        lowStockThreshold: 15.0,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await inventoryRepo.addProduct(newProduct, userId: 'test_admin');

      // 2. Verify product is queryable by ID and Code
      final retrieved = await inventoryRepo.getProductById('prod_royal_khas');
      expect(retrieved, isNotNull);
      expect(retrieved!.productCode, 'ROY-901');
      expect(retrieved.availableQuantity, 100.0);

      // 3. Verify opening stock movement logged
      final movements = await inventoryRepo.watchStockMovements('prod_royal_khas').first;
      expect(movements.isNotEmpty, isTrue);
      expect(movements.first.movementType, AppConstants.movementOpeningStock);
      expect(movements.first.quantity, 100.0);
    });

    test('Scenario 2: End-to-End POS Sale Transaction with Atomic Updates', () async {
      // Ensure test product exists
      final product = await inventoryRepo.getProductByCode('OUD-101');
      expect(product, isNotNull);
      final initialOudStock = product!.availableQuantity;
      final initialOudSold = product.totalSold;

      final nonOilProduct = await inventoryRepo.getProductByCode('EDP-701');
      expect(nonOilProduct, isNotNull);
      final initialSprayStock = nonOilProduct!.availableQuantity;
      final initialSpraySold = nonOilProduct.totalSold;

      // Read initial daily summary
      final initialSummary = await accountsRepo.getDailySummary(todayStr);

      // Create Sale with Split Payment: 10ml Oud (₹250) + 1 pc EDP Spray (₹1200) = ₹1450 - ₹50 discount = ₹1400
      final sale = SaleModel(
        saleId: 'sale_integ_001',
        invoiceNumber: 'INV-E2E-001',
        date: todayStr,
        timestamp: DateTime.now(),
        items: [
          SaleItemModel(
            productId: product.productId,
            productName: product.productName,
            productType: product.productType,
            quantity: 10.0,
            unit: product.unit,
            unitPrice: product.sellingPricePerUnit, // 25.0
            unitCostAtSale: product.vendorPricePerUnit, // 12.0
            totalPrice: 250.0,
          ),
          SaleItemModel(
            productId: nonOilProduct.productId,
            productName: nonOilProduct.productName,
            productType: nonOilProduct.productType,
            quantity: 1.0,
            unit: nonOilProduct.unit,
            unitPrice: nonOilProduct.sellingPricePerUnit, // 1200.0
            unitCostAtSale: nonOilProduct.vendorPricePerUnit, // 600.0
            totalPrice: 1200.0,
          ),
        ],
        subtotal: 1450.0,
        discount: 50.0,
        grandTotal: 1400.0,
        paymentType: AppConstants.paymentSplit,
        cashAmount: 600.0,
        onlineAmount: 800.0,
        status: AppConstants.saleStatusCompleted,
        createdBy: 'pos_cashier',
        createdByName: 'POS Cashier 1',
      );

      final completedSale = await salesRepo.completeSale(sale, idempotencyKey: 'idemp_e2e_001');
      expect(completedSale.status, AppConstants.saleStatusCompleted);

      // 1. Verify Inventory Stock Decreased
      final updatedOud = await inventoryRepo.getProductById(product.productId);
      expect(updatedOud!.availableQuantity, initialOudStock - 10.0);
      expect(updatedOud.totalSold, initialOudSold + 10.0);

      final updatedSpray = await inventoryRepo.getProductById(nonOilProduct.productId);
      expect(updatedSpray!.availableQuantity, initialSprayStock - 1.0);
      expect(updatedSpray.totalSold, initialSpraySold + 1.0);

      // 2. Verify Stock Movements Logged
      final oudMovements = await inventoryRepo.watchStockMovements(product.productId).first;
      final oudSaleMov = oudMovements.firstWhere((m) => m.referenceId == sale.saleId);
      expect(oudSaleMov.movementType, AppConstants.movementSale);
      expect(oudSaleMov.quantity, -10.0);

      final sprayMovements = await inventoryRepo.watchStockMovements(nonOilProduct.productId).first;
      final spraySaleMov = sprayMovements.firstWhere((m) => m.referenceId == sale.saleId);
      expect(spraySaleMov.movementType, AppConstants.movementSale);
      expect(spraySaleMov.quantity, -1.0);

      // 3. Verify Accounts Ledger Recorded SALE_INCOME
      final entries = await accountsRepo.getAccountEntries(date: todayStr, transactionType: AppConstants.entrySaleIncome);
      final saleEntry = entries.firstWhere((e) => e.referenceId == sale.saleId);
      expect(saleEntry.cashAmount, 600.0);
      expect(saleEntry.onlineAmount, 800.0);

      // 4. Verify Daily Summary Balances
      final updatedSummary = await accountsRepo.getDailySummary(todayStr);
      expect(updatedSummary.cashSales, initialSummary.cashSales + 600.0);
      expect(updatedSummary.onlineSales, initialSummary.onlineSales + 800.0);
      expect(updatedSummary.closingCashBalance, initialSummary.closingCashBalance + 600.0);
      expect(updatedSummary.closingOnlineBalance, initialSummary.closingOnlineBalance + 800.0);

      // 5. Verify Stock Sold Metrics
      final sub1 = container.listen(salesListStreamProvider, (_, __) {});
      final sub2 = container.listen(allProductsStreamProvider, (_, __) {});
      addTearDown(() {
        sub1.close();
        sub2.close();
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final aggregates = container.read(stockSoldAggregatesProvider);
      final oudSoldMetric = aggregates.firstWhere((m) => m.productId == product.productId);
      expect(oudSoldMetric.soldQuantity, greaterThanOrEqualTo(10.0));
      expect(oudSoldMetric.totalCogs, greaterThan(0));
      expect(oudSoldMetric.grossProfit, greaterThan(0));
    });

    test('Scenario 3: Insufficient Stock Rejection Guard', () async {
      final product = await inventoryRepo.getProductByCode('OUD-101');
      expect(product, isNotNull);
      final available = product!.availableQuantity;

      // Attempt to sell more than available
      final excessiveSale = SaleModel(
        saleId: 'sale_overflow',
        invoiceNumber: 'INV-ERR-001',
        date: todayStr,
        timestamp: DateTime.now(),
        items: [
          SaleItemModel(
            productId: product.productId,
            productName: product.productName,
            productType: product.productType,
            quantity: available + 50.0,
            unit: product.unit,
            unitPrice: product.sellingPricePerUnit,
            unitCostAtSale: product.vendorPricePerUnit,
            totalPrice: (available + 50.0) * product.sellingPricePerUnit,
          ),
        ],
        subtotal: (available + 50.0) * product.sellingPricePerUnit,
        discount: 0.0,
        grandTotal: (available + 50.0) * product.sellingPricePerUnit,
        paymentType: AppConstants.paymentCash,
        cashAmount: (available + 50.0) * product.sellingPricePerUnit,
        onlineAmount: 0.0,
        status: AppConstants.saleStatusCompleted,
        createdBy: 'cashier',
      );

      expect(
        () async => await salesRepo.completeSale(excessiveSale),
        throwsA(isA<InsufficientStockException>()),
      );

      // Verify stock was untouched
      final unchanged = await inventoryRepo.getProductById(product.productId);
      expect(unchanged!.availableQuantity, available);
    });

    test('Scenario 4: Payment Split Validation Enforcement', () async {
      final product = await inventoryRepo.getProductByCode('OUD-101');

      // Split where cash + online != grandTotal (Grand: 500, Cash: 200, Online: 250 -> Sum 450 != 500)
      final invalidSplitSale = SaleModel(
        saleId: 'sale_invalid_split',
        invoiceNumber: 'INV-ERR-SPLIT',
        date: todayStr,
        timestamp: DateTime.now(),
        items: [
          SaleItemModel(
            productId: product!.productId,
            productName: product.productName,
            productType: product.productType,
            quantity: 20.0,
            unit: product.unit,
            unitPrice: product.sellingPricePerUnit,
            unitCostAtSale: product.vendorPricePerUnit,
            totalPrice: 500.0,
          ),
        ],
        subtotal: 500.0,
        discount: 0.0,
        grandTotal: 500.0,
        paymentType: AppConstants.paymentSplit,
        cashAmount: 200.0,
        onlineAmount: 250.0, // Sum = 450 != 500
        status: AppConstants.saleStatusCompleted,
        createdBy: 'cashier',
      );

      expect(
        () async => await salesRepo.completeSale(invalidSplitSale),
        throwsA(isA<InvalidPaymentSplitException>()),
      );
    });

    test('Scenario 5: Expense Entry Reflects in Closing Balance Without Modifying Sales Income', () async {
      final summaryBefore = await accountsRepo.getDailySummary(todayStr);

      final expense = ExpenseModel(
        expenseId: 'exp_tea_001',
        date: todayStr,
        reason: 'Evening tea for showroom team',
        category: 'Staff Tea & Refreshments',
        totalAmount: 250.0,
        paymentMethod: AppConstants.paymentCash,
        cashAmount: 250.0,
        onlineAmount: 0.0,
        createdBy: 'store_manager',
        createdAt: DateTime.now(),
      );

      await accountsRepo.addExpense(expense);

      final summaryAfter = await accountsRepo.getDailySummary(todayStr);

      // Verify sales income remained completely unaffected
      expect(summaryAfter.cashSales, summaryBefore.cashSales);
      expect(summaryAfter.onlineSales, summaryBefore.onlineSales);
      expect(summaryAfter.totalSales, summaryBefore.totalSales);

      // Verify expenses updated
      expect(summaryAfter.cashExpenses, summaryBefore.cashExpenses + 250.0);
      expect(summaryAfter.totalExpenses, summaryBefore.totalExpenses + 250.0);

      // Verify closing cash decreased by exactly the expense amount
      expect(summaryAfter.closingCashBalance, summaryBefore.closingCashBalance - 250.0);
    });

    test('Scenario 6: Cash to Bank Transfer Balances Without Double Counting', () async {
      final summaryBefore = await accountsRepo.getDailySummary(todayStr);
      const transferAmount = 3000.0;

      await accountsRepo.recordCashToBankTransfer(
        amount: transferAmount,
        notes: 'Afternoon cash deposit to HDFC Bank',
        userId: 'store_manager',
        date: todayStr,
      );

      final summaryAfter = await accountsRepo.getDailySummary(todayStr);

      // Verify cash decreased by transfer amount
      expect(summaryAfter.closingCashBalance, summaryBefore.closingCashBalance - transferAmount);

      // Verify bank/online increased by transfer amount
      expect(summaryAfter.closingOnlineBalance, summaryBefore.closingOnlineBalance + transferAmount);

      // Verify total liquidity preserved
      final totalBefore = summaryBefore.closingCashBalance + summaryBefore.closingOnlineBalance;
      final totalAfter = summaryAfter.closingCashBalance + summaryAfter.closingOnlineBalance;
      expect((totalAfter - totalBefore).abs(), lessThanOrEqualTo(0.01));

      // Verify sales income was untouched
      expect(summaryAfter.totalSales, summaryBefore.totalSales);
    });

    test('Scenario 7: Controlled Sale Reversal Restores Stock and Ledger', () async {
      final product = await inventoryRepo.getProductByCode('OUD-101');
      expect(product, isNotNull);
      final initialStock = product!.availableQuantity;

      // 1. Perform a sale
      final saleToCancel = SaleModel(
        saleId: 'sale_to_cancel_001',
        invoiceNumber: 'INV-REV-001',
        date: todayStr,
        timestamp: DateTime.now(),
        items: [
          SaleItemModel(
            productId: product.productId,
            productName: product.productName,
            productType: product.productType,
            quantity: 5.0,
            unit: product.unit,
            unitPrice: 25.0,
            unitCostAtSale: 12.0,
            totalPrice: 125.0,
          ),
        ],
        subtotal: 125.0,
        discount: 0.0,
        grandTotal: 125.0,
        paymentType: AppConstants.paymentCash,
        cashAmount: 125.0,
        onlineAmount: 0.0,
        status: AppConstants.saleStatusCompleted,
        createdBy: 'cashier',
      );

      await salesRepo.completeSale(saleToCancel);

      final soldProduct = await inventoryRepo.getProductById(product.productId);
      expect(soldProduct!.availableQuantity, initialStock - 5.0);

      // 2. Cancel the sale
      await salesRepo.cancelSale(
        saleToCancel.saleId,
        'Customer changed mind at counter',
        'store_manager',
      );

      // 3. Verify stock restored
      final restoredProduct = await inventoryRepo.getProductById(product.productId);
      expect(restoredProduct!.availableQuantity, initialStock);

      // 4. Verify reversal movement recorded
      final movements = await inventoryRepo.watchStockMovements(product.productId).first;
      final reversalMov = movements.firstWhere((m) => m.referenceId == saleToCancel.saleId && m.movementType == AppConstants.movementSaleReturn);
      expect(reversalMov.quantity, 5.0);

      // 5. Verify reversal in account entries
      final entries = await accountsRepo.getAccountEntries(date: todayStr, transactionType: AppConstants.entryRefund);
      final reversalEntry = entries.firstWhere((e) => e.referenceId == saleToCancel.saleId);
      expect(reversalEntry.cashAmount, -125.0);

      // 6. Verify sale record status marked as cancelled
      final fetchedSale = await salesRepo.getSaleById(saleToCancel.saleId);
      expect(fetchedSale!.isCancelled, isTrue);
      expect(fetchedSale.cancellationReason, 'Customer changed mind at counter');
    });
  });
}
