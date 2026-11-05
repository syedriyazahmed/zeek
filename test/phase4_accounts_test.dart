import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_pos/core/constants/app_constants.dart';
import 'package:perfume_pos/core/exceptions/app_exceptions.dart';
import 'package:perfume_pos/data/models/expense_model.dart';
import 'package:perfume_pos/data/repositories/accounts_repository.dart';
import 'package:perfume_pos/services/csv/csv_service.dart';
import 'package:perfume_pos/services/firebase/firebase_service.dart';

void main() {
  late FirebaseAccountsRepository accountsRepo;

  setUp(() {
    final firebaseService = FirebaseService.instance;
    accountsRepo = FirebaseAccountsRepository(firebaseService);
  });

  group('Phase 4 - Accounts & Daily Balance Tests', () {
    test('Daily summary initializes and calculates closing balances accurately', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      final summary = await accountsRepo.getDailySummary(todayStr);
      expect(summary.date, todayStr);
      expect(summary.cashOpeningBalance, 2000.0);
      expect(summary.onlineOpeningBalance, 10000.0);
      expect(summary.cashSales, 950.0);
      expect(summary.onlineSales, 500.0);
      expect(summary.cashExpenses, 400.0);
      expect(summary.cashToBankTransfers, 500.0);

      // Verify mathematical balance formula:
      // Closing Cash = Opening Cash (2000) + Cash Sales (950) - Cash Exp (400) - Transfer (500) = 2050
      expect(summary.closingCashBalance, 2050.0);
      // Closing Online = Opening Online (10000) + Online Sales (500) - Online Exp (0) + Transfer (500) = 11000
      expect(summary.closingOnlineBalance, 11000.0);
      // Grand Balance = 2050 + 11000 = 13050
      expect(summary.grandClosingBalance, 13050.0);
    });

    test('Adding a cash expense atomically updates expenses and reduces closing cash balance', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      final before = await accountsRepo.getDailySummary(todayStr);

      final expense = ExpenseModel(
        expenseId: 'exp_test_001',
        date: todayStr,
        reason: 'Courier Delivery for Customer',
        category: 'Courier & Shipping',
        totalAmount: 150.0,
        paymentMethod: AppConstants.paymentCash,
        cashAmount: 150.0,
        onlineAmount: 0.0,
        description: 'Bluedart tracking #12345',
        createdBy: 'test_admin',
        createdAt: now,
      );

      await accountsRepo.addExpense(expense);

      final after = await accountsRepo.getDailySummary(todayStr);
      expect(after.cashExpenses, before.cashExpenses + 150.0);
      expect(after.totalExpenses, before.totalExpenses + 150.0);
      expect(after.closingCashBalance, before.closingCashBalance - 150.0);
      expect(after.closingOnlineBalance, before.closingOnlineBalance); // Unchanged

      // Verify entry logged in ledger
      final entries = await accountsRepo.getAccountEntries(date: todayStr, transactionType: AppConstants.entryExpense);
      expect(entries.any((e) => e.referenceId == 'exp_test_001'), isTrue);
    });

    test('Adding a split expense validates cash + online == total and updates balances', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      // Invalid split must throw InvalidPaymentSplitException
      final invalidExpense = ExpenseModel(
        expenseId: 'exp_inv',
        date: todayStr,
        reason: 'Office Chair',
        category: 'Maintenance',
        totalAmount: 1000.0,
        paymentMethod: AppConstants.paymentSplit,
        cashAmount: 400.0,
        onlineAmount: 500.0, // 400 + 500 != 1000
        createdBy: 'admin',
        createdAt: now,
      );

      expect(() => accountsRepo.addExpense(invalidExpense), throwsA(isA<InvalidPaymentSplitException>()));

      // Valid split
      final before = await accountsRepo.getDailySummary(todayStr);

      final validExpense = ExpenseModel(
        expenseId: 'exp_valid_split',
        date: todayStr,
        reason: 'Office Chair',
        category: 'Maintenance',
        totalAmount: 1000.0,
        paymentMethod: AppConstants.paymentSplit,
        cashAmount: 400.0,
        onlineAmount: 600.0,
        createdBy: 'admin',
        createdAt: now,
      );

      await accountsRepo.addExpense(validExpense);

      final after = await accountsRepo.getDailySummary(todayStr);
      expect(after.cashExpenses, before.cashExpenses + 400.0);
      expect(after.onlineExpenses, before.onlineExpenses + 600.0);
      expect(after.totalExpenses, before.totalExpenses + 1000.0);
      expect(after.closingCashBalance, before.closingCashBalance - 400.0);
      expect(after.closingOnlineBalance, before.closingOnlineBalance - 600.0);
    });

    test('Cash-to-bank transfer decreases cash and increases bank balance without double counting', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      final before = await accountsRepo.getDailySummary(todayStr);
      const transferAmount = 1000.0;

      await accountsRepo.recordCashToBankTransfer(
        amount: transferAmount,
        notes: 'SBI Current Account Cash Deposit',
        userId: 'admin_test',
        date: todayStr,
      );

      final after = await accountsRepo.getDailySummary(todayStr);
      expect(after.cashToBankTransfers, before.cashToBankTransfers + transferAmount);
      expect(after.closingCashBalance, before.closingCashBalance - transferAmount);
      expect(after.closingOnlineBalance, before.closingOnlineBalance + transferAmount);
      // Total store balance remains exactly identical (conservation of money)
      expect(after.grandClosingBalance, before.grandClosingBalance);

      // Verify ledger entry
      final entries = await accountsRepo.getAccountEntries(date: todayStr, transactionType: AppConstants.entryTransfer);
      final transferEntry = entries.firstWhere((e) => e.description.contains('SBI Current Account'));
      expect(transferEntry.cashAmount, -transferAmount);
      expect(transferEntry.onlineAmount, transferAmount);
    });

    test('Setting opening balance recalculates closing balances based on day transactions', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      await accountsRepo.setOpeningBalance(
        date: todayStr,
        cashOpening: 5000.0,
        onlineOpening: 20000.0,
        userId: 'admin_owner',
      );

      final summary = await accountsRepo.getDailySummary(todayStr);
      expect(summary.cashOpeningBalance, 5000.0);
      expect(summary.onlineOpeningBalance, 20000.0);

      // Re-verify formula
      final expectedCash = 5000.0 + summary.cashSales - summary.cashExpenses - summary.cashToBankTransfers;
      final expectedOnline = 20000.0 + summary.onlineSales - summary.onlineExpenses + summary.cashToBankTransfers;

      expect(summary.closingCashBalance, expectedCash);
      expect(summary.closingOnlineBalance, expectedOnline);
    });

    test('Audit reconciliation re-aggregates entries and balances accurately', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      final reconciled = await accountsRepo.recalculateDailySummary(todayStr);
      expect(reconciled.date, todayStr);
      expect(reconciled.totalSales, reconciled.cashSales + reconciled.onlineSales);
      expect(reconciled.totalExpenses, reconciled.cashExpenses + reconciled.onlineExpenses);
    });

    test('CSV export exports ledger entries accurately', () async {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final entries = await accountsRepo.getAccountEntries(date: todayStr);

      final csvContent = CsvService.instance.exportAccountLedgerToCsv(entries);
      expect(csvContent.contains('Date,Time,Entry ID,Type,Description,Cash Amount,Online Amount,Total Amount,Created By'), isTrue);
      expect(csvContent.contains(todayStr), isTrue);
    });
  });
}

