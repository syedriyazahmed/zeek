import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../providers/stock_sold_provider.dart';

class ProductSalesDrillDownDialog extends StatelessWidget {
  final ProductSaleAggregate aggregate;

  const ProductSalesDrillDownDialog({
    super.key,
    required this.aggregate,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
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
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aggregate.productName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'SKU: ${aggregate.productCode} • Category: ${aggregate.category} • ${aggregate.productType}',
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

              // Metric Cards Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metricItem('Sold Qty', '${aggregate.soldQuantity} ${aggregate.unit}', AppColors.primary),
                    _metricItem('In Stock', '${aggregate.availableQuantity} ${aggregate.unit}', AppColors.secondary),
                    _metricItem('Total Revenue', CurrencyFormatter.format(aggregate.totalRevenue), AppColors.success),
                    _metricItem('COGS', CurrencyFormatter.format(aggregate.totalCogs), AppColors.textSecondary),
                    _metricItem('Gross Profit', CurrencyFormatter.format(aggregate.grossProfit), AppColors.cashGreen),
                    _metricItem('Margin', '${aggregate.marginPercent}%', AppColors.primaryDark),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Occurrences list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transaction History (${aggregate.occurrences.length} sales)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (aggregate.occurrences.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No sales recorded for this product in the selected period.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: aggregate.occurrences.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final occ = aggregate.occurrences[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              // Invoice #
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '#${occ.invoiceNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              // Date & Time
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${occ.date} ${DateFormatter.formatTime(occ.timestamp)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                              // Qty & Rate
                              Expanded(
                                flex: 2,
                                child: Text(
                                  '${occ.quantity} ${occ.unit} @ ${CurrencyFormatter.format(occ.unitPrice)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              // Total Price
                              Expanded(
                                flex: 2,
                                child: Text(
                                  CurrencyFormatter.format(occ.totalPrice),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                                ),
                              ),
                              // Cashier
                              Expanded(
                                flex: 2,
                                child: Text(
                                  occ.cashier,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 18),

              // Close Action
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

