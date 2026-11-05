import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../../sales/providers/sales_provider.dart';

class ProductSaleOccurrence {
  final String saleId;
  final String invoiceNumber;
  final String date;
  final DateTime timestamp;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalPrice;
  final String cashier;

  const ProductSaleOccurrence({
    required this.saleId,
    required this.invoiceNumber,
    required this.date,
    required this.timestamp,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalPrice,
    required this.cashier,
  });
}

class ProductSaleAggregate {
  final String productId;
  final String productName;
  final String productCode;
  final String category;
  final String productType;
  final String unit;
  final double soldQuantity;
  final double availableQuantity;
  final double totalRevenue;
  final double totalCogs;
  final double grossProfit;
  final double marginPercent;
  final List<ProductSaleOccurrence> occurrences;

  const ProductSaleAggregate({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.category,
    required this.productType,
    required this.unit,
    required this.soldQuantity,
    required this.availableQuantity,
    required this.totalRevenue,
    required this.totalCogs,
    required this.grossProfit,
    required this.marginPercent,
    required this.occurrences,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'category': category,
      'productType': productType,
      'unit': unit,
      'soldQuantity': soldQuantity,
      'availableQuantity': availableQuantity,
      'totalRevenue': totalRevenue,
      'totalCogs': totalCogs,
      'grossProfit': grossProfit,
      'marginPercent': marginPercent,
    };
  }
}

class StockSoldOverallSummary {
  final double totalQuantitySold;
  final double totalRevenue;
  final double totalCogs;
  final double totalGrossProfit;
  final double overallMarginPercent;
  final String topSellerName;
  final double topSellerQty;

  const StockSoldOverallSummary({
    required this.totalQuantitySold,
    required this.totalRevenue,
    required this.totalCogs,
    required this.totalGrossProfit,
    required this.overallMarginPercent,
    required this.topSellerName,
    required this.topSellerQty,
  });
}

// Filter Notifiers
class StockSoldDateFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all'; // 'today' | 'yesterday' | 'week' | 'month' | 'all'
  void setFilter(String filter) => state = filter;
}

final stockSoldDateFilterProvider = NotifierProvider<StockSoldDateFilterNotifier, String>(() {
  return StockSoldDateFilterNotifier();
});

class StockSoldTypeFilterNotifier extends Notifier<String> {
  @override
  String build() => ''; // '' = all, 'Oil', 'Non-Oil'
  void setFilter(String filter) => state = filter;
}

final stockSoldTypeFilterProvider = NotifierProvider<StockSoldTypeFilterNotifier, String>(() {
  return StockSoldTypeFilterNotifier();
});

class StockSoldCategoryFilterNotifier extends Notifier<String> {
  @override
  String build() => ''; // '' = all
  void setFilter(String filter) => state = filter;
}

final stockSoldCategoryFilterProvider = NotifierProvider<StockSoldCategoryFilterNotifier, String>(() {
  return StockSoldCategoryFilterNotifier();
});

class StockSoldSortNotifier extends Notifier<String> {
  @override
  String build() => 'qty_desc'; // 'qty_desc', 'rev_desc', 'profit_desc', 'margin_desc'
  void setSort(String sort) => state = sort;
}

final stockSoldSortProvider = NotifierProvider<StockSoldSortNotifier, String>(() {
  return StockSoldSortNotifier();
});

class StockSoldSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final stockSoldSearchProvider = NotifierProvider<StockSoldSearchNotifier, String>(() {
  return StockSoldSearchNotifier();
});

// Aggregated product sales calculation
final stockSoldAggregatesProvider = Provider.autoDispose<List<ProductSaleAggregate>>((ref) {
  final salesAsync = ref.watch(salesListStreamProvider);
  final productsAsync = ref.watch(allProductsStreamProvider);

  final sales = salesAsync.value ?? [];
  final products = productsAsync.value ?? [];

  final dateFilter = ref.watch(stockSoldDateFilterProvider);
  final typeFilter = ref.watch(stockSoldTypeFilterProvider);
  final categoryFilter = ref.watch(stockSoldCategoryFilterProvider);
  final searchQuery = ref.watch(stockSoldSearchProvider).trim().toLowerCase();
  final sortOrder = ref.watch(stockSoldSortProvider);

  final now = DateTime.now();
  final todayStr = DateFormatter.toIsoDate(now);
  final yesterdayStr = DateFormatter.toIsoDate(now.subtract(const Duration(days: 1)));
  final weekAgo = now.subtract(const Duration(days: 7));
  final monthAgo = now.subtract(const Duration(days: 30));

  // Map to group sales by product ID
  final Map<String, List<ProductSaleOccurrence>> occurrencesByProduct = {};
  final Map<String, double> qtyByProduct = {};
  final Map<String, double> revByProduct = {};
  final Map<String, double> cogsByProduct = {};

  for (final s in sales) {
    if (!s.isCompleted) continue; // Skip cancelled sales

    // Date Filter check
    if (dateFilter == 'today' && s.date != todayStr) continue;
    if (dateFilter == 'yesterday' && s.date != yesterdayStr) continue;
    if (dateFilter == 'week' && s.timestamp.isBefore(weekAgo)) continue;
    if (dateFilter == 'month' && s.timestamp.isBefore(monthAgo)) continue;

    for (final item in s.items) {
      qtyByProduct[item.productId] = CurrencyFormatter.round((qtyByProduct[item.productId] ?? 0.0) + item.quantity);
      revByProduct[item.productId] = CurrencyFormatter.round((revByProduct[item.productId] ?? 0.0) + item.totalPrice);
      final itemCogs = CurrencyFormatter.round(item.quantity * item.unitCostAtSale);
      cogsByProduct[item.productId] = CurrencyFormatter.round((cogsByProduct[item.productId] ?? 0.0) + itemCogs);

      occurrencesByProduct.putIfAbsent(item.productId, () => []).add(
        ProductSaleOccurrence(
          saleId: s.saleId,
          invoiceNumber: s.invoiceNumber,
          date: s.date,
          timestamp: s.timestamp,
          quantity: item.quantity,
          unit: item.unit,
          unitPrice: item.unitPrice,
          totalPrice: item.totalPrice,
          cashier: s.createdByName ?? s.createdBy,
        ),
      );
    }
  }

  // Combine with catalog products to display comprehensive view
  final List<ProductSaleAggregate> aggregates = [];

  for (final p in products) {
    final soldQty = qtyByProduct[p.productId] ?? 0.0;
    final totalRev = revByProduct[p.productId] ?? 0.0;
    final totalCogs = cogsByProduct[p.productId] ?? 0.0;
    final grossProfit = CurrencyFormatter.round(totalRev - totalCogs);
    final marginPercent = totalRev > 0
        ? CurrencyFormatter.round((grossProfit / totalRev) * 100)
        : 0.0;

    // Type filter
    if (typeFilter.isNotEmpty && p.productType != typeFilter) continue;

    // Category filter
    if (categoryFilter.isNotEmpty && p.category != categoryFilter) continue;

    // Search query
    if (searchQuery.isNotEmpty) {
      final nameMatch = p.productName.toLowerCase().contains(searchQuery);
      final codeMatch = p.productCode.toLowerCase().contains(searchQuery);
      final catMatch = p.category.toLowerCase().contains(searchQuery);
      if (!nameMatch && !codeMatch && !catMatch) continue;
    }

    aggregates.add(
      ProductSaleAggregate(
        productId: p.productId,
        productName: p.productName,
        productCode: p.productCode,
        category: p.category,
        productType: p.productType,
        unit: p.unit,
        soldQuantity: soldQty,
        availableQuantity: p.availableQuantity,
        totalRevenue: totalRev,
        totalCogs: totalCogs,
        grossProfit: grossProfit,
        marginPercent: marginPercent,
        occurrences: occurrencesByProduct[p.productId] ?? [],
      ),
    );
  }

  // Sorting
  aggregates.sort((a, b) {
    if (sortOrder == 'qty_desc') {
      return b.soldQuantity.compareTo(a.soldQuantity);
    } else if (sortOrder == 'rev_desc') {
      return b.totalRevenue.compareTo(a.totalRevenue);
    } else if (sortOrder == 'profit_desc') {
      return b.grossProfit.compareTo(a.grossProfit);
    } else if (sortOrder == 'margin_desc') {
      return b.marginPercent.compareTo(a.marginPercent);
    }
    return b.soldQuantity.compareTo(a.soldQuantity);
  });

  return aggregates;
});

final stockSoldSummaryProvider = Provider.autoDispose<StockSoldOverallSummary>((ref) {
  final aggregates = ref.watch(stockSoldAggregatesProvider);

  double totalQty = 0.0;
  double totalRev = 0.0;
  double totalCogs = 0.0;
  double totalProfit = 0.0;
  String topSeller = '-';
  double topQty = 0.0;

  for (final a in aggregates) {
    totalQty += a.soldQuantity;
    totalRev += a.totalRevenue;
    totalCogs += a.totalCogs;
    totalProfit += a.grossProfit;

    if (a.soldQuantity > topQty) {
      topQty = a.soldQuantity;
      topSeller = '${a.productName} ($topQty ${a.unit})';
    }
  }

  totalQty = CurrencyFormatter.round(totalQty);
  totalRev = CurrencyFormatter.round(totalRev);
  totalCogs = CurrencyFormatter.round(totalCogs);
  totalProfit = CurrencyFormatter.round(totalProfit);

  final overallMargin = totalRev > 0
      ? CurrencyFormatter.round((totalProfit / totalRev) * 100)
      : 0.0;

  return StockSoldOverallSummary(
    totalQuantitySold: totalQty,
    totalRevenue: totalRev,
    totalCogs: totalCogs,
    totalGrossProfit: totalProfit,
    overallMarginPercent: overallMargin,
    topSellerName: topSeller,
    topSellerQty: topQty,
  );
});
