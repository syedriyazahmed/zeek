import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/sale_model.dart';
import '../../../../services/invoice/invoice_service.dart';
import '../../providers/cart_provider.dart';

class SaleSuccessDialog extends ConsumerWidget {
  final SaleModel sale;

  const SaleSuccessDialog({super.key, required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.cashGreenLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.cashGreen,
                  size: 44,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sale Completed Successfully!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Invoice #${sale.invoiceNumber}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              Text(
                DateFormatter.formatDateTime(sale.timestamp),
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),

              // Transaction Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildRow('Items Sold', '${sale.items.length} items (${sale.totalQuantity} total qty)'),
                    const SizedBox(height: 8),
                    _buildRow('Subtotal', CurrencyFormatter.format(sale.subtotal)),
                    if (sale.discount > 0) ...[
                      const SizedBox(height: 8),
                      _buildRow('Discount Applied', '- ${CurrencyFormatter.format(sale.discount)}', isNegative: true),
                    ],
                    const Divider(height: 18),
                    _buildRow(
                      'Grand Total Paid',
                      CurrencyFormatter.format(sale.grandTotal),
                      isHighlight: true,
                    ),
                    const SizedBox(height: 12),
                    // Payment Allocation Breakdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                sale.paymentType == AppConstants.paymentCash
                                    ? Icons.money
                                    : (sale.paymentType == AppConstants.paymentOnline
                                        ? Icons.credit_card
                                        : Icons.call_split_rounded),
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Payment: ${sale.paymentType.toUpperCase()}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (sale.paymentType == AppConstants.paymentSplit)
                            Text(
                              'Cash: ${CurrencyFormatter.format(sale.cashAmount)} • Online: ${CurrencyFormatter.format(sale.onlineAmount)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.splitPurple),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons: Print Invoice / New Sale
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => InvoiceService.instance.printInvoice(sale),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Print Receipt / PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        ref.read(cartProvider.notifier).clearCart();
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Start New Sale'),
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

  Widget _buildRow(String label, String value, {bool isHighlight = false, bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHighlight ? 14 : 13,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 16 : 13,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isNegative
                ? AppColors.danger
                : (isHighlight ? AppColors.primaryDark : AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
