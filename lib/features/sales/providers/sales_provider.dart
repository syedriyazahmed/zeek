import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/sale_model.dart';
import '../../pos/providers/cart_provider.dart';

final salesListStreamProvider = StreamProvider<List<SaleModel>>((ref) {
  final salesRepo = ref.watch(salesRepositoryProvider);
  return salesRepo.watchSales();
});

class SalesSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setQuery(String q) => state = q;
}

final salesSearchProvider = NotifierProvider<SalesSearchNotifier, String>(() {
  return SalesSearchNotifier();
});

class SalesDateFilterNotifier extends Notifier<String> {
  @override
  String build() => 'today'; // 'today' | 'yesterday' | 'week' | 'month' | 'all'
  void setFilter(String filter) => state = filter;
}

final salesDateFilterProvider = NotifierProvider<SalesDateFilterNotifier, String>(() {
  return SalesDateFilterNotifier();
});

class SalesPaymentFilterNotifier extends Notifier<String> {
  @override
  String build() => ''; // '' = all, 'cash', 'online', 'split'
  void setFilter(String filter) => state = filter;
}

final salesPaymentFilterProvider = NotifierProvider<SalesPaymentFilterNotifier, String>(() {
  return SalesPaymentFilterNotifier();
});

class SalesStatusFilterNotifier extends Notifier<String> {
  @override
  String build() => ''; // '' = all, 'completed', 'cancelled'
  void setFilter(String filter) => state = filter;
}

final salesStatusFilterProvider = NotifierProvider<SalesStatusFilterNotifier, String>(() {
  return SalesStatusFilterNotifier();
});

class SalesMetrics {
  final double totalRevenue;
  final int totalTransactions;
  final double cashRevenue;
  final double onlineRevenue;
  final double averageTicketSize;
  final int cancelledCount;
  final double cancelledAmount;

  const SalesMetrics({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.cashRevenue,
    required this.onlineRevenue,
    required this.averageTicketSize,
    required this.cancelledCount,
    required this.cancelledAmount,
  });
}

final filteredSalesProvider = Provider.autoDispose<List<SaleModel>>((ref) {
  final salesAsync = ref.watch(salesListStreamProvider);
  final sales = salesAsync.value ?? [];

  final searchQuery = ref.watch(salesSearchProvider).trim().toLowerCase();
  final dateFilter = ref.watch(salesDateFilterProvider);
  final paymentFilter = ref.watch(salesPaymentFilterProvider);
  final statusFilter = ref.watch(salesStatusFilterProvider);

  final now = DateTime.now();
  final todayStr = DateFormatter.toIsoDate(now);
  final yesterdayStr = DateFormatter.toIsoDate(now.subtract(const Duration(days: 1)));
  final weekAgo = now.subtract(const Duration(days: 7));
  final monthAgo = now.subtract(const Duration(days: 30));

  return sales.where((s) {
    // 1. Date Filter
    if (dateFilter == 'today' && s.date != todayStr) return false;
    if (dateFilter == 'yesterday' && s.date != yesterdayStr) return false;
    if (dateFilter == 'week' && s.timestamp.isBefore(weekAgo)) return false;
    if (dateFilter == 'month' && s.timestamp.isBefore(monthAgo)) return false;

    // 2. Payment Filter
    if (paymentFilter.isNotEmpty && s.paymentType != paymentFilter) return false;

    // 3. Status Filter
    if (statusFilter.isNotEmpty && s.status != statusFilter) return false;

    // 4. Search Query
    if (searchQuery.isNotEmpty) {
      final invMatch = s.invoiceNumber.toLowerCase().contains(searchQuery);
      final cashierMatch = (s.createdByName ?? s.createdBy).toLowerCase().contains(searchQuery);
      final itemMatch = s.items.any((item) => item.productName.toLowerCase().contains(searchQuery));
      if (!invMatch && !cashierMatch && !itemMatch) return false;
    }

    return true;
  }).toList();
});

final salesMetricsProvider = Provider.autoDispose<SalesMetrics>((ref) {
  final sales = ref.watch(filteredSalesProvider);

  double totalRev = 0.0;
  double cashRev = 0.0;
  double onlineRev = 0.0;
  int completedCount = 0;
  int cancelledCount = 0;
  double cancelledRev = 0.0;

  for (final s in sales) {
    if (s.status == AppConstants.saleStatusCompleted) {
      totalRev += s.grandTotal;
      cashRev += s.cashAmount;
      onlineRev += s.onlineAmount;
      completedCount++;
    } else {
      cancelledCount++;
      cancelledRev += s.grandTotal;
    }
  }

  totalRev = CurrencyFormatter.round(totalRev);
  cashRev = CurrencyFormatter.round(cashRev);
  onlineRev = CurrencyFormatter.round(onlineRev);
  cancelledRev = CurrencyFormatter.round(cancelledRev);

  final avgTicket = completedCount > 0
      ? CurrencyFormatter.round(totalRev / completedCount)
      : 0.0;

  return SalesMetrics(
    totalRevenue: totalRev,
    totalTransactions: completedCount,
    cashRevenue: cashRev,
    onlineRevenue: onlineRev,
    averageTicketSize: avgTicket,
    cancelledCount: cancelledCount,
    cancelledAmount: cancelledRev,
  );
});
