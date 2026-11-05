import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../data/models/product_model.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../vendors/providers/vendor_provider.dart';
import '../../providers/inventory_provider.dart';

class AddEditProductDialog extends ConsumerStatefulWidget {
  final ProductModel? product;
  final String defaultProductType;

  const AddEditProductDialog({
    super.key,
    this.product,
    this.defaultProductType = AppConstants.productTypeOil,
  });

  @override
  ConsumerState<AddEditProductDialog> createState() => _AddEditProductDialogState();
}

class _AddEditProductDialogState extends ConsumerState<AddEditProductDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _categoryController;
  late TextEditingController _sellingPriceController;
  late TextEditingController _vendorPriceController;
  late TextEditingController _quantityController;
  late TextEditingController _thresholdController;

  late String _productType;
  late String _unit;
  String? _selectedVendorId;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _productType = p?.productType ?? widget.defaultProductType;
    _unit = p?.unit ?? (_productType == AppConstants.productTypeOil ? AppConstants.unitMl : AppConstants.unitPiece);
    _selectedVendorId = p?.vendorId;

    _nameController = TextEditingController(text: p?.productName ?? '');
    _codeController = TextEditingController(text: p?.productCode ?? '');
    _categoryController = TextEditingController(text: p?.category ?? 'General');
    _sellingPriceController = TextEditingController(text: p != null ? p.sellingPricePerUnit.toString() : '');
    _vendorPriceController = TextEditingController(text: p != null ? p.vendorPricePerUnit.toString() : '0');
    _quantityController = TextEditingController(text: p != null ? p.availableQuantity.toString() : '0');
    _thresholdController = TextEditingController(text: p != null ? p.lowStockThreshold.toString() : '10');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _categoryController.dispose();
    _sellingPriceController.dispose();
    _vendorPriceController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final user = ref.read(authStateProvider).asData?.value;
      final userId = user?.uid ?? 'admin';

      final code = _codeController.text.trim().toUpperCase();

      // Check code uniqueness when creating or changing code
      if (!isEditing || widget.product!.productCode != code) {
        final existing = await repo.getProductByCode(code);
        if (existing != null) {
          throw Exception('Product code "$code" is already used by "${existing.productName}".');
        }
      }

      final now = DateTime.now();
      final sellingPrice = double.parse(_sellingPriceController.text.trim());
      final vendorPrice = double.tryParse(_vendorPriceController.text.trim()) ?? 0.0;
      final quantity = double.tryParse(_quantityController.text.trim()) ?? 0.0;
      final threshold = double.tryParse(_thresholdController.text.trim()) ?? 10.0;

      if (isEditing) {
        final updated = widget.product!.copyWith(
          productName: _nameController.text.trim(),
          normalizedName: _nameController.text.trim().toLowerCase(),
          productCode: code,
          productType: _productType,
          category: _categoryController.text.trim(),
          unit: _unit,
          vendorId: _selectedVendorId,
          sellingPricePerUnit: sellingPrice,
          vendorPricePerUnit: vendorPrice,
          lowStockThreshold: threshold,
          updatedAt: now,
        );
        await repo.updateProduct(updated);
      } else {
        final newProduct = ProductModel(
          productId: 'prod_${DateTime.now().millisecondsSinceEpoch}',
          productName: _nameController.text.trim(),
          normalizedName: _nameController.text.trim().toLowerCase(),
          productCode: code,
          productType: _productType,
          category: _categoryController.text.trim(),
          unit: _unit,
          vendorId: _selectedVendorId,
          totalPurchased: quantity,
          totalSold: 0.0,
          availableQuantity: quantity,
          vendorPricePerUnit: vendorPrice,
          sellingPricePerUnit: sellingPrice,
          lowStockThreshold: threshold,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await repo.addProduct(newProduct, userId: userId);
      }

      if (mounted) {
        Navigator.pop(context, true);
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
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.add_box_rounded,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isEditing ? 'Edit Product' : 'Add New Product',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.danger.withAlpha(76)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppColors.danger, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Product Type & Unit Selection
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _productType,
                          decoration: const InputDecoration(labelText: 'Product Type'),
                          items: const [
                            DropdownMenuItem(value: AppConstants.productTypeOil, child: Text('Oil (Athar / Ittar)')),
                            DropdownMenuItem(value: AppConstants.productTypeNonOil, child: Text('Non-Oil (Sprays/Bottles)')),
                          ],
                          onChanged: isEditing
                              ? null
                              : (val) {
                                  if (val != null) {
                                    setState(() {
                                      _productType = val;
                                      _unit = val == AppConstants.productTypeOil ? AppConstants.unitMl : AppConstants.unitPiece;
                                    });
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _unit,
                          decoration: const InputDecoration(labelText: 'Unit of Measure'),
                          items: [
                            DropdownMenuItem(value: _unit, child: Text(_unit)),
                            if (_unit != AppConstants.unitMl)
                              const DropdownMenuItem(value: AppConstants.unitMl, child: Text('ml')),
                            if (_unit != AppConstants.unitPiece)
                              const DropdownMenuItem(value: AppConstants.unitPiece, child: Text('piece')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _unit = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Product Name
                  TextFormField(
                    controller: _nameController,
                    validator: (v) => AppValidators.requiredField(v, 'Product Name is required'),
                    decoration: const InputDecoration(
                      labelText: 'Product Name *',
                      hintText: 'e.g. Oud Cambodi Royal',
                      prefixIcon: Icon(Icons.label_outline, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product Code & Category
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _codeController,
                          validator: (v) => AppValidators.requiredField(v, 'SKU/Code is required'),
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Product Code / SKU *',
                            hintText: 'e.g. OUD-101',
                            prefixIcon: Icon(Icons.qr_code, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            hintText: 'e.g. Oud, Musk, Floral',
                            prefixIcon: Icon(Icons.category_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Pricing: Selling Price & Vendor Cost
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sellingPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => AppValidators.positiveNumber(v, 'Selling Price'),
                          decoration: InputDecoration(
                            labelText: 'Selling Price (per $_unit) *',
                            hintText: '0.00',
                            prefixText: '${AppConstants.currencySymbol} ',
                            prefixIcon: const Icon(Icons.sell_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _vendorPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => AppValidators.nonNegativeNumber(v, 'Vendor Price'),
                          decoration: InputDecoration(
                            labelText: 'Vendor Price (per $_unit)',
                            hintText: '0.00',
                            prefixText: '${AppConstants.currencySymbol} ',
                            prefixIcon: const Icon(Icons.monetization_on_outlined, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Stock & Threshold
                  Row(
                    children: [
                      if (!isEditing) ...[
                        Expanded(
                          child: TextFormField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (v) => _unit == AppConstants.unitPiece
                                ? AppValidators.wholeNumber(v, 'Initial Stock')
                                : AppValidators.nonNegativeNumber(v, 'Initial Stock'),
                            decoration: InputDecoration(
                              labelText: 'Initial Opening Stock ($_unit)',
                              hintText: '0',
                              prefixIcon: const Icon(Icons.inventory, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: TextFormField(
                          controller: _thresholdController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (v) => AppValidators.nonNegativeNumber(v, 'Threshold'),
                          decoration: InputDecoration(
                            labelText: 'Low Stock Alert Threshold ($_unit)',
                            hintText: '10',
                            prefixIcon: const Icon(Icons.warning_amber_rounded, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Vendor Selector
                  vendorsAsync.when(
                    data: (vendors) {
                      return DropdownButtonFormField<String?>(
                        initialValue: _selectedVendorId,
                        decoration: const InputDecoration(
                          labelText: 'Preferred Vendor (Optional)',
                          prefixIcon: Icon(Icons.business_outlined, size: 20),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('No Vendor Assigned'),
                          ),
                          ...vendors.map((v) => DropdownMenuItem(
                                value: v.vendorId,
                                child: Text('${v.vendorName} (${v.companyName.isNotEmpty ? v.companyName : 'Direct'})'),
                              )),
                        ],
                        onChanged: (val) => setState(() => _selectedVendorId = val),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 28),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _saveProduct,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(isEditing ? 'Save Changes' : 'Create Product'),
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

