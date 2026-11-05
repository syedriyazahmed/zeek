import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../providers/accounts_provider.dart';

class SetOpeningBalanceDialog extends ConsumerStatefulWidget {
  final String date;
  final double currentCashOpening;
  final double currentOnlineOpening;

  const SetOpeningBalanceDialog({
    super.key,
    required this.date,
    required this.currentCashOpening,
    required this.currentOnlineOpening,
  });

  @override
  ConsumerState<SetOpeningBalanceDialog> createState() => _SetOpeningBalanceDialogState();
}

class _SetOpeningBalanceDialogState extends ConsumerState<SetOpeningBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cashController;
  late final TextEditingController _onlineController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(text: widget.currentCashOpening.toStringAsFixed(2));
    _onlineController = TextEditingController(text: widget.currentOnlineOpening.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _cashController.dispose();
    _onlineController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final online = double.tryParse(_onlineController.text) ?? 0.0;

    if (cash < 0 || online < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Balances cannot be negative.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.uid ?? 'admin';
      final accountsRepo = ref.read(accountsRepositoryProvider);

      await accountsRepo.setOpeningBalance(
        date: widget.date,
        cashOpening: cash,
        onlineOpening: online,
        userId: userId,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Opening balances saved for ${widget.date}: Cash: ${CurrencyFormatter.format(cash)}, Bank: ${CurrencyFormatter.format(online)}',
            ),
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
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
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
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Set Opening Balance (${widget.date})',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Set the opening float at start of the day. Closing balances will automatically recalculate with sales and expenses.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Cash Opening
                TextFormField(
                  controller: _cashController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cash Opening Float (₹) *',
                    hintText: 'e.g. 2000.00',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.money_rounded),
                  ),
                  validator: (v) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d < 0) return 'Enter valid balance >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Online/Bank Opening
                TextFormField(
                  controller: _onlineController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Bank / Online Opening Balance (₹) *',
                    hintText: 'e.g. 10000.00',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_rounded),
                  ),
                  validator: (v) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d < 0) return 'Enter valid balance >= 0';
                    return null;
                  },
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
                    ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(_isSubmitting ? 'Saving...' : 'Save Balances'),
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
}

