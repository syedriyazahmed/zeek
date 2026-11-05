import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/expense_model.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../providers/accounts_provider.dart';

class AddExpenseDialog extends ConsumerStatefulWidget {
  const AddExpenseDialog({super.key});

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();

  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _cashController = TextEditingController();
  final _onlineController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _category = 'Packaging';
  String _paymentMethod = AppConstants.paymentCash;
  DateTime _expenseDate = DateTime.now();
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Packaging',
    'Rent',
    'Electricity',
    'Tea / Refreshment',
    'Staff Salary / Advance',
    'Courier & Shipping',
    'Shop Maintenance',
    'Marketing / Advertising',
    'Stationery & Printing',
    'Other Misc',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    _cashController.dispose();
    _onlineController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTotalAmountChanged(String val) {
    final amount = double.tryParse(val) ?? 0.0;
    if (_paymentMethod == AppConstants.paymentCash) {
      _cashController.text = amount > 0 ? amount.toStringAsFixed(2) : '';
      _onlineController.text = '0.00';
    } else if (_paymentMethod == AppConstants.paymentOnline) {
      _cashController.text = '0.00';
      _onlineController.text = amount > 0 ? amount.toStringAsFixed(2) : '';
    } else {
      // Split
      _cashController.text = (amount / 2).toStringAsFixed(2);
      _onlineController.text = (amount / 2).toStringAsFixed(2);
    }
    setState(() {});
  }

  void _onPaymentMethodChanged(String method) {
    setState(() {
      _paymentMethod = method;
      final total = double.tryParse(_amountController.text) ?? 0.0;
      if (method == AppConstants.paymentCash) {
        _cashController.text = total > 0 ? total.toStringAsFixed(2) : '';
        _onlineController.text = '0.00';
      } else if (method == AppConstants.paymentOnline) {
        _cashController.text = '0.00';
        _onlineController.text = total > 0 ? total.toStringAsFixed(2) : '';
      } else {
        _cashController.text = (total / 2).toStringAsFixed(2);
        _onlineController.text = (total / 2).toStringAsFixed(2);
      }
    });
  }

  void _onCashChanged(String val) {
    if (_paymentMethod == AppConstants.paymentSplit) {
      final total = double.tryParse(_amountController.text) ?? 0.0;
      final cash = double.tryParse(val) ?? 0.0;
      final remaining = (total - cash).clamp(0.0, total);
      _onlineController.text = remaining.toStringAsFixed(2);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final total = double.tryParse(_amountController.text) ?? 0.0;
    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final online = double.tryParse(_onlineController.text) ?? 0.0;

    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense amount must be greater than zero.')),
      );
      return;
    }

    if ((cash + online - total).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Allocation mismatch: Cash (₹$cash) + Online (₹$online) != Total (₹$total)',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.uid ?? 'admin';
      final accountsRepo = ref.read(accountsRepositoryProvider);

      final expense = ExpenseModel(
        expenseId: 'exp_${const Uuid().v4().substring(0, 8)}',
        date: DateFormatter.toIsoDate(_expenseDate),
        reason: _reasonController.text.trim(),
        category: _category,
        totalAmount: CurrencyFormatter.round(total),
        paymentMethod: _paymentMethod,
        cashAmount: CurrencyFormatter.round(cash),
        onlineAmount: CurrencyFormatter.round(online),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        createdBy: userId,
        createdAt: DateTime.now(),
      );

      await accountsRepo.addExpense(expense);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense of ${CurrencyFormatter.format(total)} recorded successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, color: AppColors.error, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Record Expense',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date & Category Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _expenseDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _expenseDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Expense Date',
                            prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: Text(DateFormatter.toIsoDate(_expenseDate)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _categories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _category = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Reason / Item
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Expense Purpose / Title *',
                    hintText: 'e.g. 100 Athar gift boxes, counter broom, tea',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter purpose' : null,
                ),
                const SizedBox(height: 14),

                // Total Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Total Amount (₹) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                  onChanged: _onTotalAmountChanged,
                  validator: (v) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d <= 0) return 'Enter valid amount > 0';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Payment Method Selector
                const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _paymentTypeChoice(
                        title: 'Cash',
                        icon: Icons.money_rounded,
                        type: AppConstants.paymentCash,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _paymentTypeChoice(
                        title: 'Online',
                        icon: Icons.credit_card_rounded,
                        type: AppConstants.paymentOnline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _paymentTypeChoice(
                        title: 'Split',
                        icon: Icons.call_split_rounded,
                        type: AppConstants.paymentSplit,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Split Allocation Fields (visible if Split)
                if (_paymentMethod == AppConstants.paymentSplit) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cashController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Cash Paid (₹)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: _onCashChanged,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _onlineController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Online Paid (₹)',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Notes / Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Remarks / Voucher Ref (Optional)',
                    hintText: 'e.g. Receipt #882 from Metro Traders',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isSubmitting ? 'Recording...' : 'Save Expense'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentTypeChoice({
    required String title,
    required IconData icon,
    required String type,
  }) {
    final isSelected = _paymentMethod == type;
    return InkWell(
      onTap: () => _onPaymentMethodChanged(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary, size: 20),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
