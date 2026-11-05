import '../../core/utils/currency_formatter.dart';

class DailySummaryModel {
  final String date;
  final double cashSales;
  final double onlineSales;
  final double totalSales;
  final int totalTransactions;
  final double cashExpenses;
  final double onlineExpenses;
  final double totalExpenses;
  final double cashOpeningBalance;
  final double onlineOpeningBalance;
  final double cashToBankTransfers;
  final double closingCashBalance;
  final double closingOnlineBalance;

  const DailySummaryModel({
    required this.date,
    this.cashSales = 0.0,
    this.onlineSales = 0.0,
    this.totalSales = 0.0,
    this.totalTransactions = 0,
    this.cashExpenses = 0.0,
    this.onlineExpenses = 0.0,
    this.totalExpenses = 0.0,
    this.cashOpeningBalance = 0.0,
    this.onlineOpeningBalance = 0.0,
    this.cashToBankTransfers = 0.0,
    this.closingCashBalance = 0.0,
    this.closingOnlineBalance = 0.0,
  });

  double get grandClosingBalance =>
      CurrencyFormatter.round(closingCashBalance + closingOnlineBalance);

  double get netCashChange =>
      CurrencyFormatter.round(cashSales - cashExpenses - cashToBankTransfers);

  double get netOnlineChange =>
      CurrencyFormatter.round(onlineSales - onlineExpenses + cashToBankTransfers);

  factory DailySummaryModel.fromMap(Map<String, dynamic> map, String id) {
    return DailySummaryModel(
      date: id,
      cashSales: (map['cashSales'] as num?)?.toDouble() ?? 0.0,
      onlineSales: (map['onlineSales'] as num?)?.toDouble() ?? 0.0,
      totalSales: (map['totalSales'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: (map['totalTransactions'] as num?)?.toInt() ?? 0,
      cashExpenses: (map['cashExpenses'] as num?)?.toDouble() ?? 0.0,
      onlineExpenses: (map['onlineExpenses'] as num?)?.toDouble() ?? 0.0,
      totalExpenses: (map['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      cashOpeningBalance: (map['cashOpeningBalance'] as num?)?.toDouble() ?? 0.0,
      onlineOpeningBalance: (map['onlineOpeningBalance'] as num?)?.toDouble() ?? 0.0,
      cashToBankTransfers: (map['cashToBankTransfers'] as num?)?.toDouble() ?? 0.0,
      closingCashBalance: (map['closingCashBalance'] as num?)?.toDouble() ?? 0.0,
      closingOnlineBalance: (map['closingOnlineBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'cashSales': CurrencyFormatter.round(cashSales),
      'onlineSales': CurrencyFormatter.round(onlineSales),
      'totalSales': CurrencyFormatter.round(totalSales),
      'totalTransactions': totalTransactions,
      'cashExpenses': CurrencyFormatter.round(cashExpenses),
      'onlineExpenses': CurrencyFormatter.round(onlineExpenses),
      'totalExpenses': CurrencyFormatter.round(totalExpenses),
      'cashOpeningBalance': CurrencyFormatter.round(cashOpeningBalance),
      'onlineOpeningBalance': CurrencyFormatter.round(onlineOpeningBalance),
      'cashToBankTransfers': CurrencyFormatter.round(cashToBankTransfers),
      'closingCashBalance': CurrencyFormatter.round(closingCashBalance),
      'closingOnlineBalance': CurrencyFormatter.round(closingOnlineBalance),
      'grandClosingBalance': grandClosingBalance,
    };
  }
}

