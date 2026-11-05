import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_pos/core/constants/app_constants.dart';
import 'package:perfume_pos/data/models/product_model.dart';
import 'package:perfume_pos/data/models/sale_item_model.dart';
import 'package:perfume_pos/data/models/sale_model.dart';
import 'package:perfume_pos/data/repositories/accounts_repository.dart';
import 'package:perfume_pos/data/repositories/inventory_repository.dart';
import 'package:perfume_pos/data/repositories/sales_repository.dart';
import 'package:perfume_pos/features/inventory/providers/inventory_provider.dart';
import 'package:perfume_pos/features/pos/providers/cart_provider.dart';
import 'package:perfume_pos/features/sales/providers/sales_provider.dart';
import 'package:perfume_pos/features/stock_sold/providers/stock_sold_provider.dart';
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

  group('Phase 6 - Stock Sold & Profitability Analysis Tests', () {
    test('Product sales aggregation calculates sold quantity, revenue, COGS and profit correctly', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      // Add a test product
      final product = ProductModel(
        productId: 'prod_test_athar',
        productName: 'Royal Taif Rose',
        normalizedName: 'royal taif rose',
        productCode: 'RTR-101',
        productType: AppConstants.productTypeOil,
        category: 'Floral',
        unit: AppConstants.unitMl,
        totalPurchased: 200.0,
        totalSold: 0.0,
        availableQuantity: 200.0,
        vendorPricePerUnit: 10.0, // COGS = ₹10/ml
        sellingPricePerUnit: 25.0, // Selling = ₹25/ml
        createdAt: now,
        updatedAt: now,
      );
      await inventoryRepo.addProduct(product);

      // Record a sale of 20 ml:
      // Revenue = 20 * 25 = 500
      // COGS = 20 * 10 = 200
      // Gross Profit = 500 - 200 = 300
      // Margin = (300 / 500) * 100 = 60.0%
      final sale = SaleModel(
        saleId: 'sale_perf_001',
        invoiceNumber: 'INV-TEST-PERF',
        date: todayStr,
        timestamp: now,
        items: [
          SaleItemModel(
            productId: product.productId,
            productName: product.productName,
            productType: product.productType,
            quantity: 20.0,
            unit: product.unit,
            unitPrice: 25.0,
            unitCostAtSale: 10.0,
            totalPrice: 500.0,
          ),
        ],
        subtotal: 500.0,
        discount: 0.0,
        grandTotal: 500.0,
        paymentType: AppConstants.paymentCash,
        cashAmount: 500.0,
        onlineAmount: 0.0,
        createdBy: 'admin',
      );
      await salesRepo.completeSale(sale);

      final container = ProviderContainer(
        overrides: [
          inventoryRepositoryProvider.overrideWithValue(inventoryRepo),
          salesRepositoryProvider.overrideWithValue(salesRepo),
        ],
      );
      addTearDown(container.dispose);

      // Listen to ensure streams are primed
      final sub1 = container.listen(salesListStreamProvider, (_, __) {});
      final sub2 = container.listen(allProductsStreamProvider, (_, __) {});
      addTearDown(() {
        sub1.close();
        sub2.close();
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      container.read(stockSoldDateFilterProvider.notifier).setFilter('all');
      final aggregates = container.read(stockSoldAggregatesProvider);

      final match = aggregates.firstWhere((a) => a.productId == product.productId);
      expect(match.soldQuantity, 20.0);
      expect(match.totalRevenue, 500.0);
      expect(match.totalCogs, 200.0);
      expect(match.grossProfit, 300.0);
      expect(match.marginPercent, 60.0);
      expect(match.occurrences.length, 1);
      expect(match.occurrences.first.invoiceNumber, 'INV-TEST-PERF');
    });

    test('Overall summary computes total units, revenue, profit, and top seller accurately', () async {
      final container = ProviderContainer(
        overrides: [
          inventoryRepositoryProvider.overrideWithValue(inventoryRepo),
          salesRepositoryProvider.overrideWithValue(salesRepo),
        ],
      );
      addTearDown(container.dispose);

      final sub1 = container.listen(salesListStreamProvider, (_, __) {});
      final sub2 = container.listen(allProductsStreamProvider, (_, __) {});
      addTearDown(() {
        sub1.close();
        sub2.close();
      });
      await Future<void>.delayed(const Duration(milliseconds: 10));

      container.read(stockSoldDateFilterProvider.notifier).setFilter('all');
      final summary = container.read(stockSoldSummaryProvider);

      expect(summary.totalRevenue, greaterThan(0));
      expect(summary.totalGrossProfit, lessThanOrEqualTo(summary.totalRevenue));
      expect(summary.overallMarginPercent, greaterThan(0));
      expect(summary.topSellerName, isNot('-'));
    });

    test('Stock Sold CSV export outputs valid CSV string with all financial fields', () {
      final sampleItems = [
        {
          'productName': 'Dehn Al Oud Cambodi',
          'productCode': 'OUD-101',
          'category': 'Oud',
          'productType': 'Oil',
          'unit': 'ml',
          'soldQuantity': 25.0,
          'availableQuantity': 475.0,
          'totalRevenue': 625.0,
          'totalCogs': 300.0,
          'grossProfit': 325.0,
          'marginPercent': 52.0,
        }
      ];

      final csv = CsvService.instance.exportStockSoldToCsv(sampleItems);
      expect(csv.contains('Product Name,SKU / Code,Category,Type,Unit,Qty Sold,Available Stock,Total Revenue,COGS,Gross Profit,Margin %'), isTrue);
      expect(csv.contains('Dehn Al Oud Cambodi'), isTrue);
      expect(csv.contains('52.0%'), isTrue);
    });
  });
}
