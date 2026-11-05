import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/utils/currency_formatter.dart';
import '../../services/firebase/firebase_service.dart';
import '../models/account_entry_model.dart';
import '../models/daily_summary_model.dart';
import '../models/product_model.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';
import '../models/stock_movement_model.dart';
import 'accounts_repository.dart';
import 'inventory_repository.dart';

abstract class SalesRepository {
  Future<SaleModel> completeSale(
    SaleModel sale, {
    String? idempotencyKey,
  });
  Stream<List<SaleModel>> watchSales({String? date});
  Future<List<SaleModel>> getSales({String? date});
  Future<SaleModel?> getSaleById(String saleId);
  Future<void> cancelSale(String saleId, String reason, String userId);
}

class FirebaseSalesRepository implements SalesRepository {
  final FirebaseService _firebaseService;
  final InventoryRepository _inventoryRepository;
  final AccountsRepository? _accountsRepository;
  final String _shopId;

  // Local state cache for offline & testing
  final List<SaleModel> _localSales = [];
  final List<AccountEntryModel> _localAccountEntries = [];
  final Map<String, DailySummaryModel> _localDailySummaries = {};
  final Set<String> _processedIdempotencyKeys = {};

  final _salesController = StreamController<List<SaleModel>>.broadcast();

  FirebaseSalesRepository(
    this._firebaseService,
    this._inventoryRepository, {
    AccountsRepository? accountsRepository,
    String shopId = AppConstants.defaultShopId,
  })  : _accountsRepository = accountsRepository,
        _shopId = shopId {
    _initDemoSales();
  }

  void _initDemoSales() {
    if (_localSales.isEmpty) {
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];

      // Seed 2 initial sales for reporting & history
      final s1 = SaleModel(
        saleId: 'sale_init_001',
        invoiceNumber: 'INV-100234',
        date: todayStr,
        timestamp: now.subtract(const Duration(hours: 4)),
        items: [
          SaleItemModel(
            productId: 'prod_cambodi_oud',
            productName: 'Dehn Al Oud Cambodi',
            productType: AppConstants.productTypeOil,
            quantity: 20.0,
            unit: AppConstants.unitMl,
            unitPrice: 25.0,
            unitCostAtSale: 12.0,
            totalPrice: 500.0,
          ),
        ],
        subtotal: 500.0,
        discount: 0.0,
        grandTotal: 500.0,
        paymentType: AppConstants.paymentCash,
        cashAmount: 500.0,
        onlineAmount: 0.0,
        status: AppConstants.saleStatusCompleted,
        createdBy: 'admin',
        createdByName: 'Shop Administrator',
      );

      final s2 = SaleModel(
        saleId: 'sale_init_002',
        invoiceNumber: 'INV-100235',
        date: todayStr,
        timestamp: now.subtract(const Duration(hours: 2)),
        items: [
          SaleItemModel(
            productId: 'prod_white_musk',
            productName: 'Royal White Musk',
            productType: AppConstants.productTypeOil,
            quantity: 10.0,
            unit: AppConstants.unitMl,
            unitPrice: 15.0,
            unitCostAtSale: 5.0,
            totalPrice: 150.0,
          ),
          SaleItemModel(
            productId: 'prod_rose_spray',
            productName: 'Rose Taif Perfume Spray 50ml',
            productType: AppConstants.productTypeNonOil,
            quantity: 2.0,
            unit: AppConstants.unitPiece,
            unitPrice: 425.0,
            unitCostAtSale: 200.0,
            totalPrice: 850.0,
          ),
        ],
        subtotal: 1000.0,
        discount: 50.0,
        grandTotal: 950.0,
        paymentType: AppConstants.paymentSplit,
        cashAmount: 450.0,
        onlineAmount: 500.0,
        status: AppConstants.saleStatusCompleted,
        createdBy: 'staff',
        createdByName: 'Staff Representative',
      );

      _localSales.addAll([s1, s2]);
      _salesController.add(List.unmodifiable(_localSales));

      // Initial Account Entries
      _localAccountEntries.add(
        AccountEntryModel(
          entryId: 'entry_init_001',
          date: todayStr,
          transactionType: AppConstants.entrySaleIncome,
          referenceId: 'sale_init_001',
          cashAmount: 500.0,
          onlineAmount: 0.0,
          description: 'POS Sale #INV-100234',
          createdBy: 'admin',
          createdAt: now.subtract(const Duration(hours: 4)),
        ),
      );
      _localAccountEntries.add(
        AccountEntryModel(
          entryId: 'entry_init_002',
          date: todayStr,
          transactionType: AppConstants.entrySaleIncome,
          referenceId: 'sale_init_002',
          cashAmount: 450.0,
          onlineAmount: 500.0,
          description: 'POS Sale #INV-100235',
          createdBy: 'staff',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      );

      // Initial Daily Summary
      _localDailySummaries[todayStr] = DailySummaryModel(
        date: todayStr,
        cashSales: 950.0,
        onlineSales: 500.0,
        totalSales: 1450.0,
        totalTransactions: 2,
        cashOpeningBalance: 2000.0,
        onlineOpeningBalance: 5000.0,
        closingCashBalance: 2950.0,
        closingOnlineBalance: 5500.0,
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
  Future<SaleModel> completeSale(
    SaleModel sale, {
    String? idempotencyKey,
  }) async {
    // 1. Idempotency Check
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      if (_processedIdempotencyKeys.contains(idempotencyKey)) {
        final existing = _localSales.where((s) => s.saleId == sale.saleId);
        if (existing.isNotEmpty) return existing.first;
      }
      _processedIdempotencyKeys.add(idempotencyKey);
    }

    // 2. Validate Cart
    if (sale.items.isEmpty) {
      throw const AppException('Sale cart cannot be empty.');
    }

    // 3. Validate Payment Allocation
    final cash = CurrencyFormatter.round(sale.cashAmount);
    final online = CurrencyFormatter.round(sale.onlineAmount);
    final grandTotal = CurrencyFormatter.round(sale.grandTotal);

    if ((cash + online - grandTotal).abs() > 0.01) {
      throw InvalidPaymentSplitException(
        'Payment allocation (Cash: ₹$cash + Online: ₹$online = ₹${cash + online}) does not equal Grand Total (₹$grandTotal).',
      );
    }

    final now = DateTime.now();
    final todayStr = sale.date.isNotEmpty ? sale.date : now.toIso8601String().split('T')[0];

    // 4. Validate Stock Availability & Snapshot Unit Costs
    final List<ProductModel> productsToUpdate = [];
    final List<StockMovementModel> movementsToCreate = [];

    for (final item in sale.items) {
      final product = await _inventoryRepository.getProductById(item.productId);
      if (product == null) {
        throw AppException('Product "${item.productName}" not found in inventory.');
      }

      if (product.availableQuantity < item.quantity) {
        throw InsufficientStockException(
          productName: product.productName,
          requestedQuantity: item.quantity,
          availableQuantity: product.availableQuantity,
        );
      }

      final newAvailable = CurrencyFormatter.round(product.availableQuantity - item.quantity);
      final newSold = CurrencyFormatter.round(product.totalSold + item.quantity);

      productsToUpdate.add(
        product.copyWith(
          availableQuantity: newAvailable,
          totalSold: newSold,
          updatedAt: now,
        ),
      );

      movementsToCreate.add(
        StockMovementModel(
          movementId: 'mov_sale_${now.millisecondsSinceEpoch}_${item.productId}',
          productId: item.productId,
          productName: item.productName,
          movementType: AppConstants.movementSale,
          quantity: -item.quantity, // Negative for deduction
          unit: item.unit,
          referenceId: sale.saleId,
          date: todayStr,
          notes: 'POS Sale #${sale.invoiceNumber}',
          createdBy: sale.createdBy,
          createdAt: now,
        ),
      );
    }

    // 5. Account Entry (SALE_INCOME)
    final accountEntry = AccountEntryModel(
      entryId: 'entry_${now.millisecondsSinceEpoch}',
      date: todayStr,
      transactionType: AppConstants.entrySaleIncome,
      referenceId: sale.saleId,
      cashAmount: cash,
      onlineAmount: online,
      description: 'POS Sale #${sale.invoiceNumber}',
      createdBy: sale.createdBy,
      createdAt: now,
    );

    // 6. Firestore Atomic Transaction (if connected)
    final sRef = _shopRef;
    if (sRef != null) {
      await _firebaseService.firestore!.runTransaction((transaction) async {
        // Read and verify stock within transaction
        for (final item in sale.items) {
          final pDoc = sRef.collection('products').doc(item.productId);
          final pSnap = await transaction.get(pDoc);
          if (!pSnap.exists) {
            throw AppException('Product "${item.productName}" not found.');
          }
          final avail = (pSnap.data()?['availableQuantity'] as num?)?.toDouble() ?? 0.0;
          if (avail < item.quantity) {
            throw InsufficientStockException(
              productName: item.productName,
              requestedQuantity: item.quantity,
              availableQuantity: avail,
            );
          }
        }

        // Writes: Products stock update
        for (final p in productsToUpdate) {
          transaction.update(sRef.collection('products').doc(p.productId), p.toMap());
        }

        // Writes: Stock Movements
        for (final m in movementsToCreate) {
          transaction.set(sRef.collection('stock_movements').doc(m.movementId), m.toMap());
        }

        // Writes: Sale Document
        transaction.set(sRef.collection('sales').doc(sale.saleId), sale.toMap());

        // Writes: Account Entry
        transaction.set(sRef.collection('account_entries').doc(accountEntry.entryId), accountEntry.toMap());

        // Writes: Daily Summary
        final sumDoc = sRef.collection('daily_summaries').doc(todayStr);
        final sumSnap = await transaction.get(sumDoc);
        if (sumSnap.exists) {
          final cur = sumSnap.data()!;
          transaction.update(sumDoc, {
            'cashSales': CurrencyFormatter.round((cur['cashSales'] as num? ?? 0) + cash),
            'onlineSales': CurrencyFormatter.round((cur['onlineSales'] as num? ?? 0) + online),
            'totalSales': CurrencyFormatter.round((cur['totalSales'] as num? ?? 0) + grandTotal),
            'totalTransactions': (cur['totalTransactions'] as num? ?? 0).toInt() + 1,
            'closingCashBalance': CurrencyFormatter.round((cur['closingCashBalance'] as num? ?? 0) + cash),
            'closingOnlineBalance': CurrencyFormatter.round((cur['closingOnlineBalance'] as num? ?? 0) + online),
          });
        } else {
          transaction.set(sumDoc, {
            'date': todayStr,
            'cashSales': cash,
            'onlineSales': online,
            'totalSales': grandTotal,
            'totalTransactions': 1,
            'cashExpenses': 0.0,
            'onlineExpenses': 0.0,
            'totalExpenses': 0.0,
            'cashOpeningBalance': 0.0,
            'onlineOpeningBalance': 0.0,
            'cashToBankTransfers': 0.0,
            'closingCashBalance': cash,
            'closingOnlineBalance': online,
          });
        }
      });
    }

    // 7. Update Local Repositories & Cache
    for (final p in productsToUpdate) {
      await _inventoryRepository.updateProduct(p);
    }
    await _inventoryRepository.recordStockMovements(movementsToCreate);

    _localSales.insert(0, sale);
    _localAccountEntries.insert(0, accountEntry);

    if (_accountsRepository != null) {
      await _accountsRepository.recordSaleIncome(
        entry: accountEntry,
        cashAmount: cash,
        onlineAmount: online,
        grandTotal: grandTotal,
        date: todayStr,
      );
    }

    final existingSummary = _localDailySummaries[todayStr] ?? DailySummaryModel(date: todayStr);
    _localDailySummaries[todayStr] = DailySummaryModel(
      date: todayStr,
      cashSales: CurrencyFormatter.round(existingSummary.cashSales + cash),
      onlineSales: CurrencyFormatter.round(existingSummary.onlineSales + online),
      totalSales: CurrencyFormatter.round(existingSummary.totalSales + grandTotal),
      totalTransactions: existingSummary.totalTransactions + 1,
      cashExpenses: existingSummary.cashExpenses,
      onlineExpenses: existingSummary.onlineExpenses,
      totalExpenses: existingSummary.totalExpenses,
      cashOpeningBalance: existingSummary.cashOpeningBalance,
      onlineOpeningBalance: existingSummary.onlineOpeningBalance,
      cashToBankTransfers: existingSummary.cashToBankTransfers,
      closingCashBalance: CurrencyFormatter.round(existingSummary.closingCashBalance + cash),
      closingOnlineBalance: CurrencyFormatter.round(existingSummary.closingOnlineBalance + online),
    );

    _salesController.add(List.unmodifiable(_localSales));

    return sale;
  }

  @override
  Stream<List<SaleModel>> watchSales({String? date}) async* {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('sales').orderBy('timestamp', descending: true);
      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }
      yield* query.snapshots().map((snap) => snap.docs.map((d) => SaleModel.fromMap(d.data(), d.id)).toList());
    } else {
      yield _filterSales(date);
      yield* _salesController.stream.map((_) => _filterSales(date));
    }
  }

  List<SaleModel> _filterSales(String? date) {
    if (date == null || date.isEmpty) return List.unmodifiable(_localSales);
    return _localSales.where((s) => s.date == date).toList();
  }

  @override
  Future<List<SaleModel>> getSales({String? date}) async {
    final sRef = _shopRef;
    if (sRef != null) {
      Query<Map<String, dynamic>> query = sRef.collection('sales').orderBy('timestamp', descending: true);
      if (date != null && date.isNotEmpty) {
        query = query.where('date', isEqualTo: date);
      }
      final snap = await query.get();
      return snap.docs.map((d) => SaleModel.fromMap(d.data(), d.id)).toList();
    }
    return _filterSales(date);
  }

  @override
  Future<SaleModel?> getSaleById(String saleId) async {
    final sRef = _shopRef;
    if (sRef != null) {
      final doc = await sRef.collection('sales').doc(saleId).get();
      if (doc.exists && doc.data() != null) {
        return SaleModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    }
    final match = _localSales.where((s) => s.saleId == saleId);
    return match.isNotEmpty ? match.first : null;
  }

  @override
  Future<void> cancelSale(String saleId, String reason, String userId) async {
    final sale = await getSaleById(saleId);
    if (sale == null) throw const AppException('Sale not found.');
    if (sale.isCancelled) throw const AppException('Sale is already cancelled.');

    final now = DateTime.now();

    // Restore stock and record reversal movements
    final List<StockMovementModel> reversalMovements = [];
    for (final item in sale.items) {
      final product = await _inventoryRepository.getProductById(item.productId);
      if (product != null) {
        final restoredStock = CurrencyFormatter.round(product.availableQuantity + item.quantity);
        final restoredSold = CurrencyFormatter.round(product.totalSold - item.quantity);
        await _inventoryRepository.updateProduct(
          product.copyWith(
            availableQuantity: restoredStock,
            totalSold: restoredSold < 0 ? 0 : restoredSold,
            updatedAt: now,
          ),
        );

        reversalMovements.add(
          StockMovementModel(
            movementId: 'mov_rev_${now.millisecondsSinceEpoch}_${item.productId}',
            productId: item.productId,
            productName: item.productName,
            movementType: AppConstants.movementSaleReturn,
            quantity: item.quantity,
            unit: item.unit,
            referenceId: sale.saleId,
            date: now.toIso8601String().split('T')[0],
            notes: 'Sale Cancellation: $reason',
            createdBy: userId,
            createdAt: now,
          ),
        );
      }
    }
    if (reversalMovements.isNotEmpty) {
      await _inventoryRepository.recordStockMovements(reversalMovements);
    }

    final updatedSale = SaleModel(
      saleId: sale.saleId,
      invoiceNumber: sale.invoiceNumber,
      date: sale.date,
      timestamp: sale.timestamp,
      items: sale.items,
      subtotal: sale.subtotal,
      discount: sale.discount,
      grandTotal: sale.grandTotal,
      paymentType: sale.paymentType,
      cashAmount: sale.cashAmount,
      onlineAmount: sale.onlineAmount,
      status: AppConstants.saleStatusCancelled,
      createdBy: sale.createdBy,
      createdByName: sale.createdByName,
      cancellationReason: reason,
      cancelledAt: now,
      cancelledBy: userId,
    );

    final sRef = _shopRef;
    if (sRef != null) {
      await sRef.collection('sales').doc(saleId).update(updatedSale.toMap());
    }

    final index = _localSales.indexWhere((s) => s.saleId == saleId);
    if (index != -1) {
      _localSales[index] = updatedSale;
      _salesController.add(List.unmodifiable(_localSales));
    }

    if (_accountsRepository != null) {
      await _accountsRepository.recordSaleCancellation(
        saleId: sale.saleId,
        invoiceNumber: sale.invoiceNumber,
        cashAmount: sale.cashAmount,
        onlineAmount: sale.onlineAmount,
        grandTotal: sale.grandTotal,
        date: sale.date,
        userId: userId,
        reason: reason,
      );
    }
  }
}
