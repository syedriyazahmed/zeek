import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/firebase/firebase_service.dart';
import '../models/account_entry_model.dart';
import '../models/daily_summary_model.dart';
import '../models/expense_model.dart';

abstract class AccountsRepository {
  Stream<List<AccountEntryModel>> watchAccountEntries({String? date, String? transactionType});
  Future<List<AccountEntryModel>> getAccountEntries({String? date, String? transactionType});

  Stream<List<ExpenseModel>> watchExpenses({String? date, String? category});
  Future<List<ExpenseModel>> getExpenses({String? date, String? category});
  Future<void> addExpense(ExpenseModel expense);

  Stream<DailySummaryModel?> watchDailySummary(String date);
  Future<DailySummaryModel> getDailySummary(String date);
  Future<void> setOpeningBalance({
    required String date,
    required double cashOpening,
    required double onlineOpening,
    required String userId,
  });

  Future<void> recordCashToBankTransfer({
    required double amount,
    required String notes,
    required String userId,
    String? date,
  });

  Future<void> recordSaleIncome({
    required AccountEntryModel entry,
    required double cashAmount,
    required double onlineAmount,
    required double grandTotal,
    required String date,
  });

  Future<void> recordSaleCancellation({
    required String saleId,
    required String invoiceNumber,
    required double cashAmount,
    required double onlineAmount,
    required double grandTotal,
    required String date,
    required String userId,
    required String reason,
  });

  Future<DailySummaryModel> recalculateDailySummary(String date);
}

class FirebaseAccountsRepository implements AccountsRepository {
  final FirebaseService _firebaseService;
  final String _shopId;

  // Local state cache
  final List<AccountEntryModel> _localEntries = [];
  final List<ExpenseModel> _localExpenses = [];
  final Map<String, DailySummaryModel> _localDailySummaries = {};

  final _entriesController = StreamController<List<AccountEntryModel>>.broadcast();
  final _expensesController = StreamController<List<ExpenseModel>>.broadcast();
  final _summariesController = StreamController<Map<String, DailySummaryModel>>.broadcast();

  FirebaseAccountsRepository(
    this._firebaseService, {
    String shopId = AppConstants.defaultShopId,
  }) : _shopId = shopId {
    _initDemoAccounts();
  }

  void _initDemoAccounts() {
    if (_localEntries.isEmpty) {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final yesterdayStr = now.subtract(const Duration(days: 1)).toIso8601String().split('T')[0];

      // Yesterday Summary
      _localDailySummaries[yesterdayStr] = DailySummaryModel(
        date: yesterdayStr,
        cashSales: 1500.0,
        onlineSales: 2000.0,
        totalSales: 3500.0,
        totalTransactions: 5,
        cashExpenses: 300.0,
        onlineExpenses: 500.0,
        totalExpenses: 800.0,
        cashOpeningBalance: 1500.0,
        onlineOpeningBalance: 8500.0,
        cashToBankTransfers: 700.0,
        closingCashBalance: 2000.0, // 1500 + 1500 - 300 - 700 = 2000
        closingOnlineBalance: 10000.0, // 8500 + 2000 - 500 + 700 = 10700 -> set 10000
      );

      // Today Initial Entries
      _localEntries.addAll([
        AccountEntryModel(
          entryId: 'entry_sale_001',
          date: todayStr,
          transactionType: AppConstants.entrySaleIncome,
          referenceId: 'sale_init_001',
          cashAmount: 500.0,
          onlineAmount: 0.0,
          description: 'POS Sale #INV-100234 (Cash)',
          createdBy: 'emp_01',
          createdAt: now.subtract(const Duration(hours: 4)),
        ),
        AccountEntryModel(
          entryId: 'entry_sale_002',
          date: todayStr,
          transactionType: AppConstants.entrySaleIncome,
          referenceId: 'sale_init_002',
          cashAmount: 450.0,
          onlineAmount: 500.0,
          description: 'POS Sale #INV-100235 (Split)',
          createdBy: 'emp_02',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        AccountEntryModel(
          entryId: 'entry_exp_001',
          date: todayStr,
          transactionType: AppConstants.entryExpense,
          referenceId: 'exp_001',
          cashAmount: 300.0,
          onlineAmount: 0.0,
          description: 'Expense: Packaging & Athar Gift Bags',
          createdBy: 'admin_01',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        AccountEntryModel(
          entryId: 'entry_exp_002',
          date: todayStr,
          transactionType: AppConstants.entryExpense,
          referenceId: 'exp_002',
          cashAmount: 100.0,
          onlineAmount: 0.0,
          description: 'Expense: Daily Staff Tea & Refreshments',
          createdBy: 'emp_01',
          createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
        ),
        AccountEntryModel(
          entryId: 'entry_trf_001',
          date: todayStr,
          transactionType: AppConstants.entryTransfer,
          referenceId: 'trf_001',
          cashAmount: -500.0,
          onlineAmount: 500.0,
          description: 'Cash to Bank Deposit (HDFC Current A/c)',
          createdBy: 'admin_01',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ]);

      _localExpenses.addAll([
        ExpenseModel(
          expenseId: 'exp_001',
          date: todayStr,
          reason: 'Packaging Materials',
          category: 'Packaging',
          totalAmount: 300.0,
          paymentMethod: AppConstants.paymentCash,
          cashAmount: 300.0,
          onlineAmount: 0.0,
          description: 'Purchased 100 velvet gift pouches for bottles',
          createdBy: 'admin_01',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
        ExpenseModel(
          expenseId: 'exp_002',
          date: todayStr,
          reason: 'Staff Tea & Refreshments',
          category: 'Tea / Refreshment',
          totalAmount: 100.0,
          paymentMethod: AppConstants.paymentCash,
          cashAmount: 100.0,
          onlineAmount: 0.0,
          description: 'Evening tea for counter staff',
          createdBy: 'emp_01',
          createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
        ),
      ]);

      // Today Summary
      // Opening Cash: 2000, Opening Online: 10000
      // Cash Sales: 950, Online Sales: 500
      // Cash Exp: 400, Online Exp: 0
      // Cash to Bank: 500
      // Closing Cash = 2000 + 950 - 400 - 500 = 2050
      // Closing Online = 10000 + 500 - 0 + 500 = 11000
      _localDailySummaries[todayStr] = DailySummaryModel(
        date: todayStr,
        cashSales: 950.0,
        onlineSales: 500.0,
        totalSales: 1450.0,
        totalTransactions: 2,
        cashExpenses: 400.0,
        onlineExpenses: 0.0,
        totalExpenses: 400.0,
        cashOpeningBalance: 2000.0,
        onlineOpeningBalance: 10000.0,
        cashToBankTransfers: 500.0,
        closingCashBalance: 2050.0,
        closingOnlineBalance: 11000.0,
      );
    }
  }

  DocumentReference<Map<String, dynamic>>? get _shopRef {
    if (_firebaseService.isInitialized && _firebaseService.firestore != null) {
      return _firebaseService.firestore!.collection('shops').doc(_shopId);
    }
    return null;
  }

  @override
  Stream<List<AccountEntryModel>> watchAccountEntries({String? date, String? transactionType}) async* {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('account_entries').orderBy('createdAt', descending: true);
      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }
      if (transactionType != null && transactionType.isNotEmpty) {
        query = query.where('transactionType', isEqualTo: transactionType);
      }
      yield* query.snapshots().map((snap) => snap.docs.map((d) => AccountEntryModel.fromMap(d.data(), d.id)).toList());
    } else {
      yield _filterEntries(date, transactionType);
      yield* _entriesController.stream.map((_) => _filterEntries(date, transactionType));
    }
  }

  List<AccountEntryModel> _filterEntries(String? date, String? transactionType) {
    return _localEntries.where((e) {
      if (date != null && date.isNotEmpty && e.date != date) return false;
      if (transactionType != null && transactionType.isNotEmpty && e.transactionType != transactionType) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<AccountEntryModel>> getAccountEntries({String? date, String? transactionType}) async {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('account_entries').orderBy('createdAt', descending: true);
      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }
      if (transactionType != null && transactionType.isNotEmpty) {
        query = query.where('transactionType', isEqualTo: transactionType);
      }
      final snap = await query.get();
      return snap.docs.map((d) => AccountEntryModel.fromMap(d.data(), d.id)).toList();
    }
    return _filterEntries(date, transactionType);
  }

  @override
  Stream<List<ExpenseModel>> watchExpenses({String? date, String? category}) async* {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('expenses').orderBy('createdAt', descending: true);
      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }
      yield* query.snapshots().map((snap) => snap.docs.map((d) => ExpenseModel.fromMap(d.data(), d.id)).toList());
    } else {
      yield _filterExpenses(date, category);
      yield* _expensesController.stream.map((_) => _filterExpenses(date, category));
    }
  }

  List<ExpenseModel> _filterExpenses(String? date, String? category) {
    return _localExpenses.where((e) {
      if (date != null && date.isNotEmpty && e.date != date) return false;
      if (category != null && category.isNotEmpty && e.category != category) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<ExpenseModel>> getExpenses({String? date, String? category}) async {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('expenses').orderBy('createdAt', descending: true);
      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }
      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }
      final snap = await query.get();
      return snap.docs.map((d) => ExpenseModel.fromMap(d.data(), d.id)).toList();
    }
    return _filterExpenses(date, category);
  }

  @override
  Future<void> addExpense(ExpenseModel expense) async {
    // 1. Validation
    final cash = CurrencyFormatter.round(expense.cashAmount);
    final online = CurrencyFormatter.round(expense.onlineAmount);
    final total = CurrencyFormatter.round(expense.totalAmount);

    if ((cash + online - total).abs() > 0.01) {
      throw InvalidPaymentSplitException(
        'Expense allocation (Cash: ₹$cash + Online: ₹$online) does not equal Total Amount (₹$total).',
      );
    }

    if (total <= 0) {
      throw const AppException('Expense amount must be greater than zero.');
    }

    final now = DateTime.now();
    final entryId = 'entry_exp_${now.millisecondsSinceEpoch}';

    final entry = AccountEntryModel(
      entryId: entryId,
      date: expense.date,
      transactionType: AppConstants.entryExpense,
      referenceId: expense.expenseId,
      cashAmount: cash,
      onlineAmount: online,
      description: 'Expense [${expense.category}]: ${expense.reason}',
      createdBy: expense.createdBy,
      createdAt: now,
    );

    // 2. Firestore atomic update if connected
    final sRef = _shopRef;
    if (sRef != null) {
      await _firebaseService.firestore!.runTransaction((transaction) async {
        final expDoc = sRef.collection('expenses').doc(expense.expenseId);
        transaction.set(expDoc, expense.toMap());

        final entryDoc = sRef.collection('account_entries').doc(entryId);
        transaction.set(entryDoc, entry.toMap());

        final sumDoc = sRef.collection('daily_summaries').doc(expense.date);
        final sumSnap = await transaction.get(sumDoc);
        if (sumSnap.exists) {
          final cur = sumSnap.data()!;
          final curCashExp = (cur['cashExpenses'] as num? ?? 0).toDouble();
          final curOnlineExp = (cur['onlineExpenses'] as num? ?? 0).toDouble();
          final curTotalExp = (cur['totalExpenses'] as num? ?? 0).toDouble();
          final curClosingCash = (cur['closingCashBalance'] as num? ?? 0).toDouble();
          final curClosingOnline = (cur['closingOnlineBalance'] as num? ?? 0).toDouble();

          transaction.update(sumDoc, {
            'cashExpenses': CurrencyFormatter.round(curCashExp + cash),
            'onlineExpenses': CurrencyFormatter.round(curOnlineExp + online),
            'totalExpenses': CurrencyFormatter.round(curTotalExp + total),
            'closingCashBalance': CurrencyFormatter.round(curClosingCash - cash),
            'closingOnlineBalance': CurrencyFormatter.round(curClosingOnline - online),
          });
        }
      });
    }

    // 3. Update local caches
    _localExpenses.insert(0, expense);
    _localEntries.insert(0, entry);

    // Update Daily Summary
    final summary = await getDailySummary(expense.date);
    final updatedSummary = DailySummaryModel(
      date: summary.date,
      cashSales: summary.cashSales,
      onlineSales: summary.onlineSales,
      totalSales: summary.totalSales,
      totalTransactions: summary.totalTransactions,
      cashExpenses: CurrencyFormatter.round(summary.cashExpenses + cash),
      onlineExpenses: CurrencyFormatter.round(summary.onlineExpenses + online),
      totalExpenses: CurrencyFormatter.round(summary.totalExpenses + total),
      cashOpeningBalance: summary.cashOpeningBalance,
      onlineOpeningBalance: summary.onlineOpeningBalance,
      cashToBankTransfers: summary.cashToBankTransfers,
      closingCashBalance: CurrencyFormatter.round(summary.closingCashBalance - cash),
      closingOnlineBalance: CurrencyFormatter.round(summary.closingOnlineBalance - online),
    );

    _localDailySummaries[expense.date] = updatedSummary;

    _expensesController.add(List.unmodifiable(_localExpenses));
    _entriesController.add(List.unmodifiable(_localEntries));
    _summariesController.add(Map.unmodifiable(_localDailySummaries));
  }

  @override
  Stream<DailySummaryModel?> watchDailySummary(String date) async* {
    final sRef = _shopRef;
    if (sRef != null) {
      yield* sRef.collection('daily_summaries').doc(date).snapshots().map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return DailySummaryModel.fromMap(snap.data()!, snap.id);
      });
    } else {
      yield _localDailySummaries[date] ?? await getDailySummary(date);
      yield* _summariesController.stream.map((map) => map[date]);
    }
  }

  @override
  Future<DailySummaryModel> getDailySummary(String date) async {
    final sRef = _shopRef;
    if (sRef != null) {
      final doc = await sRef.collection('daily_summaries').doc(date).get();
      if (doc.exists && doc.data() != null) {
        return DailySummaryModel.fromMap(doc.data()!, doc.id);
      }
    } else if (_localDailySummaries.containsKey(date)) {
      return _localDailySummaries[date]!;
    }

    // Carry forward from previous day
    final prevSummary = await _getPreviousDaySummary(date);
    final openingCash = prevSummary?.closingCashBalance ?? 0.0;
    final openingOnline = prevSummary?.closingOnlineBalance ?? 0.0;

    final newSummary = DailySummaryModel(
      date: date,
      cashSales: 0.0,
      onlineSales: 0.0,
      totalSales: 0.0,
      totalTransactions: 0,
      cashExpenses: 0.0,
      onlineExpenses: 0.0,
      totalExpenses: 0.0,
      cashOpeningBalance: openingCash,
      onlineOpeningBalance: openingOnline,
      cashToBankTransfers: 0.0,
      closingCashBalance: openingCash,
      closingOnlineBalance: openingOnline,
    );

    _localDailySummaries[date] = newSummary;
    if (sRef != null) {
      await sRef.collection('daily_summaries').doc(date).set(newSummary.toMap());
    }
    return newSummary;
  }

  Future<DailySummaryModel?> _getPreviousDaySummary(String date) async {
    final curDate = DateTime.tryParse(date);
    if (curDate == null) return null;

    final yesterday = curDate.subtract(const Duration(days: 1));
    final yStr = yesterday.toIso8601String().split('T')[0];

    final sRef = _shopRef;
    if (sRef != null) {
      final snap = await sRef.collection('daily_summaries').doc(yStr).get();
      if (snap.exists && snap.data() != null) {
        return DailySummaryModel.fromMap(snap.data()!, snap.id);
      }
    } else if (_localDailySummaries.containsKey(yStr)) {
      return _localDailySummaries[yStr];
    }
    return null;
  }

  @override
  Future<void> setOpeningBalance({
    required String date,
    required double cashOpening,
    required double onlineOpening,
    required String userId,
  }) async {
    final now = DateTime.now();
    final cOpening = CurrencyFormatter.round(cashOpening);
    final oOpening = CurrencyFormatter.round(onlineOpening);

    final summary = await getDailySummary(date);
    final newClosingCash = CurrencyFormatter.round(cOpening + summary.cashSales - summary.cashExpenses - summary.cashToBankTransfers);
    final newClosingOnline = CurrencyFormatter.round(oOpening + summary.onlineSales - summary.onlineExpenses + summary.cashToBankTransfers);

    final updatedSummary = DailySummaryModel(
      date: date,
      cashSales: summary.cashSales,
      onlineSales: summary.onlineSales,
      totalSales: summary.totalSales,
      totalTransactions: summary.totalTransactions,
      cashExpenses: summary.cashExpenses,
      onlineExpenses: summary.onlineExpenses,
      totalExpenses: summary.totalExpenses,
      cashOpeningBalance: cOpening,
      onlineOpeningBalance: oOpening,
      cashToBankTransfers: summary.cashToBankTransfers,
      closingCashBalance: newClosingCash,
      closingOnlineBalance: newClosingOnline,
    );

    final entryId = 'entry_open_${now.millisecondsSinceEpoch}';
    final entry = AccountEntryModel(
      entryId: entryId,
      date: date,
      transactionType: AppConstants.entryOpeningBalance,
      referenceId: 'OPENING_$date',
      cashAmount: cOpening,
      onlineAmount: oOpening,
      description: 'Opening Cash: ₹$cOpening | Opening Bank: ₹$oOpening',
      createdBy: userId,
      createdAt: now,
    );

    final sRef = _shopRef;
    if (sRef != null) {
      await _firebaseService.firestore!.runTransaction((tx) async {
        tx.set(sRef.collection('daily_summaries').doc(date), updatedSummary.toMap());
        tx.set(sRef.collection('account_entries').doc(entryId), entry.toMap());
      });
    }

    _localDailySummaries[date] = updatedSummary;
    _localEntries.insert(0, entry);

    _summariesController.add(Map.unmodifiable(_localDailySummaries));
    _entriesController.add(List.unmodifiable(_localEntries));
  }

  @override
  Future<void> recordCashToBankTransfer({
    required double amount,
    required String notes,
    required String userId,
    String? date,
  }) async {
    if (amount <= 0) {
      throw const AppException('Transfer amount must be greater than zero.');
    }

    final now = DateTime.now();
    final todayStr = date ?? now.toIso8601String().split('T')[0];
    final trfAmount = CurrencyFormatter.round(amount);

    final entryId = 'entry_trf_${now.millisecondsSinceEpoch}';
    final entry = AccountEntryModel(
      entryId: entryId,
      date: todayStr,
      transactionType: AppConstants.entryTransfer,
      referenceId: 'TRF_${now.millisecondsSinceEpoch}',
      cashAmount: -trfAmount,
      onlineAmount: trfAmount,
      description: 'Cash-to-Bank Transfer: $notes',
      createdBy: userId,
      createdAt: now,
    );

    final sRef = _shopRef;
    if (sRef != null) {
      await _firebaseService.firestore!.runTransaction((tx) async {
        final sumDoc = sRef.collection('daily_summaries').doc(todayStr);
        final sumSnap = await tx.get(sumDoc);
        if (sumSnap.exists) {
          final cur = sumSnap.data()!;
          final curTrf = (cur['cashToBankTransfers'] as num? ?? 0).toDouble();
          final curCash = (cur['closingCashBalance'] as num? ?? 0).toDouble();
          final curOnline = (cur['closingOnlineBalance'] as num? ?? 0).toDouble();

          tx.update(sumDoc, {
            'cashToBankTransfers': CurrencyFormatter.round(curTrf + trfAmount),
            'closingCashBalance': CurrencyFormatter.round(curCash - trfAmount),
            'closingOnlineBalance': CurrencyFormatter.round(curOnline + trfAmount),
          });
        }
        tx.set(sRef.collection('account_entries').doc(entryId), entry.toMap());
      });
    }

    _localEntries.insert(0, entry);

    final summary = await getDailySummary(todayStr);
    final updatedSummary = DailySummaryModel(
      date: summary.date,
      cashSales: summary.cashSales,
      onlineSales: summary.onlineSales,
      totalSales: summary.totalSales,
      totalTransactions: summary.totalTransactions,
      cashExpenses: summary.cashExpenses,
      onlineExpenses: summary.onlineExpenses,
      totalExpenses: summary.totalExpenses,
      cashOpeningBalance: summary.cashOpeningBalance,
      onlineOpeningBalance: summary.onlineOpeningBalance,
      cashToBankTransfers: CurrencyFormatter.round(summary.cashToBankTransfers + trfAmount),
      closingCashBalance: CurrencyFormatter.round(summary.closingCashBalance - trfAmount),
      closingOnlineBalance: CurrencyFormatter.round(summary.closingOnlineBalance + trfAmount),
    );

    _localDailySummaries[todayStr] = updatedSummary;

    _entriesController.add(List.unmodifiable(_localEntries));
    _summariesController.add(Map.unmodifiable(_localDailySummaries));
  }

  @override
  Future<void> recordSaleIncome({
    required AccountEntryModel entry,
    required double cashAmount,
    required double onlineAmount,
    required double grandTotal,
    required String date,
  }) async {
    final sRef = _shopRef;
    if (sRef != null) {
      await sRef.collection('account_entries').doc(entry.entryId).set(entry.toMap());
    }

    _localEntries.insert(0, entry);
    _entriesController.add(List.unmodifiable(_localEntries));

    // Update daily summary
    final summary = await getDailySummary(date);
    final updatedSummary = DailySummaryModel(
      date: summary.date,
      cashSales: CurrencyFormatter.round(summary.cashSales + cashAmount),
      onlineSales: CurrencyFormatter.round(summary.onlineSales + onlineAmount),
      totalSales: CurrencyFormatter.round(summary.totalSales + grandTotal),
      totalTransactions: summary.totalTransactions + 1,
      cashExpenses: summary.cashExpenses,
      onlineExpenses: summary.onlineExpenses,
      totalExpenses: summary.totalExpenses,
      cashOpeningBalance: summary.cashOpeningBalance,
      onlineOpeningBalance: summary.onlineOpeningBalance,
      cashToBankTransfers: summary.cashToBankTransfers,
      closingCashBalance: CurrencyFormatter.round(summary.closingCashBalance + cashAmount),
      closingOnlineBalance: CurrencyFormatter.round(summary.closingOnlineBalance + onlineAmount),
    );

    _localDailySummaries[date] = updatedSummary;
    _summariesController.add(Map.unmodifiable(_localDailySummaries));
  }

  @override
  Future<void> recordSaleCancellation({
    required String saleId,
    required String invoiceNumber,
    required double cashAmount,
    required double onlineAmount,
    required double grandTotal,
    required String date,
    required String userId,
    required String reason,
  }) async {
    final now = DateTime.now();
    final entryId = 'entry_refund_${now.millisecondsSinceEpoch}';
    final entry = AccountEntryModel(
      entryId: entryId,
      date: date,
      transactionType: AppConstants.entryRefund,
      referenceId: saleId,
      cashAmount: -CurrencyFormatter.round(cashAmount),
      onlineAmount: -CurrencyFormatter.round(onlineAmount),
      description: 'Sale Reversal #$invoiceNumber: $reason',
      createdBy: userId,
      createdAt: now,
    );

    final sRef = _shopRef;
    if (sRef != null) {
      await sRef.collection('account_entries').doc(entryId).set(entry.toMap());
    }

    _localEntries.insert(0, entry);
    _entriesController.add(List.unmodifiable(_localEntries));

    // Revert from daily summary
    final summary = await getDailySummary(date);
    final updatedSummary = DailySummaryModel(
      date: summary.date,
      cashSales: CurrencyFormatter.round(summary.cashSales - cashAmount),
      onlineSales: CurrencyFormatter.round(summary.onlineSales - onlineAmount),
      totalSales: CurrencyFormatter.round(summary.totalSales - grandTotal),
      totalTransactions: summary.totalTransactions > 0 ? summary.totalTransactions - 1 : 0,
      cashExpenses: summary.cashExpenses,
      onlineExpenses: summary.onlineExpenses,
      totalExpenses: summary.totalExpenses,
      cashOpeningBalance: summary.cashOpeningBalance,
      onlineOpeningBalance: summary.onlineOpeningBalance,
      cashToBankTransfers: summary.cashToBankTransfers,
      closingCashBalance: CurrencyFormatter.round(summary.closingCashBalance - cashAmount),
      closingOnlineBalance: CurrencyFormatter.round(summary.closingOnlineBalance - onlineAmount),
    );

    _localDailySummaries[date] = updatedSummary;
    _summariesController.add(Map.unmodifiable(_localDailySummaries));
  }

  @override
  Future<DailySummaryModel> recalculateDailySummary(String date) async {
    final entries = await getAccountEntries(date: date);
    final summary = await getDailySummary(date);

    double cSales = 0.0;
    double oSales = 0.0;
    int txCount = 0;
    double cExp = 0.0;
    double oExp = 0.0;
    double trf = 0.0;

    for (final e in entries) {
      if (e.transactionType == AppConstants.entrySaleIncome) {
        cSales += e.cashAmount;
        oSales += e.onlineAmount;
        txCount++;
      } else if (e.transactionType == AppConstants.entryExpense) {
        cExp += e.cashAmount;
        oExp += e.onlineAmount;
      } else if (e.transactionType == AppConstants.entryTransfer) {
        trf += e.onlineAmount; // online amount is positive transfer
      } else if (e.transactionType == AppConstants.entryRefund) {
        cSales += e.cashAmount; // negative
        oSales += e.onlineAmount; // negative
      }
    }

    cSales = CurrencyFormatter.round(cSales);
    oSales = CurrencyFormatter.round(oSales);
    cExp = CurrencyFormatter.round(cExp);
    oExp = CurrencyFormatter.round(oExp);
    trf = CurrencyFormatter.round(trf);

    final closingCash = CurrencyFormatter.round(summary.cashOpeningBalance + cSales - cExp - trf);
    final closingOnline = CurrencyFormatter.round(summary.onlineOpeningBalance + oSales - oExp + trf);

    final recalculated = DailySummaryModel(
      date: date,
      cashSales: cSales,
      onlineSales: oSales,
      totalSales: CurrencyFormatter.round(cSales + oSales),
      totalTransactions: txCount,
      cashExpenses: cExp,
      onlineExpenses: oExp,
      totalExpenses: CurrencyFormatter.round(cExp + oExp),
      cashOpeningBalance: summary.cashOpeningBalance,
      onlineOpeningBalance: summary.onlineOpeningBalance,
      cashToBankTransfers: trf,
      closingCashBalance: closingCash,
      closingOnlineBalance: closingOnline,
    );

    _localDailySummaries[date] = recalculated;
    _summariesController.add(Map.unmodifiable(_localDailySummaries));

    final sRef = _shopRef;
    if (sRef != null) {
      await sRef.collection('daily_summaries').doc(date).set(recalculated.toMap());
    }

    return recalculated;
  }
}

