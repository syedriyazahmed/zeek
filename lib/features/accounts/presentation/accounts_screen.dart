import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/account_entry_model.dart';
import '../../../data/models/daily_summary_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../services/csv/csv_service.dart';
import '../providers/accounts_provider.dart';
import 'widgets/add_expense_dialog.dart';
import 'widgets/cash_to_bank_dialog.dart';
import 'widgets/set_opening_balance_dialog.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isReconciling = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _changeDateBy(int days) {
    final currentStr = ref.read(selectedDateProvider);
    final curDate = DateTime.tryParse(currentStr) ?? DateTime.now();
    final newDate = curDate.add(Duration(days: days));
    if (newDate.isAfter(DateTime.now())) return; // Don't navigate to future
    ref.read(selectedDateProvider.notifier).setDate(DateFormatter.toIsoDate(newDate));
  }

  Future<void> _pickDate() async {
    final currentStr = ref.read(selectedDateProvider);
    final curDate = DateTime.tryParse(currentStr) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: curDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ref.read(selectedDateProvider.notifier).setDate(DateFormatter.toIsoDate(picked));
    }
  }

  Future<void> _recalculateAudit() async {
    final date = ref.read(selectedDateProvider);
    setState(() => _isReconciling = true);
    try {
      final repo = ref.read(accountsRepositoryProvider);
      await repo.recalculateDailySummary(date);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audit reconciliation completed for $date. Balances updated.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isReconciling = false);
    }
  }

  void _exportLedger(List<AccountEntryModel> entries) {
    final csv = CsvService.instance.exportAccountLedgerToCsv(entries);
    final date = ref.read(selectedDateProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Export Ledger CSV ($date)'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total ${entries.length} entries exported in standard CSV format.'),
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
    final date = ref.watch(selectedDateProvider);
    final summaryAsync = ref.watch(dailySummaryProvider);
    final entriesAsync = ref.watch(accountEntriesProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final filterType = ref.watch(accountFilterProvider);

    final isToday = date == DateFormatter.toIsoDate(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Date Navigation
            _buildHeader(context, date, isToday, entriesAsync.value ?? []),

            const SizedBox(height: 18),

            // Summary Metric Cards
            summaryAsync.when(
              data: (summary) => _buildSummaryCards(summary ?? DailySummaryModel(date: date)),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (e, _) => Text('Error loading summary: $e', style: const TextStyle(color: AppColors.error)),
            ),

            const SizedBox(height: 24),

            // Tabs Header
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    text: 'Account Ledger (${entriesAsync.value?.length ?? 0})',
                  ),
                  Tab(
                    icon: const Icon(Icons.money_off_rounded, size: 18),
                    text: 'Expenses Log (${expensesAsync.value?.length ?? 0})',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Content
            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Account Ledger
                  _buildLedgerTab(entriesAsync, filterType),

                  // Tab 2: Expenses Log
                  _buildExpensesTab(expensesAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String date,
    bool isToday,
    List<AccountEntryModel> entries,
  ) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        // Title & Date Selector
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accounts & Daily Balances',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  isToday ? 'Today ($date)' : 'Historical Log: $date',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(width: 16),

            // Date Nav buttons
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    tooltip: 'Previous Day',
                    onPressed: () => _changeDateBy(-1),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  InkWell(
                    onTap: _pickDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(date, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    tooltip: 'Next Day',
                    onPressed: isToday ? null : () => _changeDateBy(1),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                  if (!isToday) ...[
                    const VerticalDivider(width: 1),
                    TextButton(
                      onPressed: () => ref.read(selectedDateProvider.notifier).setDate(DateFormatter.toIsoDate(DateTime.now())),
                      child: const Text('Today', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        // Action Buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Reconcile Audit Button
            OutlinedButton.icon(
              onPressed: _isReconciling ? null : _recalculateAudit,
              icon: _isReconciling
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded, size: 16),
              label: const Text('Reconcile Audit'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),

            // Set Opening Float
            OutlinedButton.icon(
              onPressed: () async {
                final summary = await ref.read(accountsRepositoryProvider).getDailySummary(date);
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => SetOpeningBalanceDialog(
                      date: date,
                      currentCashOpening: summary.cashOpeningBalance,
                      currentOnlineOpening: summary.onlineOpeningBalance,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Opening Float'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),

            // Cash to Bank Deposit
            ElevatedButton.icon(
              onPressed: () async {
                final summary = await ref.read(accountsRepositoryProvider).getDailySummary(date);
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx) => CashToBankTransferDialog(
                      currentCashInHand: summary.closingCashBalance,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.account_balance_rounded, size: 16),
              label: const Text('Bank Deposit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),

            // Record Expense Button
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => const AddExpenseDialog(),
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Record Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),

            // Export CSV
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Export CSV',
              onPressed: () => _exportLedger(entries),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCards(DailySummaryModel summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final cardWidth = isWide ? (constraints.maxWidth - (5 * 12)) / 6 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            // 1. Cash In Hand
            _metricCard(
              title: 'Cash In Hand',
              value: CurrencyFormatter.format(summary.closingCashBalance),
              subtitle: 'Opening: ${CurrencyFormatter.format(summary.cashOpeningBalance)}',
              icon: Icons.money_rounded,
              color: AppColors.primary,
              width: cardWidth,
            ),
            // 2. Bank / Online Balance
            _metricCard(
              title: 'Bank / Online Balance',
              value: CurrencyFormatter.format(summary.closingOnlineBalance),
              subtitle: 'Opening: ${CurrencyFormatter.format(summary.onlineOpeningBalance)}',
              icon: Icons.account_balance_rounded,
              color: AppColors.secondary,
              width: cardWidth,
            ),
            // 3. Today's Sales Income
            _metricCard(
              title: "Today's Sales Income",
              value: CurrencyFormatter.format(summary.totalSales),
              subtitle: 'Cash: ${CurrencyFormatter.format(summary.cashSales)} | Online: ${CurrencyFormatter.format(summary.onlineSales)}',
              icon: Icons.point_of_sale_rounded,
              color: AppColors.success,
              width: cardWidth,
            ),
            // 4. Today's Expenses
            _metricCard(
              title: "Today's Expenses",
              value: CurrencyFormatter.format(summary.totalExpenses),
              subtitle: 'Cash: ${CurrencyFormatter.format(summary.cashExpenses)} | Online: ${CurrencyFormatter.format(summary.onlineExpenses)}',
              icon: Icons.money_off_rounded,
              color: AppColors.error,
              width: cardWidth,
            ),
            // 5. Cash-to-Bank Transfers
            _metricCard(
              title: 'Cash-to-Bank Deposited',
              value: CurrencyFormatter.format(summary.cashToBankTransfers),
              subtitle: 'Deducted from cash float',
              icon: Icons.swap_horiz_rounded,
              color: Colors.blueGrey,
              width: cardWidth,
            ),
            // 6. Total Store Balance
            _metricCard(
              title: 'Total Store Closing',
              value: CurrencyFormatter.format(summary.grandClosingBalance),
              subtitle: 'Cash + Bank Combined',
              icon: Icons.savings_rounded,
              color: AppColors.accent,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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

  Widget _buildLedgerTab(AsyncValue<List<AccountEntryModel>> entriesAsync, String filterType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _filterChip('All Types', '', filterType),
              const SizedBox(width: 8),
              _filterChip('Sales Income', AppConstants.entrySaleIncome, filterType),
              const SizedBox(width: 8),
              _filterChip('Expenses', AppConstants.entryExpense, filterType),
              const SizedBox(width: 8),
              _filterChip('Transfers', AppConstants.entryTransfer, filterType),
              const SizedBox(width: 8),
              _filterChip('Opening Balances', AppConstants.entryOpeningBalance, filterType),
              const SizedBox(width: 8),
              _filterChip('Refunds', AppConstants.entryRefund, filterType),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Entries List/Table
        Expanded(
          child: entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 48, color: AppColors.textSecondary),
                      SizedBox(height: 12),
                      Text('No ledger entries recorded for this date/filter.', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    return _buildEntryRow(e);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String type, String currentFilter) {
    final isSelected = currentFilter == type;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      onSelected: (_) => ref.read(accountFilterProvider.notifier).setFilter(type),
    );
  }

  Widget _buildEntryRow(AccountEntryModel e) {
    Color typeColor = AppColors.primary;
    IconData typeIcon = Icons.swap_horiz_rounded;

    if (e.transactionType == AppConstants.entrySaleIncome) {
      typeColor = AppColors.success;
      typeIcon = Icons.point_of_sale_rounded;
    } else if (e.transactionType == AppConstants.entryExpense) {
      typeColor = AppColors.error;
      typeIcon = Icons.money_off_rounded;
    } else if (e.transactionType == AppConstants.entryTransfer) {
      typeColor = Colors.blue;
      typeIcon = Icons.account_balance_rounded;
    } else if (e.transactionType == AppConstants.entryOpeningBalance) {
      typeColor = AppColors.secondary;
      typeIcon = Icons.tune_rounded;
    } else if (e.transactionType == AppConstants.entryRefund) {
      typeColor = Colors.purple;
      typeIcon = Icons.undo_rounded;
    }

    final isExpense = e.transactionType == AppConstants.entryExpense;
    final isRefund = e.transactionType == AppConstants.entryRefund;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          const SizedBox(width: 14),

          // Description & Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.description,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        e.transactionType.replaceAll('_', ' '),
                        style: TextStyle(color: typeColor, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormatter.formatTime(e.createdAt),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'By: ${e.createdBy}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cash & Online Breakdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense || isRefund ? '-' : ''}${CurrencyFormatter.format(e.totalAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isExpense || isRefund ? AppColors.error : (e.transactionType == AppConstants.entrySaleIncome ? AppColors.success : AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Cash: ${CurrencyFormatter.format(e.cashAmount)} | Online: ${CurrencyFormatter.format(e.onlineAmount)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(AsyncValue<List<ExpenseModel>> expensesAsync) {
    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.money_off_rounded, size: 48, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text('No expenses recorded for this date.', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            itemCount: expenses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final exp = expenses[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(exp.reason, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  exp.category,
                                  style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          if (exp.description != null && exp.description!.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              exp.description!,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                          const SizedBox(height: 3),
                          Text(
                            'Paid via ${exp.paymentMethod.toUpperCase()} • Recorded by ${exp.createdBy}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '- ${CurrencyFormatter.format(exp.totalAmount)}',
                          style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (exp.paymentMethod == AppConstants.paymentSplit)
                          Text(
                            'Cash: ${CurrencyFormatter.format(exp.cashAmount)} | Online: ${CurrencyFormatter.format(exp.onlineAmount)}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
