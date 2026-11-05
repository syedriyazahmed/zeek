import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../services/csv/csv_service.dart';
import '../providers/stock_sold_provider.dart';
import 'widgets/product_sales_drill_down_dialog.dart';

class StockSoldScreen extends ConsumerStatefulWidget {
  const StockSoldScreen({super.key});

  @override
  ConsumerState<StockSoldScreen> createState() => _StockSoldScreenState();
}

class _StockSoldScreenState extends ConsumerState<StockSoldScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv(List<ProductSaleAggregate> items) {
    final csv = CsvService.instance.exportStockSoldToCsv(items.map((i) => i.toMap()).toList());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Stock Sold CSV'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total ${items.length} products exported with sales, COGS, and profit margin details.'),
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
    final aggregates = ref.watch(stockSoldAggregatesProvider);
    final summary = ref.watch(stockSoldSummaryProvider);
    final dateFilter = ref.watch(stockSoldDateFilterProvider);
    final typeFilter = ref.watch(stockSoldTypeFilterProvider);
    final sortOrder = ref.watch(stockSoldSortProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Actions
            _buildHeader(context, aggregates),

            const SizedBox(height: 16),

            // Summary Metric Cards
            _buildSummaryCards(summary),

            const SizedBox(height: 16),

            // Filter Toolbar
            _buildFilterToolbar(dateFilter, typeFilter, sortOrder),

            const SizedBox(height: 16),

            // Aggregates Table / List
            _buildAggregatesList(context, aggregates),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<ProductSaleAggregate> items) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stock Sold & Product Performance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Track product-level sales volume, realized gross profit, and profit margin %',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _exportCsv(items),
          icon: const Icon(Icons.download_rounded, size: 16),
          label: const Text('Export CSV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(StockSoldOverallSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final cardWidth = isWide ? (constraints.maxWidth - (5 * 12)) / 6 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(
              title: 'Total Quantity Sold',
              value: '${summary.totalQuantitySold}',
              subtitle: 'Units / ml dispensed',
              icon: Icons.inventory_2_outlined,
              color: AppColors.secondary,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Total Sales Revenue',
              value: CurrencyFormatter.format(summary.totalRevenue),
              subtitle: 'Gross sales realized',
              icon: Icons.payments_rounded,
              color: AppColors.primary,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Cost of Goods (COGS)',
              value: CurrencyFormatter.format(summary.totalCogs),
              subtitle: 'Purchase cost of sold items',
              icon: Icons.price_check_rounded,
              color: AppColors.textSecondary,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Realized Gross Profit',
              value: CurrencyFormatter.format(summary.totalGrossProfit),
              subtitle: 'Revenue minus COGS',
              icon: Icons.savings_rounded,
              color: AppColors.cashGreen,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Blended Gross Margin',
              value: '${summary.overallMarginPercent}%',
              subtitle: 'Profit margin %',
              icon: Icons.pie_chart_outline_rounded,
              color: AppColors.primaryDark,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Top Seller',
              value: summary.topSellerName,
              subtitle: 'Highest quantity sold',
              icon: Icons.star_rounded,
              color: AppColors.warning,
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
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

  Widget _buildFilterToolbar(String dateFilter, String typeFilter, String sortOrder) {
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
              hintText: 'Search product by name, SKU or category...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(stockSoldSearchProvider.notifier).setQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => ref.read(stockSoldSearchProvider.notifier).setQuery(val),
          ),
          const SizedBox(height: 12),

          // Filters Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Period:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              _filterChoice('All Time', 'all', dateFilter, (v) => ref.read(stockSoldDateFilterProvider.notifier).setFilter(v)),
              _filterChoice('Today', 'today', dateFilter, (v) => ref.read(stockSoldDateFilterProvider.notifier).setFilter(v)),
              _filterChoice('Yesterday', 'yesterday', dateFilter, (v) => ref.read(stockSoldDateFilterProvider.notifier).setFilter(v)),
              _filterChoice('7 Days', 'week', dateFilter, (v) => ref.read(stockSoldDateFilterProvider.notifier).setFilter(v)),
              _filterChoice('30 Days', 'month', dateFilter, (v) => ref.read(stockSoldDateFilterProvider.notifier).setFilter(v)),

              const SizedBox(width: 8),
              const Text('Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              _filterChoice('All', '', typeFilter, (v) => ref.read(stockSoldTypeFilterProvider.notifier).setFilter(v)),
              _filterChoice('Oil (ml)', AppConstants.productTypeOil, typeFilter, (v) => ref.read(stockSoldTypeFilterProvider.notifier).setFilter(v)),
              _filterChoice('Non-Oil (Piece)', AppConstants.productTypeNonOil, typeFilter, (v) => ref.read(stockSoldTypeFilterProvider.notifier).setFilter(v)),

              const SizedBox(width: 8),
              const Text('Sort By:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              _sortDropdown(sortOrder),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChoice(String label, String value, String activeValue, Function(String) onSelect) {
    final isSelected = activeValue == value;
    return InkWell(
      onTap: () => onSelect(value),
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

  Widget _sortDropdown(String currentSort) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<String>(
        value: currentSort,
        underline: const SizedBox.shrink(),
        isDense: true,
        style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
        items: const [
          DropdownMenuItem(value: 'qty_desc', child: Text('Quantity Sold (High to Low)')),
          DropdownMenuItem(value: 'rev_desc', child: Text('Revenue (High to Low)')),
          DropdownMenuItem(value: 'profit_desc', child: Text('Gross Profit (High to Low)')),
          DropdownMenuItem(value: 'margin_desc', child: Text('Margin % (High to Low)')),
        ],
        onChanged: (val) {
          if (val != null) ref.read(stockSoldSortProvider.notifier).setSort(val);
        },
      ),
    );
  }

  Widget _buildAggregatesList(BuildContext context, List<ProductSaleAggregate> items) {
    if (items.isEmpty) {
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
                'No products match the selected filters or search query.',
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
      child: isDesktop ? _buildDesktopTable(context, items) : _buildMobileList(context, items),
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<ProductSaleAggregate> items) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Product & Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Code / SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Sold Qty', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('In Stock', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Revenue', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('COGS', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Gross Profit', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Margin %', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text('History', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        const Divider(height: 1),

        // Table Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final a = items[index];

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
                          a.productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${a.category} • ${a.productType}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Code
                  Expanded(
                    flex: 2,
                    child: Text(
                      a.productCode,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppColors.secondary),
                    ),
                  ),

                  // Sold Qty
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${a.soldQuantity} ${a.unit}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: a.soldQuantity > 0 ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                  ),

                  // In Stock
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${a.availableQuantity} ${a.unit}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),

                  // Revenue
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(a.totalRevenue),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),

                  // COGS
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(a.totalCogs),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),

                  // Gross Profit
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(a.grossProfit),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.cashGreen),
                    ),
                  ),

                  // Margin %
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: a.marginPercent >= 50
                              ? AppColors.cashGreen.withValues(alpha: 0.1)
                              : (a.marginPercent > 0 ? Colors.amber.withValues(alpha: 0.15) : AppColors.borderLight),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${a.marginPercent}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: a.marginPercent >= 50
                                ? AppColors.cashGreen
                                : (a.marginPercent > 0 ? Colors.amber.shade900 : AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Action
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(Icons.history_rounded, size: 18),
                        tooltip: 'View Sales History (${a.occurrences.length})',
                        onPressed: () => _openDrillDown(context, a),
                      ),
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

  Widget _buildMobileList(BuildContext context, List<ProductSaleAggregate> items) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final a = items[index];

        return ListTile(
          onTap: () => _openDrillDown(context, a),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  a.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                CurrencyFormatter.format(a.totalRevenue),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
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
                  Text('Sold: ${a.soldQuantity} ${a.unit} • In Stock: ${a.availableQuantity} ${a.unit}', style: const TextStyle(fontSize: 11)),
                  Text(
                    'Profit: ${CurrencyFormatter.format(a.grossProfit)} (${a.marginPercent}%)',
                    style: const TextStyle(fontSize: 11, color: AppColors.cashGreen, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        );
      },
    );
  }

  void _openDrillDown(BuildContext context, ProductSaleAggregate aggregate) {
    showDialog(
      context: context,
      builder: (ctx) => ProductSalesDrillDownDialog(aggregate: aggregate),
    );
  }
}
