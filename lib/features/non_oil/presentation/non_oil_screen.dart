import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../services/csv/csv_service.dart';
import '../../inventory/presentation/widgets/add_edit_product_dialog.dart';
import '../../inventory/presentation/widgets/csv_import_dialog.dart';
import '../../inventory/presentation/widgets/stock_adjustment_dialog.dart';
import '../../inventory/presentation/widgets/stock_movement_dialog.dart';
import '../../inventory/presentation/widgets/stock_purchase_dialog.dart';
import '../../inventory/providers/inventory_provider.dart';

class NonOilScreen extends ConsumerStatefulWidget {
  const NonOilScreen({super.key});

  @override
  ConsumerState<NonOilScreen> createState() => _NonOilScreenState();
}

class _NonOilScreenState extends ConsumerState<NonOilScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv(List<ProductModel> products) {
    final csv = CsvService.instance.exportProductsToCsv(products);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Non-Oil Inventory CSV'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total ${products.length} Non-Oil products exported in standard CSV format.'),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(filteredNonOilProductsProvider);
    final metrics = ref.watch(nonOilInventoryMetricsProvider);
    final categories = ref.watch(nonOilCategoriesProvider);
    final filterState = ref.watch(nonOilInventoryFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Action Buttons
            _buildHeader(context, products),

            const SizedBox(height: 16),

            // Summary Metric Cards
            _buildSummaryCards(metrics),

            const SizedBox(height: 16),

            // Filter & Search Toolbar
            _buildFilterToolbar(filterState, categories),

            const SizedBox(height: 16),

            // Non-Oil Product Table / Cards
            _buildProductList(context, products),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<ProductModel> products) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Non-Oil Products Inventory',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Manage perfume sprays, crystal/glass bottles, bakhoor, gift boxes & accessories (piece units)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),

        // Action Buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Import CSV
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const CsvImportDialog(productType: AppConstants.productTypeNonOil),
                );
              },
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: const Text('Import CSV'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),

            // Export CSV
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
              onPressed: () => _exportCsv(products),
            ),

            // Add Product Button
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const AddEditProductDialog(
                    defaultProductType: AppConstants.productTypeNonOil,
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Non-Oil Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(InventoryMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final cardWidth = isWide ? (constraints.maxWidth - (5 * 12)) / 6 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(
              title: 'Active Non-Oil Items',
              value: '${metrics.totalProducts}',
              subtitle: 'Sprays, bottles & boxes',
              icon: Icons.category_rounded,
              color: AppColors.primary,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Total Stock Available',
              value: '${metrics.totalAvailableStock.toInt()} pcs',
              subtitle: 'Count in showroom & store',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.cashGreen,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Stock Purchase Value',
              value: CurrencyFormatter.format(metrics.totalPurchaseValue),
              subtitle: 'Acquisition inventory cost',
              icon: Icons.price_change_rounded,
              color: AppColors.secondary,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Potential Sales Value',
              value: CurrencyFormatter.format(metrics.potentialSellingValue),
              subtitle: 'Retail shelf value',
              icon: Icons.storefront_rounded,
              color: Colors.indigo,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Low Stock (< Threshold)',
              value: '${metrics.lowStockCount}',
              subtitle: 'Needs replenishment',
              icon: Icons.warning_amber_rounded,
              color: metrics.lowStockCount > 0 ? AppColors.warning : AppColors.textSecondary,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Out of Stock Items',
              value: '${metrics.outOfStockCount}',
              subtitle: 'Zero pieces remaining',
              icon: Icons.block_rounded,
              color: metrics.outOfStockCount > 0 ? AppColors.error : AppColors.textSecondary,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar(InventoryFilterState filter, List<String> categories) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search non-oil item by name, SKU or category...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(nonOilInventoryFilterProvider.notifier).setSearchQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => ref.read(nonOilInventoryFilterProvider.notifier).setSearchQuery(val),
          ),
          const SizedBox(height: 12),

          // Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Category:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ...categories.map((cat) {
                final isSelected = filter.selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : AppColors.textPrimary)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onSelected: (_) => ref.read(nonOilInventoryFilterProvider.notifier).setSelectedCategory(cat),
                );
              }),

              const SizedBox(width: 8),
              const Text('Stock Level:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              _stockFilterChoice('All', StockFilter.all, filter.stockFilter),
              _stockFilterChoice('In Stock', StockFilter.inStock, filter.stockFilter),
              _stockFilterChoice('Low Stock', StockFilter.lowStock, filter.stockFilter),
              _stockFilterChoice('Out of Stock', StockFilter.outOfStock, filter.stockFilter),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stockFilterChoice(String label, StockFilter filter, StockFilter activeFilter) {
    final isSelected = activeFilter == filter;
    return InkWell(
      onTap: () => ref.read(nonOilInventoryFilterProvider.notifier).setStockFilter(filter),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<ProductModel> products) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'No non-oil products found matching your filters.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.mobileBreakpoint;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: isDesktop ? _buildDesktopTable(context, products) : _buildMobileList(context, products),
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<ProductModel> products) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Product & Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('SKU / Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Available (pcs)', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Cost Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Selling Price', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Total Value', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        const Divider(height: 1),

        // Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final p = products[index];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Product & Category
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${p.category} • Piece unit',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Code
                  Expanded(
                    flex: 2,
                    child: Text(
                      p.productCode,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.secondary),
                    ),
                  ),

                  // Available Stock
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${p.availableQuantity.toInt()} pcs',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: p.isOutOfStock ? AppColors.error : (p.isLowStock ? AppColors.warning : AppColors.textPrimary),
                      ),
                    ),
                  ),

                  // Cost Price
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(p.vendorPricePerUnit),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),

                  // Selling Price
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(p.sellingPricePerUnit),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primaryDark),
                    ),
                  ),

                  // Total Value
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(p.potentialSellingValue),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),

                  // Status
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.isOutOfStock
                              ? AppColors.dangerLight
                              : (p.isLowStock ? AppColors.warningLight : AppColors.cashGreenLight),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.isOutOfStock ? 'OUT OF STOCK' : (p.isLowStock ? 'LOW STOCK' : 'IN STOCK'),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: p.isOutOfStock
                                ? AppColors.danger
                                : (p.isLowStock ? AppColors.warning : AppColors.cashGreen),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Actions
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Stock In
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                          tooltip: 'Stock In / Purchase',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => StockPurchaseDialog(product: p),
                            );
                          },
                        ),
                        // Adjust Stock
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          tooltip: 'Stock Adjustment',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => StockAdjustmentDialog(product: p),
                            );
                          },
                        ),
                        // Stock History
                        IconButton(
                          icon: const Icon(Icons.history_rounded, size: 18),
                          tooltip: 'Stock Movements',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => StockMovementDialog(product: p),
                            );
                          },
                        ),
                        // Edit
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Edit Product',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AddEditProductDialog(
                                product: p,
                                defaultProductType: AppConstants.productTypeNonOil,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMobileList(BuildContext context, List<ProductModel> products) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final p = products[index];

        return ListTile(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => StockMovementDialog(product: p),
            );
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  p.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${p.availableQuantity.toInt()} pcs',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: p.isOutOfStock ? AppColors.error : AppColors.primary,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${p.productCode} • ${p.category}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(
                    CurrencyFormatter.format(p.sellingPricePerUnit),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primaryDark),
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (val) {
              if (val == 'purchase') {
                showDialog(context: context, builder: (ctx) => StockPurchaseDialog(product: p));
              } else if (val == 'adjust') {
                showDialog(context: context, builder: (ctx) => StockAdjustmentDialog(product: p));
              } else if (val == 'edit') {
                showDialog(context: context, builder: (ctx) => AddEditProductDialog(product: p, defaultProductType: AppConstants.productTypeNonOil));
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'purchase', child: Text('Stock In / Purchase')),
              PopupMenuItem(value: 'adjust', child: Text('Adjust Stock')),
              PopupMenuItem(value: 'edit', child: Text('Edit Product')),
            ],
          ),
        );
      },
    );
  }
}
