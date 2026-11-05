import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_pos/core/constants/app_constants.dart';
import 'package:perfume_pos/data/models/sale_item_model.dart';
import 'package:perfume_pos/data/models/sale_model.dart';
import 'package:perfume_pos/data/repositories/accounts_repository.dart';
import 'package:perfume_pos/data/repositories/inventory_repository.dart';
import 'package:perfume_pos/data/repositories/sales_repository.dart';
import 'package:perfume_pos/features/pos/providers/cart_provider.dart';
import 'package:perfume_pos/features/sales/providers/sales_provider.dart';
import 'package:perfume_pos/services/csv/csv_service.dart';
import 'package:perfume_pos/services/firebase/firebase_service.dart';

void main() {
  late FirebaseInventoryRepository inventoryRepo;
  late FirebaseAccountsRepository accountsRepo;
  late FirebaseSalesRepository salesRepo;

  setUp(() {
    final firebaseService = FirebaseService.instance;
    inventoryRepo = FirebaseInventoryRepository(firebaseService);
    accountsRepo = FirebaseAccountsRepository(firebaseService);
    salesRepo = FirebaseSalesRepository(
      firebaseService,
      inventoryRepo,
      accountsRepository: accountsRepo,
    );
  });

  group('Phase 5 - Sales Management & Analytics Tests', () {
    test('Sales list stream retrieves initial demo transactions', () async {
      final sales = await salesRepo.getSales();
      expect(sales.length, greaterThanOrEqualTo(2));
      expect(sales.any((s) => s.invoiceNumber == 'INV-100234'), isTrue);
      expect(sales.any((s) => s.invoiceNumber == 'INV-100235'), isTrue);
    });

    test('Sale cancellation atomically restores product stock and marks sale cancelled', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      // Create a test sale with Oud Cambodi
      final product = await inventoryRepo.getProductByCode('OUD-101');
      expect(product, isNotNull);
      final initialStock = product!.availableQuantity;

      const saleQty = 15.0; // 15 ml @ ₹25 = ₹375
      const totalAmount = 375.0;

      final sale = SaleModel(
        saleId: 'sale_to_cancel',
        invoiceNumber: 'INV-TEST-CANCEL',
        date: todayStr,
        timestamp: now,
        items: [
          SaleItemModel(
            productId: product.productId,
            productName: product.productName,
            productType: product.productType,
            quantity: saleQty,
            unit: product.unit,
            unitPrice: product.sellingPricePerUnit,
            unitCostAtSale: product.vendorPricePerUnit,
            totalPrice: totalAmount,
          ),
        ],
        subtotal: totalAmount,
        discount: 0.0,
        grandTotal: totalAmount,
        paymentType: AppConstants.paymentCash,
        cashAmount: totalAmount,
        onlineAmount: 0.0,
        createdBy: 'admin_test',
        createdByName: 'Admin Test',
      );

      await salesRepo.completeSale(sale);

      // Verify stock decreased
      final productAfterSale = await inventoryRepo.getProductById(product.productId);
      expect(productAfterSale!.availableQuantity, initialStock - saleQty);

      // Now cancel sale
      await salesRepo.cancelSale('sale_to_cancel', 'Customer returned bottle', 'admin_test');

      // Verify sale is marked cancelled
      final cancelledSale = await salesRepo.getSaleById('sale_to_cancel');
      expect(cancelledSale, isNotNull);
      expect(cancelledSale!.isCancelled, isTrue);
      expect(cancelledSale.cancellationReason, 'Customer returned bottle');

      // Verify product stock restored
      final productAfterCancel = await inventoryRepo.getProductById(product.productId);
      expect(productAfterCancel!.availableQuantity, initialStock);

      // Verify reversal stock movement was logged
      final movements = await inventoryRepo.watchStockMovements(product.productId).first;
      expect(movements.any((m) => m.movementType == AppConstants.movementSaleReturn), isTrue);
    });

    test('Sales filtering & search providers filter transactions correctly', () async {
      final container = ProviderContainer(
        overrides: [
          salesRepositoryProvider.overrideWithValue(salesRepo),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(salesListStreamProvider, (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Set payment filter to split
      container.read(salesPaymentFilterProvider.notifier).setFilter(AppConstants.paymentSplit);
      final splitSales = container.read(filteredSalesProvider);
      expect(splitSales.isNotEmpty, isTrue);
      for (final s in splitSales) {
        expect(s.paymentType, AppConstants.paymentSplit);
      }

      // Reset payment filter and search for invoice
      container.read(salesPaymentFilterProvider.notifier).setFilter('');
      container.read(salesSearchProvider.notifier).setQuery('INV-100234');
      final searchResults = container.read(filteredSalesProvider);
      expect(searchResults.isNotEmpty, isTrue);
      expect(searchResults.every((s) => s.invoiceNumber.contains('100234')), isTrue);
    });

    test('SalesMetrics calculates totals, splits, and average order value accurately', () async {
      final container = ProviderContainer(
        overrides: [
          salesRepositoryProvider.overrideWithValue(salesRepo),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(salesListStreamProvider, (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Ensure 'all' period is selected for complete aggregate
      container.read(salesDateFilterProvider.notifier).setFilter('all');
      final metrics = container.read(salesMetricsProvider);

      expect(metrics.totalRevenue, greaterThan(0));
      expect(metrics.totalTransactions, greaterThan(0));
      expect(metrics.cashRevenue + metrics.onlineRevenue, metrics.totalRevenue);
      expect(metrics.averageTicketSize, greaterThan(0));
    });

    test('CSV export exports sales transactions with expected headers and row data', () async {
      final sales = await salesRepo.getSales();
      final csv = CsvService.instance.exportSalesToCsv(sales);

      expect(csv.contains('Date,Time,Invoice Number,Items Count,Subtotal,Discount,Grand Total,Payment Mode,Cash Paid,Online Paid,Status,Staff'), isTrue);
      expect(csv.contains('INV-100234'), isTrue);
    });
  });
}
