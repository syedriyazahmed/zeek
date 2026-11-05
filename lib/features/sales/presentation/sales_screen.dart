import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/sale_model.dart';
import '../../../services/csv/csv_service.dart';
import '../../../services/invoice/invoice_service.dart';
import '../providers/sales_provider.dart';
import 'widgets/sale_details_dialog.dart';
import 'widgets/sales_trend_chart.dart';

class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
  final _searchController = TextEditingController();
  bool _showChart = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportCsv(List<SaleModel> sales) {
    final csv = CsvService.instance.exportSalesToCsv(sales);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Sales CSV'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total ${sales.length} transactions exported in standard CSV format.'),
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
    final allSalesAsync = ref.watch(salesListStreamProvider);
    final filteredSales = ref.watch(filteredSalesProvider);
    final metrics = ref.watch(salesMetricsProvider);
    final dateFilter = ref.watch(salesDateFilterProvider);
    final paymentFilter = ref.watch(salesPaymentFilterProvider);
    final statusFilter = ref.watch(salesStatusFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header & Actions
            _buildHeader(context, filteredSales),

            const SizedBox(height: 16),

            // Summary Metric Cards
            _buildSummaryCards(metrics),

            const SizedBox(height: 16),

            // Trend Chart (if enabled)
            if (_showChart) ...[
              SalesTrendChart(sales: allSalesAsync.value ?? []),
              const SizedBox(height: 16),
            ],

            // Filter & Search Toolbar
            _buildFilterToolbar(dateFilter, paymentFilter, statusFilter),

            const SizedBox(height: 16),

            // Sales Data List / Table
            _buildSalesList(context, filteredSales, allSalesAsync.isLoading),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<SaleModel> sales) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 28),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sales History & Invoices',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Search, inspect, reprint invoices and monitor daily transaction volumes',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () => setState(() => _showChart = !_showChart),
              icon: Icon(_showChart ? Icons.bar_chart_rounded : Icons.show_chart_rounded, size: 16),
              label: Text(_showChart ? 'Hide Trend' : 'Show Trend'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _exportCsv(sales),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Export CSV'),
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

  Widget _buildSummaryCards(SalesMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final cardWidth = isWide ? (constraints.maxWidth - (5 * 12)) / 6 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(
              title: 'Total Sales Revenue',
              value: CurrencyFormatter.format(metrics.totalRevenue),
              subtitle: '${metrics.totalTransactions} bills settled',
              icon: Icons.payments_rounded,
              color: AppColors.primary,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Total Transactions',
              value: '${metrics.totalTransactions}',
              subtitle: 'Settled customer orders',
              icon: Icons.shopping_bag_outlined,
              color: AppColors.secondary,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Cash Sales',
              value: CurrencyFormatter.format(metrics.cashRevenue),
              subtitle: 'Cash in drawer',
              icon: Icons.money_rounded,
              color: AppColors.cashGreen,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Online Sales',
              value: CurrencyFormatter.format(metrics.onlineRevenue),
              subtitle: 'UPI / Card payments',
              icon: Icons.credit_card_rounded,
              color: AppColors.onlineBlue,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Avg Order Value',
              value: CurrencyFormatter.format(metrics.averageTicketSize),
              subtitle: 'Average bill size',
              icon: Icons.analytics_rounded,
              color: Colors.teal,
              width: cardWidth,
            ),
            _metricCard(
              title: 'Cancelled Orders',
              value: '${metrics.cancelledCount}',
              subtitle: CurrencyFormatter.format(metrics.cancelledAmount),
              icon: Icons.cancel_outlined,
              color: metrics.cancelledCount > 0 ? AppColors.error : AppColors.textSecondary,
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

  Widget _buildFilterToolbar(String dateFilter, String paymentFilter, String statusFilter) {
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
              hintText: 'Search by Invoice #, Product name, or Cashier...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(salesSearchProvider.notifier).setQuery('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (val) => ref.read(salesSearchProvider.notifier).setQuery(val),
          ),
          const SizedBox(height: 12),

          // Filters Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Period:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              _filterChoice('Today', 'today', dateFilter, (v) => ref.read(salesDateFilterProvider.notifier).setFilter(v)),
              _filterChoice('Yesterday', 'yesterday', dateFilter, (v) => ref.read(salesDateFilterProvider.notifier).setFilter(v)),
              _filterChoice('7 Days', 'week', dateFilter, (v) => ref.read(salesDateFilterProvider.notifier).setFilter(v)),
              _filterChoice('30 Days', 'month', dateFilter, (v) => ref.read(salesDateFilterProvider.notifier).setFilter(v)),
              _filterChoice('All Time', 'all', dateFilter, (v) => ref.read(salesDateFilterProvider.notifier).setFilter(v)),

              const SizedBox(width: 8),
              const Text('Payment:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              _filterChoice('All', '', paymentFilter, (v) => ref.read(salesPaymentFilterProvider.notifier).setFilter(v)),
              _filterChoice('Cash', AppConstants.paymentCash, paymentFilter, (v) => ref.read(salesPaymentFilterProvider.notifier).setFilter(v)),
              _filterChoice('Online', AppConstants.paymentOnline, paymentFilter, (v) => ref.read(salesPaymentFilterProvider.notifier).setFilter(v)),
              _filterChoice('Split', AppConstants.paymentSplit, paymentFilter, (v) => ref.read(salesPaymentFilterProvider.notifier).setFilter(v)),

              const SizedBox(width: 8),
              const Text('Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              _filterChoice('All', '', statusFilter, (v) => ref.read(salesStatusFilterProvider.notifier).setFilter(v)),
              _filterChoice('Completed', AppConstants.saleStatusCompleted, statusFilter, (v) => ref.read(salesStatusFilterProvider.notifier).setFilter(v)),
              _filterChoice('Cancelled', AppConstants.saleStatusCancelled, statusFilter, (v) => ref.read(salesStatusFilterProvider.notifier).setFilter(v)),
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

  Widget _buildSalesList(BuildContext context, List<SaleModel> sales, bool isLoading) {
    if (isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    if (sales.isEmpty) {
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
              Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'No transactions found for the selected period or filter.',
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
      child: isDesktop ? _buildDesktopTable(context, sales) : _buildMobileList(context, sales),
    );
  }

  Widget _buildDesktopTable(BuildContext context, List<SaleModel> sales) {
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
              Expanded(flex: 2, child: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 3, child: Text('Items Sold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Cashier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Grand Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 1, child: Text('Status', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('Actions', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
          ),
        ),
        const Divider(height: 1),

        // Table Rows
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sales.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final s = sales[index];
            final itemsSummary = s.items.map((i) => '${i.productName} (${i.quantity}${i.unit})').join(', ');

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Invoice #
                  Expanded(
                    flex: 2,
                    child: Text(
                      '#${s.invoiceNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.secondary),
                    ),
                  ),

                  // Date & Time
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        Text(
                          DateFormatter.formatTime(s.timestamp),
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  // Items Summary
                  Expanded(
                    flex: 3,
                    child: Text(
                      itemsSummary.isNotEmpty ? itemsSummary : 'Direct Bill',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Payment Mode
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: s.paymentType == AppConstants.paymentSplit
                                ? AppColors.splitPurple.withValues(alpha: 0.1)
                                : (s.paymentType == AppConstants.paymentCash
                                    ? AppColors.cashGreen.withValues(alpha: 0.1)
                                    : AppColors.onlineBlue.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            s.paymentType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: s.paymentType == AppConstants.paymentSplit
                                  ? AppColors.splitPurple
                                  : (s.paymentType == AppConstants.paymentCash
                                      ? AppColors.cashGreen
                                      : AppColors.onlineBlue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cashier
                  Expanded(
                    flex: 2,
                    child: Text(
                      s.createdByName ?? s.createdBy,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),

                  // Grand Total
                  Expanded(
                    flex: 2,
                    child: Text(
                      CurrencyFormatter.format(s.grandTotal),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: s.isCancelled ? AppColors.textMuted : AppColors.primaryDark,
                        decoration: s.isCancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),

                  // Status
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Icon(
                        s.isCancelled ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: s.isCancelled ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ),

                  // Actions
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          tooltip: 'View Details',
                          onPressed: () => _openDetailsDialog(context, s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 18),
                          tooltip: 'Reprint Invoice',
                          onPressed: () => InvoiceService.instance.printInvoice(s),
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

  Widget _buildMobileList(BuildContext context, List<SaleModel> sales) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sales.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final s = sales[index];
        final itemsSummary = s.items.map((i) => '${i.productName} (${i.quantity}${i.unit})').join(', ');

        return ListTile(
          onTap: () => _openDetailsDialog(context, s),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#${s.invoiceNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              Text(
                CurrencyFormatter.format(s.grandTotal),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: s.isCancelled ? AppColors.textMuted : AppColors.primaryDark,
                  decoration: s.isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                itemsSummary.isNotEmpty ? itemsSummary : 'Items direct sale',
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${s.date} ${DateFormatter.formatTime(s.timestamp)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.paymentType.toUpperCase(),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                    ),
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

  void _openDetailsDialog(BuildContext context, SaleModel sale) {
    showDialog(
      context: context,
      builder: (ctx) => SaleDetailsDialog(sale: sale),
    );
  }
}
