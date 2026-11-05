import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_item_model.dart';
import '../../../data/repositories/sales_repository.dart';
import '../../accounts/providers/accounts_provider.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../inventory/providers/inventory_provider.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  final inventoryRepo = ref.watch(inventoryRepositoryProvider);
  final accountsRepo = ref.watch(accountsRepositoryProvider);
  return FirebaseSalesRepository(
    firebaseService,
    inventoryRepo,
    accountsRepository: accountsRepo,
  );
});

class CartItem {
  final ProductModel product;
  final double quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  double get unitPrice => product.sellingPricePerUnit;
  double get totalPrice => CurrencyFormatter.round(quantity * unitPrice);

  SaleItemModel toSaleItem() {
    return SaleItemModel(
      productId: product.productId,
      productName: product.productName,
      productType: product.productType,
      quantity: quantity,
      unit: product.unit,
      unitPrice: unitPrice,
      unitCostAtSale: product.vendorPricePerUnit,
      totalPrice: totalPrice,
    );
  }

  CartItem copyWith({ProductModel? product, double? quantity}) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }
}

class CartState {
  final List<CartItem> items;
  final double discount;
  final String paymentType; // 'cash' | 'online' | 'split'
  final double cashAmount;
  final double onlineAmount;
  final String customerName;
  final String customerPhone;
  final String idempotencyKey;

  const CartState({
    this.items = const [],
    this.discount = 0.0,
    this.paymentType = AppConstants.paymentCash,
    this.cashAmount = 0.0,
    this.onlineAmount = 0.0,
    this.customerName = '',
    this.customerPhone = '',
    required this.idempotencyKey,
  });

  double get subtotal {
    final sum = items.fold<double>(0.0, (acc, item) => acc + item.totalPrice);
    return CurrencyFormatter.round(sum);
  }

  double get grandTotal {
    final total = subtotal - discount;
    return CurrencyFormatter.round(total < 0 ? 0.0 : total);
  }

  double get totalQuantity {
    return items.fold<double>(0.0, (acc, item) => acc + item.quantity);
  }

  bool get isSplitValid {
    if (paymentType != AppConstants.paymentSplit) return true;
    return (cashAmount + onlineAmount - grandTotal).abs() <= 0.01;
  }

  bool get canCheckout {
    return items.isNotEmpty && grandTotal >= 0 && isSplitValid;
  }

  CartState copyWith({
    List<CartItem>? items,
    double? discount,
    String? paymentType,
    double? cashAmount,
    double? onlineAmount,
    String? customerName,
    String? customerPhone,
    String? idempotencyKey,
  }) {
    return CartState(
      items: items ?? this.items,
      discount: discount ?? this.discount,
      paymentType: paymentType ?? this.paymentType,
      cashAmount: cashAmount ?? this.cashAmount,
      onlineAmount: onlineAmount ?? this.onlineAmount,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return CartState(idempotencyKey: const Uuid().v4());
  }

  void addProduct(ProductModel product, [double quantity = 1.0]) {
    final existingIndex = state.items.indexWhere((i) => i.product.productId == product.productId);

    List<CartItem> newItems;
    if (existingIndex != -1) {
      final currentItem = state.items[existingIndex];
      final newQty = currentItem.quantity + quantity;

      // Enforce available stock boundary
      final clampedQty = newQty > product.availableQuantity ? product.availableQuantity : newQty;

      newItems = List.from(state.items);
      newItems[existingIndex] = currentItem.copyWith(quantity: clampedQty);
    } else {
      if (product.availableQuantity <= 0) return;
      final initialQty = quantity > product.availableQuantity ? product.availableQuantity : quantity;
      newItems = [...state.items, CartItem(product: product, quantity: initialQty)];
    }

    _updateStateWithAutoPayment(items: newItems);
  }

  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final newItems = state.items.map((item) {
      if (item.product.productId == productId) {
        final clamped = quantity > item.product.availableQuantity
            ? item.product.availableQuantity
            : quantity;
        return item.copyWith(quantity: clamped);
      }
      return item;
    }).toList();

    _updateStateWithAutoPayment(items: newItems);
  }

  void removeItem(String productId) {
    final newItems = state.items.where((i) => i.product.productId != productId).toList();
    _updateStateWithAutoPayment(items: newItems);
  }

  void setDiscount(double discount) {
    final safeDiscount = discount < 0 ? 0.0 : CurrencyFormatter.round(discount);
    _updateStateWithAutoPayment(discount: safeDiscount);
  }

  void setPaymentType(String type) {
    final gt = state.grandTotal;
    if (type == AppConstants.paymentCash) {
      state = state.copyWith(paymentType: type, cashAmount: gt, onlineAmount: 0.0);
    } else if (type == AppConstants.paymentOnline) {
      state = state.copyWith(paymentType: type, cashAmount: 0.0, onlineAmount: gt);
    } else {
      // Split payment: default half-and-half or current
      final half = CurrencyFormatter.round(gt / 2);
      state = state.copyWith(
        paymentType: type,
        cashAmount: half,
        onlineAmount: CurrencyFormatter.round(gt - half),
      );
    }
  }

  void setCashAmount(double cash) {
    final safeCash = CurrencyFormatter.round(cash < 0 ? 0 : cash);
    final remainingOnline = CurrencyFormatter.round(state.grandTotal - safeCash);
    state = state.copyWith(
      cashAmount: safeCash,
      onlineAmount: remainingOnline < 0 ? 0 : remainingOnline,
    );
  }

  void setOnlineAmount(double online) {
    final safeOnline = CurrencyFormatter.round(online < 0 ? 0 : online);
    final remainingCash = CurrencyFormatter.round(state.grandTotal - safeOnline);
    state = state.copyWith(
      cashAmount: remainingCash < 0 ? 0 : remainingCash,
      onlineAmount: safeOnline,
    );
  }

  void setCustomerInfo({String? name, String? phone}) {
    state = state.copyWith(
      customerName: name ?? state.customerName,
      customerPhone: phone ?? state.customerPhone,
    );
  }

  void clearCart() {
    state = CartState(idempotencyKey: const Uuid().v4());
  }

  void _updateStateWithAutoPayment({List<CartItem>? items, double? discount}) {
    final currentItems = items ?? state.items;
    final currentDiscount = discount ?? state.discount;

    final sub = currentItems.fold<double>(0.0, (acc, item) => acc + item.totalPrice);
    final gt = CurrencyFormatter.round((sub - currentDiscount) < 0 ? 0.0 : (sub - currentDiscount));

    double newCash = state.cashAmount;
    double newOnline = state.onlineAmount;

    if (state.paymentType == AppConstants.paymentCash) {
      newCash = gt;
      newOnline = 0.0;
    } else if (state.paymentType == AppConstants.paymentOnline) {
      newCash = 0.0;
      newOnline = gt;
    } else {
      // Re-balance split if grand total changed
      if (newCash > gt) {
        newCash = gt;
        newOnline = 0.0;
      } else {
        newOnline = CurrencyFormatter.round(gt - newCash);
      }
    }

    state = state.copyWith(
      items: currentItems,
      discount: currentDiscount,
      cashAmount: newCash,
      onlineAmount: newOnline,
    );
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(() {
  return CartNotifier();
});
