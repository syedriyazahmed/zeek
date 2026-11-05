import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/inventory_repository.dart';
import '../../authentication/providers/auth_provider.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return FirebaseInventoryRepository(firebaseService);
});

enum StockFilter { all, inStock, lowStock, outOfStock }

class InventoryFilterState {
  final String searchQuery;
  final String selectedCategory;
  final StockFilter stockFilter;
  final String productType; // 'Oil' | 'Non-Oil'

  const InventoryFilterState({
    this.searchQuery = '',
    this.selectedCategory = 'All',
    this.stockFilter = StockFilter.all,
    this.productType = AppConstants.productTypeOil,
  });

  InventoryFilterState copyWith({
    String? searchQuery,
    String? selectedCategory,
    StockFilter? stockFilter,
    String? productType,
  }) {
    return InventoryFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      stockFilter: stockFilter ?? this.stockFilter,
      productType: productType ?? this.productType,
    );
  }
}

class InventoryFilterNotifier extends Notifier<InventoryFilterState> {
  final String _initialType;

  InventoryFilterNotifier([this._initialType = AppConstants.productTypeOil]);

  @override
  InventoryFilterState build() {
    return InventoryFilterState(productType: _initialType);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSelectedCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setStockFilter(StockFilter filter) {
    state = state.copyWith(stockFilter: filter);
  }

  void setProductType(String type) {
    state = state.copyWith(productType: type);
  }

  void reset() {
    state = InventoryFilterState(productType: state.productType);
  }
}

final oilInventoryFilterProvider =
    NotifierProvider<InventoryFilterNotifier, InventoryFilterState>(() {
  return InventoryFilterNotifier(AppConstants.productTypeOil);
});

final nonOilInventoryFilterProvider =
    NotifierProvider<InventoryFilterNotifier, InventoryFilterState>(() {
  return InventoryFilterNotifier(AppConstants.productTypeNonOil);
});

// Stream of products for a specific type
final productsStreamProvider =
    StreamProvider.family<List<ProductModel>, String>((ref, productType) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchProducts(
    productType: productType.isEmpty ? null : productType,
    includeArchived: false,
  );
});

// Stream of all active products across all types
final allProductsStreamProvider = StreamProvider<List<ProductModel>>((ref) {
  final repository = ref.watch(inventoryRepositoryProvider);
  return repository.watchProducts(includeArchived: false);
});

// Filtered products provider for Oil Inventory
final filteredOilProductsProvider = Provider<List<ProductModel>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider(AppConstants.productTypeOil));
  final filter = ref.watch(oilInventoryFilterProvider);

  return productsAsync.when(
    data: (products) {
      return products.where((p) {
        // Search query
        if (filter.searchQuery.isNotEmpty) {
          final q = filter.searchQuery.toLowerCase();
          final matchName = p.productName.toLowerCase().contains(q);
          final matchCode = p.productCode.toLowerCase().contains(q);
          final matchCategory = p.category.toLowerCase().contains(q);
          if (!matchName && !matchCode && !matchCategory) return false;
        }

        // Category filter
        if (filter.selectedCategory != 'All' && p.category != filter.selectedCategory) {
          return false;
        }

        // Stock filter
        switch (filter.stockFilter) {
          case StockFilter.all:
            break;
          case StockFilter.inStock:
            if (p.isOutOfStock) return false;
            break;
          case StockFilter.lowStock:
            if (!p.isLowStock) return false;
            break;
          case StockFilter.outOfStock:
            if (!p.isOutOfStock) return false;
            break;
        }

        return true;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Inventory Metrics
class InventoryMetrics {
  final int totalProducts;
  final double totalAvailableStock;
  final double totalPurchaseValue;
  final double potentialSellingValue;
  final double expectedMargin;
  final int lowStockCount;
  final int outOfStockCount;

  const InventoryMetrics({
    this.totalProducts = 0,
    this.totalAvailableStock = 0.0,
    this.totalPurchaseValue = 0.0,
    this.potentialSellingValue = 0.0,
    this.expectedMargin = 0.0,
    this.lowStockCount = 0,
    this.outOfStockCount = 0,
  });
}

final oilInventoryMetricsProvider = Provider<InventoryMetrics>((ref) {
  final productsAsync = ref.watch(productsStreamProvider(AppConstants.productTypeOil));

  return productsAsync.when(
    data: (products) {
      int active = 0;
      double stock = 0.0;
      double purchaseCost = 0.0;
      double sellingVal = 0.0;
      int low = 0;
      int out = 0;

      for (final p in products) {
        if (!p.isActive) continue;
        active++;
        stock += p.availableQuantity;
        purchaseCost += (p.availableQuantity * p.vendorPricePerUnit);
        sellingVal += (p.availableQuantity * p.sellingPricePerUnit);
        if (p.isOutOfStock) {
          out++;
        } else if (p.isLowStock) {
          low++;
        }
      }

      final roundedCost = CurrencyFormatter.round(purchaseCost);
      final roundedSelling = CurrencyFormatter.round(sellingVal);

      return InventoryMetrics(
        totalProducts: active,
        totalAvailableStock: CurrencyFormatter.round(stock),
        totalPurchaseValue: roundedCost,
        potentialSellingValue: roundedSelling,
        expectedMargin: CurrencyFormatter.round(roundedSelling - roundedCost),
        lowStockCount: low,
        outOfStockCount: out,
      );
    },
    loading: () => const InventoryMetrics(),
    error: (_, __) => const InventoryMetrics(),
  );
});

// Categories list for filters
final oilCategoriesProvider = Provider<List<String>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider(AppConstants.productTypeOil));
  return productsAsync.when(
    data: (products) {
      final set = <String>{'All'};
      for (final p in products) {
        if (p.category.trim().isNotEmpty) {
          set.add(p.category.trim());
        }
      }
      return set.toList();
    },
    loading: () => ['All'],
    error: (_, __) => ['All'],
  );
});

// Filtered products provider for Non-Oil Inventory
final filteredNonOilProductsProvider = Provider<List<ProductModel>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider(AppConstants.productTypeNonOil));
  final filter = ref.watch(nonOilInventoryFilterProvider);

  return productsAsync.when(
    data: (products) {
      return products.where((p) {
        // Search query
        if (filter.searchQuery.isNotEmpty) {
          final q = filter.searchQuery.toLowerCase();
          final matchName = p.productName.toLowerCase().contains(q);
          final matchCode = p.productCode.toLowerCase().contains(q);
          final matchCategory = p.category.toLowerCase().contains(q);
          if (!matchName && !matchCode && !matchCategory) return false;
        }

        // Category filter
        if (filter.selectedCategory != 'All' && p.category != filter.selectedCategory) {
          return false;
        }

        // Stock filter
        switch (filter.stockFilter) {
          case StockFilter.all:
            break;
          case StockFilter.inStock:
            if (p.isOutOfStock) return false;
            break;
          case StockFilter.lowStock:
            if (!p.isLowStock) return false;
            break;
          case StockFilter.outOfStock:
            if (!p.isOutOfStock) return false;
            break;
        }

        return true;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

// Metrics for Non-Oil Inventory
final nonOilInventoryMetricsProvider = Provider<InventoryMetrics>((ref) {
  final productsAsync = ref.watch(productsStreamProvider(AppConstants.productTypeNonOil));

  return productsAsync.when(
    data: (products) {
      int active = 0;
      double stock = 0.0;
      double purchaseCost = 0.0;
      double sellingVal = 0.0;
      int low = 0;
      int out = 0;

      for (final p in products) {
        if (!p.isActive) continue;
        active++;
        stock += p.availableQuantity;
        purchaseCost += (p.availableQuantity * p.vendorPricePerUnit);
        sellingVal += (p.availableQuantity * p.sellingPricePerUnit);
        if (p.isOutOfStock) {
          out++;
        } else if (p.isLowStock) {
          low++;
        }
      }

      final roundedCost = CurrencyFormatter.round(purchaseCost);
      final roundedSelling = CurrencyFormatter.round(sellingVal);

      return InventoryMetrics(
        totalProducts: active,
        totalAvailableStock: CurrencyFormatter.round(stock),
        totalPurchaseValue: roundedCost,
        potentialSellingValue: roundedSelling,
        expectedMargin: CurrencyFormatter.round(roundedSelling - roundedCost),
        lowStockCount: low,
        outOfStockCount: out,
      );
    },
    loading: () => const InventoryMetrics(),
    error: (_, __) => const InventoryMetrics(),
  );
});

// Categories list for Non-Oil filters
final nonOilCategoriesProvider = Provider<List<String>>((ref) {
  final productsAsync = ref.watch(productsStreamProvider(AppConstants.productTypeNonOil));
  return productsAsync.when(
    data: (products) {
      final set = <String>{'All'};
      for (final p in products) {
        if (p.category.trim().isNotEmpty) {
          set.add(p.category.trim());
        }
      }
      return set.toList();
    },
    loading: () => ['All'],
    error: (_, __) => ['All'],
  );
});
