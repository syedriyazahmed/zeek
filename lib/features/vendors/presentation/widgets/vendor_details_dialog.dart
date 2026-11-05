import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/purchase_model.dart';
import '../../../../data/models/vendor_model.dart';
import '../../../inventory/providers/inventory_provider.dart';

class VendorDetailsDialog extends ConsumerWidget {
  final VendorModel vendor;

  const VendorDetailsDialog({super.key, required this.vendor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryRepo = ref.watch(inventoryRepositoryProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.business_rounded, color: AppColors.primaryDark, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vendor.vendorName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          if (vendor.companyName.isNotEmpty)
                            Text(
                              vendor.companyName,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
              const SizedBox(height: 18),

              // Contact Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    if (vendor.phoneNumber.isNotEmpty) ...[
                      const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(vendor.phoneNumber, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 20),
                    ],
                    if (vendor.address.isNotEmpty) ...[
                      const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          vendor.address,
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              const Text(
                'Purchase & Inward History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),

              // Purchases Stream
              Expanded(
                child: StreamBuilder<List<PurchaseModel>>(
                  stream: inventoryRepo.watchPurchases(vendorId: vendor.vendorId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final purchases = snapshot.data ?? [];

                    if (purchases.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted.withAlpha(128)),
                            const SizedBox(height: 10),
                            const Text(
                              'No purchase history recorded for this vendor yet.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    final totalSpent = purchases.fold<double>(0.0, (acc, p) => acc + p.totalAmount);

                    return Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.separated(
                              itemCount: purchases.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                              itemBuilder: (context, index) {
                                final p = purchases[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(
                                    '${DateFormatter.formatDate(p.purchaseDate)} • ${p.purchasedQuantity} ${p.unit} @ ${AppConstants.currencySymbol}${p.purchasePricePerUnit}',
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(p.totalAmount),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        p.paymentMethod ?? 'paid',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Cumulative Purchases:', style: TextStyle(fontWeight: FontWeight.bold)),
                              Text(
                                CurrencyFormatter.format(totalSpent),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
