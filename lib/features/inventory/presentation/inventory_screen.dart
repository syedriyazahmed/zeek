import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../services/csv/csv_service.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../vendors/presentation/vendors_screen.dart';
import '../providers/inventory_provider.dart';
import 'widgets/add_edit_product_dialog.dart';
import 'widgets/csv_import_dialog.dart';
import 'widgets/stock_adjustment_dialog.dart';
import 'widgets/stock_movement_dialog.dart';
import 'widgets/stock_purchase_dialog.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv(List<ProductModel> products) {
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available to export.')),
      );
      return;
    }

    final csvString = CsvService.instance.exportProductsToCsv(products);
    Clipboard.setData(ClipboardData(text: csvString));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        content: Text('Exported ${products.length} products to CSV! Copied to clipboard.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(filteredOilProductsProvider);
    final metrics = ref.watch(oilInventoryMetricsProvider);
    final categories = ref.watch(oilCategoriesProvider);
    final filter = ref.watch(oilInventoryFilterProvider);
    final filterNotifier = ref.read(oilInventoryFilterProvider.notifier);

    final user = ref.watch(authStateProvider).asData?.value;
    final isAdmin = user?.isAdmin ?? false;
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.mobileBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oil Inventory (Athar & Perfume Oils)',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage concentrated perfume oils, stock levels, vendors, and inward batches in ml',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VendorsScreen()),
                        );
                      },
                      icon: const Icon(Icons.business_outlined, size: 16),
                      label: const Text('Vendors'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _exportCsv(products),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export CSV'),
                    ),
                    if (isAdmin) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const CsvImportDialog(productType: AppConstants.productTypeOil),
                          );
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: const Text('Import CSV'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const AddEditProductDialog(defaultProductType: AppConstants.productTypeOil),
                          );
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Oil Product'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Summary Cards Grid
            _buildSummaryMetrics(metrics, filter, filterNotifier),
            const SizedBox(height: 24),

            // Filter & Search Controls Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Search Field
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => filterNotifier.setSearchQuery(val),
                            decoration: InputDecoration(
                              hintText: 'Search by product name, code (e.g. OUD-101), or category...',
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        filterNotifier.setSearchQuery('');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Category Dropdown
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: filter.selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Category',
                              prefixIcon: Icon(Icons.category_outlined, size: 20),
                            ),
                            items: categories.map((cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) filterNotifier.setSelectedCategory(val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Stock Status Chips
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterChip('All Products', StockFilter.all, filter.stockFilter, filterNotifier),
                        _buildFilterChip('In Stock', StockFilter.inStock, filter.stockFilter, filterNotifier),
                        _buildFilterChip(
                          'Low Stock (${metrics.lowStockCount})',
                          StockFilter.lowStock,
                          filter.stockFilter,
                          filterNotifier,
                          isWarning: metrics.lowStockCount > 0,
                        ),
                        _buildFilterChip(
                          'Out of Stock (${metrics.outOfStockCount})',
                          StockFilter.outOfStock,
                          filter.stockFilter,
                          filterNotifier,
                          isDanger: metrics.outOfStockCount > 0,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Products Table or Cards
            products.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textMuted.withAlpha(128)),
                          const SizedBox(height: 12),
                          const Text('No products match your filter criteria.', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  )
                : isDesktop
                    ? _buildDesktopTable(context, ref, products, isAdmin)
                    : _buildMobileProductCards(context, ref, products, isAdmin),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetrics(
    InventoryMetrics metrics,
    InventoryFilterState filter,
    InventoryFilterNotifier filterNotifier,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 5
            : (constraints.maxWidth > 700 ? 3 : 2);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.1,
          children: [
            _buildMetricCard(
              title: 'Active Products',
              value: '${metrics.totalProducts}',
              icon: Icons.spa_rounded,
              color: AppColors.secondary,
            ),
            _buildMetricCard(
              title: 'Total Stock Available',
              value: '${metrics.totalAvailableStock} ml',
              icon: Icons.water_drop_rounded,
              color: AppColors.info,
            ),
            _buildMetricCard(
              title: 'Purchase Stock Cost',
              value: CurrencyFormatter.format(metrics.totalPurchaseValue),
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
            ),
            _buildMetricCard(
              title: 'Potential Selling Value',
              value: CurrencyFormatter.format(metrics.potentialSellingValue),
              icon: Icons.sell_outlined,
              color: AppColors.cashGreen,
            ),
            _buildMetricCard(
              title: 'Low / Out of Stock',
              value: '${metrics.lowStockCount} low • ${metrics.outOfStockCount} out',
              icon: Icons.warning_amber_rounded,
              color: (metrics.lowStockCount > 0 || metrics.outOfStockCount > 0)
                  ? AppColors.danger
                  : AppColors.cashGreen,
              onTap: () {
                if (metrics.lowStockCount > 0) {
                  filterNotifier.setStockFilter(StockFilter.lowStock);
                } else if (metrics.outOfStockCount > 0) {
                  filterNotifier.setStockFilter(StockFilter.outOfStock);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    StockFilter filterValue,
    StockFilter activeFilter,
    InventoryFilterNotifier notifier, {
    bool isWarning = false,
    bool isDanger = false,
  }) {
    final isSelected = activeFilter == filterValue;
    Color chipColor = AppColors.primary;
    if (isDanger) chipColor = AppColors.danger;
    if (isWarning && !isDanger) chipColor = AppColors.warning;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: chipColor,
      backgroundColor: AppColors.background,
      onSelected: (_) => notifier.setStockFilter(filterValue),
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    WidgetRef ref,
    List<ProductModel> products,
    bool isAdmin,
  ) {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Product Name / Code', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Available Stock', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Vendor Price', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Stock Valuation', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: products.map((p) {
              return DataRow(
                cells: [
                  // Name & SKU
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('SKU: ${p.productCode}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  // Category
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(p.category, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  // Stock Quantity + Status badge
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.isOutOfStock
                                ? AppColors.danger
                                : (p.isLowStock ? AppColors.warning : AppColors.cashGreen),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${p.availableQuantity} ${p.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: p.isOutOfStock
                                ? AppColors.danger
                                : (p.isLowStock ? AppColors.warning : AppColors.textPrimary),
                          ),
                        ),
                        if (p.isLowStock)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('LOW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.warning)),
                          ),
                        if (p.isOutOfStock)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('OUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.danger)),
                          ),
                      ],
                    ),
                  ),
                  // Selling Price
                  DataCell(Text(CurrencyFormatter.format(p.sellingPricePerUnit), style: const TextStyle(fontWeight: FontWeight.w600))),
                  // Vendor Price
                  DataCell(Text(CurrencyFormatter.format(p.vendorPricePerUnit), style: const TextStyle(color: AppColors.textSecondary))),
                  // Valuation
                  DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(CurrencyFormatter.format(p.potentialSellingValue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Cost: ${CurrencyFormatter.format(p.currentStockCost)}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  // Actions
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Stock Purchase (Inward)
                        IconButton(
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 18, color: AppColors.cashGreen),
                          tooltip: 'Record Stock In / Purchase',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => StockPurchaseDialog(product: p),
                            );
                          },
                        ),
                        // Stock Movement History
                        IconButton(
                          icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.info),
                          tooltip: 'View Stock Movement History',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => StockMovementDialog(product: p),
                            );
                          },
                        ),
                        if (isAdmin) ...[
                          // Stock Adjustment
                          IconButton(
                            icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.warning),
                            tooltip: 'Physical Stock Adjustment',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => StockAdjustmentDialog(product: p),
                              );
                            },
                          ),
                          // Edit
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                            tooltip: 'Edit Product',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AddEditProductDialog(product: p),
                              );
                            },
                          ),
                          // Archive
                          IconButton(
                            icon: const Icon(Icons.archive_outlined, size: 18, color: AppColors.textMuted),
                            tooltip: 'Archive Product',
                            onPressed: () => _confirmArchiveProduct(context, ref, p),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileProductCards(
    BuildContext context,
    WidgetRef ref,
    List<ProductModel> products,
    bool isAdmin,
  ) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('SKU: ${p.productCode} • ${p.category}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${p.availableQuantity} ${p.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: p.isOutOfStock
                                ? AppColors.danger
                                : (p.isLowStock ? AppColors.warning : AppColors.cashGreen),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(p.sellingPricePerUnit),
                          style: const TextStyle(fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.add_shopping_cart, size: 16, color: AppColors.cashGreen),
                      label: const Text('Stock In', style: TextStyle(fontSize: 12, color: AppColors.cashGreen)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => StockPurchaseDialog(product: p),
                        );
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('History', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => StockMovementDialog(product: p),
                        );
                      },
                    ),
                    if (isAdmin)
                      TextButton.icon(
                        icon: const Icon(Icons.tune, size: 16, color: AppColors.warning),
                        label: const Text('Adjust', style: TextStyle(fontSize: 12, color: AppColors.warning)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => StockAdjustmentDialog(product: p),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmArchiveProduct(BuildContext context, WidgetRef ref, ProductModel product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Product?'),
        content: Text(
          'Are you sure you want to archive "${product.productName}"?\n\nIt will be hidden from new POS sales searches, but will be preserved in historical sales, stock reports, and accounts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(inventoryRepositoryProvider).archiveProduct(product.productId, true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Product "${product.productName}" archived.')),
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}
