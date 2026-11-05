import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../data/models/product_model.dart';
import '../../../../data/models/purchase_model.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../vendors/providers/vendor_provider.dart';
import '../../providers/inventory_provider.dart';

class StockPurchaseDialog extends ConsumerStatefulWidget {
  final ProductModel product;

  const StockPurchaseDialog({super.key, required this.product});

  @override
  ConsumerState<StockPurchaseDialog> createState() => _StockPurchaseDialogState();
}

class _StockPurchaseDialogState extends ConsumerState<StockPurchaseDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _notesController;

  String? _selectedVendorId;
  String? _selectedVendorName;
  DateTime _purchaseDate = DateTime.now();
  String _paymentMethod = 'cash';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedVendorId = widget.product.vendorId;
    _quantityController = TextEditingController();
    _priceController = TextEditingController(
      text: widget.product.vendorPricePerUnit > 0
          ? widget.product.vendorPricePerUnit.toString()
          : '',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _calculatedTotal {
    final qty = double.tryParse(_quantityController.text.trim()) ?? 0.0;
    final price = double.tryParse(_priceController.text.trim()) ?? 0.0;
    return CurrencyFormatter.round(qty * price);
  }

  Future<void> _recordPurchase() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final user = ref.read(authStateProvider).asData?.value;
      final userId = user?.uid ?? 'admin';

      final qty = double.parse(_quantityController.text.trim());
      final price = double.parse(_priceController.text.trim());
      final total = CurrencyFormatter.round(qty * price);

      final purchase = PurchaseModel(
        purchaseId: 'pur_${DateTime.now().millisecondsSinceEpoch}',
        vendorId: _selectedVendorId ?? '',
        vendorName: _selectedVendorName ?? 'Direct Purchase',
        purchaseDate: _purchaseDate,
        productId: widget.product.productId,
        productName: widget.product.productName,
        purchasedQuantity: qty,
        unit: widget.product.unit,
        purchasePricePerUnit: price,
        totalAmount: total,
        paymentMethod: _paymentMethod,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      await repo.recordPurchase(purchase);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cashGreen,
            content: Text(
              'Stock In Recorded: +$qty ${widget.product.unit} of ${widget.product.productName}. New available stock: ${widget.product.availableQuantity + qty} ${widget.product.unit}',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vendorsAsync = ref.watch(vendorsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.cashGreenLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_shopping_cart_rounded, color: AppColors.cashGreen),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record Stock Purchase / Stock In',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Increase inventory & register vendor purchase',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Product Info Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.productName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Code: ${widget.product.productCode} • Type: ${widget.product.productType}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Current Stock', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              '${widget.product.availableQuantity} ${widget.product.unit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger.withAlpha(76)),
                      ),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Vendor Dropdown
                  vendorsAsync.when(
                    data: (vendors) {
                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedVendorId,
                        decoration: const InputDecoration(
                          labelText: 'Select Vendor *',
                          prefixIcon: Icon(Icons.business_outlined, size: 20),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Please select a vendor' : null,
                        items: vendors.map((v) {
                          return DropdownMenuItem(
                            value: v.vendorId,
                            child: Text('${v.vendorName} (${v.companyName})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedVendorId = val;
                            final match = vendors.where((v) => v.vendorId == val);
                            _selectedVendorName = match.isNotEmpty ? match.first.vendorName : null;
                          });
                        },
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),

                  // Quantity & Purchase Price
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => widget.product.unit == AppConstants.unitPiece
                              ? AppValidators.wholeNumber(v, 'Purchased Quantity')
                              : AppValidators.positiveNumber(v, 'Purchased Quantity'),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Purchased Quantity (${widget.product.unit}) *',
                            hintText: 'e.g. 500',
                            prefixIcon: const Icon(Icons.add_box_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => AppValidators.positiveNumber(v, 'Cost Price per Unit'),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Purchase Price (per ${widget.product.unit}) *',
                            prefixText: '${AppConstants.currencySymbol} ',
                            prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Purchase Date & Payment Method
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _purchaseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _purchaseDate = picked);
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Purchase Date',
                              prefixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                            ),
                            child: Text(DateFormatter.formatDate(_purchaseDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _paymentMethod,
                          decoration: const InputDecoration(labelText: 'Payment Status'),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Paid via Cash')),
                            DropdownMenuItem(value: 'online', child: Text('Paid via Online/Bank')),
                            DropdownMenuItem(value: 'unpaid', child: Text('Credit / Unpaid')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _paymentMethod = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Purchase Notes / Invoice Ref (Optional)',
                      hintText: 'e.g. Batch #44 from Ajmal Deira',
                      prefixIcon: Icon(Icons.notes, size: 20),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Total Calculated Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withAlpha(76)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Purchase Cost:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          CurrencyFormatter.format(_calculatedTotal),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.cashGreen),
                        onPressed: _isLoading ? null : _recordPurchase,
                        icon: _isLoading
                            ? const SizedBox.shrink()
                            : const Icon(Icons.check_circle_outline, size: 18),
                        label: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Confirm Purchase & Inward Stock'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

