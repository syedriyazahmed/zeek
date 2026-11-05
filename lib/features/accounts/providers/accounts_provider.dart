import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/account_entry_model.dart';
import '../../../data/models/daily_summary_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/accounts_repository.dart';
import '../../authentication/providers/auth_provider.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return FirebaseAccountsRepository(firebaseService);
});

class SelectedDateNotifier extends Notifier<String> {
  @override
  String build() {
    return DateFormatter.toIsoDate(DateTime.now());
  }

  void setDate(String date) {
    state = date;
  }
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, String>(() {
  return SelectedDateNotifier();
});

class AccountFilterNotifier extends Notifier<String> {
  @override
  String build() {
    return ''; // empty = all types
  }

  void setFilter(String filter) {
    state = filter;
  }
}

final accountFilterProvider = NotifierProvider<AccountFilterNotifier, String>(() {
  return AccountFilterNotifier();
});

final dailySummaryProvider = StreamProvider.autoDispose<DailySummaryModel?>((ref) {
  final repo = ref.watch(accountsRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  return repo.watchDailySummary(date);
});

final accountEntriesProvider = StreamProvider.autoDispose<List<AccountEntryModel>>((ref) {
  final repo = ref.watch(accountsRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  final filterType = ref.watch(accountFilterProvider);
  return repo.watchAccountEntries(
    date: date,
    transactionType: filterType.isEmpty ? null : filterType,
  );
});

final expensesProvider = StreamProvider.autoDispose<List<ExpenseModel>>((ref) {
  final repo = ref.watch(accountsRepositoryProvider);
  final date = ref.watch(selectedDateProvider);
  return repo.watchExpenses(date: date);
});
