class AppConstants {
  AppConstants._();

  static const String appName = 'Al-Abeer Perfumes & Athar';
  static const String appSubtitle = 'Shop Management & POS System';
  static const String defaultShopId = 'main_shop';
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // Product Types
  static const String productTypeOil = 'Oil';
  static const String productTypeNonOil = 'Non-Oil';

  // Units
  static const String unitMl = 'ml';
  static const String unitPiece = 'piece';

  // Payment Types
  static const String paymentCash = 'cash';
  static const String paymentOnline = 'online';
  static const String paymentSplit = 'split';

  // Roles
  static const String roleAdmin = 'admin';
  static const String roleEmployee = 'employee';

  // Stock Movement Types
  static const String movementOpeningStock = 'OPENING_STOCK';
  static const String movementPurchase = 'PURCHASE';
  static const String movementSale = 'SALE';
  static const String movementSaleReturn = 'SALE_RETURN';
  static const String movementDamage = 'DAMAGE';
  static const String movementWastage = 'WASTAGE';
  static const String movementAdjustment = 'STOCK_ADJUSTMENT';

  // Account Entry Transaction Types
  static const String entryOpeningBalance = 'OPENING_BALANCE';
  static const String entrySaleIncome = 'SALE_INCOME';
  static const String entryExpense = 'EXPENSE';
  static const String entryTransfer = 'TRANSFER';
  static const String entryRefund = 'REFUND';
  static const String entryAdjustment = 'ADJUSTMENT';

  // Sale Status
  static const String saleStatusCompleted = 'completed';
  static const String saleStatusCancelled = 'cancelled';

  // Breakpoints
  static const double mobileBreakpoint = 768.0;
  static const double tabletBreakpoint = 1024.0;
}

