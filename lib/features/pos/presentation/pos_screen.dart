import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/sale_model.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../inventory/providers/inventory_provider.dart';
import '../providers/cart_provider.dart';
import 'widgets/sale_success_dialog.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _cashInputController = TextEditingController();
  final TextEditingController _onlineInputController = TextEditingController();
  final TextEditingController _custNameController = TextEditingController();
  final TextEditingController _custPhoneController = TextEditingController();

  String _selectedCategory = 'All';
  String _selectedType = 'All'; // 'All' | 'Oil' | 'Non-Oil'
  bool _isProcessingSale = false;
  String? _checkoutError;

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _cashInputController.dispose();
    _onlineInputController.dispose();
    _custNameController.dispose();
    _custPhoneController.dispose();
    super.dispose();
  }

  void _syncSplitInputs(CartState cart) {
    if (cart.paymentType == AppConstants.paymentSplit) {
      if (_cashInputController.text.isEmpty && _onlineInputController.text.isEmpty) {
        _cashInputController.text = cart.cashAmount.toString();
        _onlineInputController.text = cart.onlineAmount.toString();
      }
    }
  }

  Future<void> _handleCompleteSale(WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final user = ref.read(authStateProvider).asData?.value;

    if (!cart.canCheckout) {
      setState(() {
        _checkoutError = cart.items.isEmpty
            ? 'Cart is empty. Add products to complete sale.'
            : 'Payment split does not match Grand Total.';
      });
      return;
    }

    setState(() {
      _isProcessingSale = true;
      _checkoutError = null;
    });

    try {
      final repo = ref.read(salesRepositoryProvider);
      final now = DateTime.now();
      final todayStr = now.toIso8601String().split('T')[0];
      final invoiceNum = 'INV-${now.millisecondsSinceEpoch.toString().substring(7)}';

      final sale = SaleModel(
        saleId: 'sale_${now.millisecondsSinceEpoch}',
        invoiceNumber: invoiceNum,
        date: todayStr,
        timestamp: now,
        items: cart.items.map((i) => i.toSaleItem()).toList(),
        subtotal: cart.subtotal,
        discount: cart.discount,
        grandTotal: cart.grandTotal,
        paymentType: cart.paymentType,
        cashAmount: cart.cashAmount,
        onlineAmount: cart.onlineAmount,
        status: AppConstants.saleStatusCompleted,
        createdBy: user?.uid ?? 'staff',
        createdByName: user?.displayName ?? 'Sales Staff',
      );

      final confirmedSale = await repo.completeSale(
        sale,
        idempotencyKey: cart.idempotencyKey,
      );

      if (!mounted) return;

      _discountController.clear();
      _cashInputController.clear();
      _onlineInputController.clear();
      _custNameController.clear();
      _custPhoneController.clear();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => SaleSuccessDialog(sale: confirmedSale),
      );
    } catch (e) {
      setState(() {
        _checkoutError = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingSale = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    _syncSplitInputs(cart);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 720;
          return isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Product Selection & Catalog (60% width)
                    Expanded(
                      flex: 6,
                      child: _buildProductCatalogSection(context, ref),
                    ),
                    const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
                    // Right Column: Current Sale / Cart & Checkout (40% width)
                    Expanded(
                      flex: 4,
                      child: _buildCartSection(context, ref, cart),
                    ),
                  ],
                )
              : Stack(
                  children: [
                    _buildProductCatalogSection(context, ref),
                    if (cart.items.isNotEmpty)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: _buildMobileFloatingCartBar(context, ref, cart),
                      ),
                  ],
                );
        },
      ),
    );
  }

  // --- Left Catalog Section ---
  Widget _buildProductCatalogSection(BuildContext context, WidgetRef ref) {
    final productsRepo = ref.watch(inventoryRepositoryProvider);

    return StreamBuilder<List<ProductModel>>(
      stream: productsRepo.watchProducts(includeArchived: false),
      builder: (context, snapshot) {
        final allProducts = snapshot.data ?? [];

        // Extract categories
        final categories = {'All', ...allProducts.map((p) => p.category.trim())}.toList();

        // Filter products based on search, type, and category
        final query = _searchController.text.trim().toLowerCase();
        final filtered = allProducts.where((p) {
          if (_selectedType != 'All' && p.productType != _selectedType) return false;
          if (_selectedCategory != 'All' && p.category != _selectedCategory) return false;
          if (query.isNotEmpty) {
            final matchName = p.productName.toLowerCase().contains(query);
            final matchCode = p.productCode.toLowerCase().contains(query);
            if (!matchName && !matchCode) return false;
          }
          return true;
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search & Filter Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search products by name or code (e.g. OUD-101)...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Oil / Non-Oil Toggle
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'All', label: Text('All')),
                      ButtonSegment(value: AppConstants.productTypeOil, label: Text('Oils (ml)')),
                      ButtonSegment(value: AppConstants.productTypeNonOil, label: Text('Non-Oil')),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (val) {
                      setState(() => _selectedType = val.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Category Filter Pills
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Product Cards Grid
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted.withAlpha(128)),
                            const SizedBox(height: 12),
                            const Text('No matching products found in catalog.', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount = constraints.maxWidth > 900
                              ? 3
                              : (constraints.maxWidth > 500 ? 2 : 1);

                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.45,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              return _buildProductCard(context, ref, p);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, WidgetRef ref, ProductModel product) {
    final isOut = product.isOutOfStock;
    final isLow = product.isLowStock;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOut
              ? AppColors.danger.withAlpha(51)
              : (isLow ? AppColors.warning.withAlpha(76) : AppColors.border),
          width: isOut || isLow ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: isOut ? null : () => _showAddQuantityDialog(context, ref, product),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Category tag & SKU
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ),
                  Text(
                    product.productCode,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Product Name
              Text(
                product.productName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Bottom Row: Price & Stock indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.format(product.sellingPricePerUnit),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'per ${product.unit}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Stock pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isOut
                          ? AppColors.dangerLight
                          : (isLow ? AppColors.warningLight : AppColors.cashGreenLight),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOut ? Icons.block : (isLow ? Icons.warning_amber : Icons.check),
                          size: 12,
                          color: isOut
                              ? AppColors.danger
                              : (isLow ? AppColors.warning : AppColors.cashGreen),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOut ? 'Out of stock' : '${product.availableQuantity} ${product.unit}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isOut
                                ? AppColors.danger
                                : (isLow ? AppColors.warning : AppColors.cashGreen),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Right Cart Section ---
  Widget _buildCartSection(BuildContext context, WidgetRef ref, CartState cart) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cart Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Current Cart (${cart.items.length})',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (cart.items.isNotEmpty)
                TextButton.icon(
                  onPressed: () => ref.read(cartProvider.notifier).clearCart(),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.danger),
                  label: const Text('Clear', style: TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
            ],
          ),
          const Divider(height: 20),

          // Error alert
          if (_checkoutError != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _checkoutError!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Items List
          Expanded(
            child: cart.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.point_of_sale_rounded, size: 48, color: AppColors.textMuted.withAlpha(100)),
                        const SizedBox(height: 12),
                        const Text('No products in cart.', style: TextStyle(color: AppColors.textSecondary)),
                        const Text('Click any product in the catalog to add.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.borderLight),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _buildCartItemTile(context, ref, item);
                    },
                  ),
          ),
          const Divider(height: 16),

          // Pricing & Checkout Panel
          _buildPaymentAndCheckoutPanel(context, ref, cart),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(BuildContext context, WidgetRef ref, CartItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.productName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${CurrencyFormatter.format(item.unitPrice)} / ${item.product.unit}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          // Quantity Controls
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  final step = item.product.isOil ? 1.0 : 1.0;
                  ref.read(cartProvider.notifier).updateQuantity(item.product.productId, item.quantity - step);
                },
              ),
              InkWell(
                onTap: () => _showEditQuantityPopup(context, ref, item),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${item.quantity} ${item.product.unit}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  final step = item.product.isOil ? 1.0 : 1.0;
                  ref.read(cartProvider.notifier).updateQuantity(item.product.productId, item.quantity + step);
                },
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Total Item Price
          Text(
            CurrencyFormatter.format(item.totalPrice),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => ref.read(cartProvider.notifier).removeItem(item.product.productId),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentAndCheckoutPanel(BuildContext context, WidgetRef ref, CartState cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtotal & Discount Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Text(CurrencyFormatter.format(cart.subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 6),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Discount (₹):', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            SizedBox(
              width: 100,
              height: 32,
              child: TextField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  hintText: '0.00',
                ),
                onChanged: (val) {
                  final disc = double.tryParse(val.trim()) ?? 0.0;
                  ref.read(cartProvider.notifier).setDiscount(disc);
                },
              ),
            ),
          ],
        ),
        const Divider(height: 16),

        // Grand Total Banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Grand Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Flexible(
              child: Text(
                CurrencyFormatter.format(cart.grandTotal),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Payment Method Selector
        const Text('Payment Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPaymentTypeButton(
                label: 'Cash',
                icon: Icons.money_rounded,
                type: AppConstants.paymentCash,
                activeType: cart.paymentType,
                color: AppColors.cashGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPaymentTypeButton(
                label: 'Online',
                icon: Icons.credit_card_rounded,
                type: AppConstants.paymentOnline,
                activeType: cart.paymentType,
                color: AppColors.onlineBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildPaymentTypeButton(
                label: 'Split',
                icon: Icons.call_split_rounded,
                type: AppConstants.paymentSplit,
                activeType: cart.paymentType,
                color: AppColors.splitPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Split Inputs (when active)
        if (cart.paymentType == AppConstants.paymentSplit) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.splitPurpleLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.splitPurple.withAlpha(76)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Cash Part (₹):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _cashInputController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                            onChanged: (val) {
                              final cash = double.tryParse(val.trim()) ?? 0.0;
                              ref.read(cartProvider.notifier).setCashAmount(cash);
                              _onlineInputController.text = cart.onlineAmount.toString();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Online Part (₹):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _onlineInputController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                            onChanged: (val) {
                              final online = double.tryParse(val.trim()) ?? 0.0;
                              ref.read(cartProvider.notifier).setOnlineAmount(online);
                              _cashInputController.text = cart.cashAmount.toString();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  cart.isSplitValid
                      ? '✓ Cash (₹${cart.cashAmount}) + Online (₹${cart.onlineAmount}) = ₹${cart.grandTotal}'
                      : '⚠ Split must equal ₹${cart.grandTotal}. Current sum: ₹${cart.cashAmount + cart.onlineAmount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cart.isSplitValid ? AppColors.cashGreen : AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Complete Sale Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            onPressed: (_isProcessingSale || !cart.canCheckout)
                ? null
                : () => _handleCompleteSale(ref),
            child: _isProcessingSale
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    'Complete Sale • ${CurrencyFormatter.format(cart.grandTotal)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeButton({
    required String label,
    required IconData icon,
    required String type,
    required String activeType,
    required Color color,
  }) {
    final isSelected = activeType == type;

    return InkWell(
      onTap: () => ref.read(cartProvider.notifier).setPaymentType(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? color : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Add Quantity Dialog (Supports standard & decimal e.g. 2.5 ml, 5 ml, 10 ml, 25 ml) ---
  void _showAddQuantityDialog(BuildContext context, WidgetRef ref, ProductModel product) {
    final qtyController = TextEditingController(text: product.isOil ? '10' : '1');
    double selectedQty = product.isOil ? 10.0 : 1.0;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final unit = product.unit;
          final price = product.sellingPricePerUnit;
          final total = CurrencyFormatter.round(selectedQty * price);
          final isExceeded = selectedQty > product.availableQuantity;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.water_drop, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.productName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Stock: ${product.availableQuantity} $unit • ${CurrencyFormatter.format(price)} / $unit',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),

                // Quick Dose Pills (for Perfume Oil: 3ml, 6ml, 12ml / tola)
                if (product.isOil) ...[
                  const Text('Common Athar Doses:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [3.0, 6.0, 10.0, 12.0, 25.0].map((dose) {
                      return ActionChip(
                        label: Text('$dose ml'),
                        onPressed: () {
                          setDlgState(() {
                            selectedQty = dose;
                            qtyController.text = dose.toString();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Quantity Text Field
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Enter Quantity ($unit)',
                    prefixIcon: const Icon(Icons.scale_rounded, size: 20),
                    errorText: isExceeded ? 'Exceeds available stock (${product.availableQuantity} $unit)' : null,
                  ),
                  onChanged: (val) {
                    final parsed = double.tryParse(val.trim()) ?? 0.0;
                    setDlgState(() => selectedQty = parsed);
                  },
                ),
                const SizedBox(height: 16),

                // Total Preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Item Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyFormatter.format(total),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: (selectedQty <= 0 || isExceeded)
                    ? null
                    : () {
                        ref.read(cartProvider.notifier).addProduct(product, selectedQty);
                        Navigator.pop(dialogCtx);
                      },
                child: const Text('Add to Cart'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditQuantityPopup(BuildContext context, WidgetRef ref, CartItem item) {
    final qtyController = TextEditingController(text: item.quantity.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Quantity for ${item.product.productName}'),
        content: TextField(
          controller: qtyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Quantity (${item.product.unit})',
            hintText: 'Max ${item.product.availableQuantity}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQty = double.tryParse(qtyController.text.trim()) ?? 0.0;
              ref.read(cartProvider.notifier).updateQuantity(item.product.productId, newQty);
              Navigator.pop(ctx);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  // --- Mobile Floating Cart Bar ---
  Widget _buildMobileFloatingCartBar(BuildContext context, WidgetRef ref, CartState cart) {
    return Card(
      elevation: 8,
      color: AppColors.sidebarBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showMobileCartBottomSheet(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    '${cart.items.length} items (${cart.totalQuantity} total)',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    CurrencyFormatter.format(cart.grandTotal),
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMobileCartBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return Consumer(
          builder: (context, ref, _) {
            final cart = ref.watch(cartProvider);
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: _buildCartSection(context, ref, cart),
              ),
            );
          },
        );
      },
    );
  }
}
