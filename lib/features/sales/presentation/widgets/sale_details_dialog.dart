import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/sale_model.dart';
import '../../../../services/invoice/invoice_service.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../../pos/providers/cart_provider.dart';

class SaleDetailsDialog extends ConsumerStatefulWidget {
  final SaleModel sale;

  const SaleDetailsDialog({
    super.key,
    required this.sale,
  });

  @override
  ConsumerState<SaleDetailsDialog> createState() => _SaleDetailsDialogState();
}

class _SaleDetailsDialogState extends ConsumerState<SaleDetailsDialog> {
  bool _isCancelling = false;
  bool _isPrinting = false;

  Future<void> _printInvoice() async {
    setState(() => _isPrinting = true);
    try {
      await InvoiceService.instance.printInvoice(widget.sale);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleCancelSale() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Cancel Sale Transaction'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel Invoice #${widget.sale.invoiceNumber} (${CurrencyFormatter.format(widget.sale.grandTotal)})?',
              ),
              const SizedBox(height: 12),
              const Text(
                'This will restore all item stocks to inventory and record a refund in the account ledger.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Reason *',
                  hintText: 'e.g. Customer returned goods / Wrong bill',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter reason' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Back')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.uid ?? 'admin';
      final salesRepo = ref.read(salesRepositoryProvider);

      await salesRepo.cancelSale(
        widget.sale.saleId,
        reasonController.text.trim(),
        userId,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sale #${widget.sale.invoiceNumber} has been successfully cancelled and stock restored.'),
            backgroundColor: AppColors.warning,
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
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final isCancelled = sale.isCancelled;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isCancelled ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isCancelled ? Icons.cancel_outlined : Icons.receipt_long_rounded,
                          color: isCancelled ? AppColors.error : AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice #${sale.invoiceNumber}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormatter.formatDateTime(sale.timestamp),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
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

              // Status Banner
              if (isCancelled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.cancel_rounded, color: AppColors.error, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'TRANSACTION CANCELLED / REFUNDED',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${sale.cancellationReason ?? 'Not specified'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (sale.cancelledAt != null)
                        Text(
                          'Cancelled on ${DateFormatter.formatDateTime(sale.cancelledAt!)} by ${sale.cancelledBy}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'COMPLETED SALE',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Staff & Payment Mode Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cashier / Staff:', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        Text(
                          sale.createdByName ?? sale.createdBy,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Payment Mode:', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: sale.paymentType == AppConstants.paymentSplit
                                ? AppColors.splitPurple.withValues(alpha: 0.1)
                                : (sale.paymentType == AppConstants.paymentCash
                                    ? AppColors.cashGreen.withValues(alpha: 0.1)
                                    : AppColors.onlineBlue.withValues(alpha: 0.1)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sale.paymentType.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: sale.paymentType == AppConstants.paymentSplit
                                  ? AppColors.splitPurple
                                  : (sale.paymentType == AppConstants.paymentCash
                                      ? AppColors.cashGreen
                                      : AppColors.onlineBlue),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Items Table
              const Text('Items Sold', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: const Row(
                        children: [
                          Expanded(flex: 4, child: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Expanded(flex: 2, child: Text('Unit / Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Expanded(flex: 2, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                          Expanded(flex: 2, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ...sale.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                item.productName,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${item.quantity} ${item.unit}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                CurrencyFormatter.format(item.unitPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                CurrencyFormatter.format(item.totalPrice),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Financial Totals
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 260,
                  child: Column(
                    children: [
                      _summaryRow('Subtotal:', CurrencyFormatter.format(sale.subtotal)),
                      if (sale.discount > 0)
                        _summaryRow('Discount:', '- ${CurrencyFormatter.format(sale.discount)}', color: AppColors.error),
                      const Divider(height: 12),
                      _summaryRow(
                        'Grand Total:',
                        CurrencyFormatter.format(sale.grandTotal),
                        isBold: true,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                      if (sale.paymentType == AppConstants.paymentSplit) ...[
                        const SizedBox(height: 6),
                        _summaryRow('Cash Paid:', CurrencyFormatter.format(sale.cashAmount), fontSize: 11),
                        _summaryRow('Online Paid:', CurrencyFormatter.format(sale.onlineAmount), fontSize: 11),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel Sale button (only if not cancelled)
                  if (!isCancelled)
                    TextButton.icon(
                      onPressed: _isCancelling ? null : _handleCancelSale,
                      icon: _isCancelling
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancel Sale'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    )
                  else
                    const SizedBox.shrink(),

                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isPrinting ? null : _printInvoice,
                        icon: _isPrinting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print Invoice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, double fontSize = 12, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

