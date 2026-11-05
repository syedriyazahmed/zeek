import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/validators/app_validators.dart';
import '../../../../data/models/product_model.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';

class StockAdjustmentDialog extends ConsumerStatefulWidget {
  final ProductModel product;

  const StockAdjustmentDialog({super.key, required this.product});

  @override
  ConsumerState<StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends ConsumerState<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _newCountController;
  late TextEditingController _notesController;

  String _reasonCategory = 'Physical Count Audit';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _newCountController = TextEditingController(text: widget.product.availableQuantity.toString());
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _newCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _newCount => double.tryParse(_newCountController.text.trim()) ?? widget.product.availableQuantity;
  double get _difference => _newCount - widget.product.availableQuantity;

  Future<void> _submitAdjustment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_difference == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No change in stock quantity.')),
      );
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final user = ref.read(authStateProvider).asData?.value;
      final userId = user?.displayName ?? 'Admin';

      final reason = '$_reasonCategory: ${_notesController.text.trim().isNotEmpty ? _notesController.text.trim() : 'Stock count adjustment'}';

      await repo.adjustStock(
        productId: widget.product.productId,
        newQuantity: _newCount,
        reason: reason,
        userId: userId,
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _difference > 0 ? AppColors.cashGreen : AppColors.warning,
            content: Text(
              'Stock Adjusted: ${_difference > 0 ? "+$_difference" : "$_difference"} ${widget.product.unit}. New available: $_newCount ${widget.product.unit}',
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
    final diff = _difference;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.tune_rounded, color: AppColors.warning),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Physical Stock Adjustment',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Audit reconciliation with signed ledger trail',
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'SKU: ${widget.product.productCode}',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Current System Count', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              '${widget.product.availableQuantity} ${widget.product.unit}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

                  // New Physical Count
                  TextFormField(
                    controller: _newCountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => widget.product.unit == AppConstants.unitPiece
                        ? AppValidators.wholeNumber(v, 'Physical Count')
                        : AppValidators.nonNegativeNumber(v, 'Physical Count'),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'New Verified Physical Count (${widget.product.unit}) *',
                      hintText: 'Enter actual counted stock',
                      prefixIcon: const Icon(Icons.format_list_numbered, size: 20),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Difference Indicator Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: diff == 0
                          ? AppColors.background
                          : (diff > 0 ? AppColors.cashGreenLight : AppColors.dangerLight),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: diff == 0
                            ? AppColors.border
                            : (diff > 0 ? AppColors.cashGreen.withAlpha(76) : AppColors.danger.withAlpha(76)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Stock Movement Difference:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: diff == 0
                                ? AppColors.textSecondary
                                : (diff > 0 ? AppColors.cashGreen : AppColors.danger),
                          ),
                        ),
                        Text(
                          '${diff > 0 ? "+$diff" : "$diff"} ${widget.product.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: diff == 0
                                ? AppColors.textSecondary
                                : (diff > 0 ? AppColors.cashGreen : AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reason Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _reasonCategory,
                    decoration: const InputDecoration(
                      labelText: 'Adjustment Reason *',
                      prefixIcon: Icon(Icons.help_outline, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Physical Count Audit', child: Text('Physical Count Audit / Routine Check')),
                      DropdownMenuItem(value: 'Spillage / Leakage', child: Text('Spillage / Leakage')),
                      DropdownMenuItem(value: 'Evaporation', child: Text('Natural Evaporation (Oil)')),
                      DropdownMenuItem(value: 'Damaged Goods', child: Text('Damaged / Broken Bottle')),
                      DropdownMenuItem(value: 'Tester / Customer Sample', child: Text('Shop Tester / Customer Sample')),
                      DropdownMenuItem(value: 'Other Adjustment', child: Text('Other Reason')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _reasonCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Detail Note
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Audit Note / Explanation (Optional)',
                      hintText: 'e.g. Broken 100ml beaker during stock refilling',
                      prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                        onPressed: _isLoading ? null : _submitAdjustment,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Commit Adjustment'),
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

