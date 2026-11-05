import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/vendor_model.dart';
import '../../authentication/providers/auth_provider.dart';
import '../providers/vendor_provider.dart';
import 'widgets/add_edit_vendor_dialog.dart';
import 'widgets/vendor_details_dialog.dart';

class VendorsScreen extends ConsumerWidget {
  const VendorsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendors = ref.watch(filteredVendorsProvider);
    final user = ref.watch(authStateProvider).asData?.value;
    final isAdmin = user?.isAdmin ?? false;
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.mobileBreakpoint;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Title & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vendor Directory & Suppliers',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage oil and bottle suppliers, purchase rates, and contacts',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                if (isAdmin)
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AddEditVendorDialog(),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Vendor'),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (val) => ref.read(vendorSearchQueryProvider.notifier).setQuery(val),
                decoration: const InputDecoration(
                  hintText: 'Search vendors by name, company, phone, or address...',
                  prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Vendors Table or Cards
            Expanded(
              child: vendors.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business_outlined, size: 56, color: AppColors.textMuted.withAlpha(128)),
                          const SizedBox(height: 12),
                          const Text('No vendors found.', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  : isDesktop
                      ? _buildDesktopTable(context, ref, vendors, isAdmin)
                      : _buildMobileCards(context, ref, vendors, isAdmin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context, WidgetRef ref, List<VendorModel> vendors, bool isAdmin) {
    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SingleChildScrollView(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Vendor Name', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Company', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Location / Address', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Specialities / Notes', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: vendors.map((v) {
              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primaryContainer,
                          child: Text(
                            v.vendorName.isNotEmpty ? v.vendorName[0].toUpperCase() : 'V',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(v.vendorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  DataCell(Text(v.companyName.isNotEmpty ? v.companyName : '-')),
                  DataCell(Text(v.phoneNumber.isNotEmpty ? v.phoneNumber : '-')),
                  DataCell(
                    SizedBox(
                      width: 180,
                      child: Text(
                        v.address.isNotEmpty ? v.address : '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 200,
                      child: Text(
                        v.notes.isNotEmpty ? v.notes : '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
                          tooltip: 'Purchase History',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (_) => VendorDetailsDialog(vendor: v),
                            );
                          },
                        ),
                        if (isAdmin) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                            tooltip: 'Edit Vendor',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (_) => AddEditVendorDialog(vendor: v),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.archive_outlined, size: 18, color: AppColors.warning),
                            tooltip: 'Archive Vendor',
                            onPressed: () => _confirmArchiveVendor(context, ref, v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCards(BuildContext context, WidgetRef ref, List<VendorModel> vendors, bool isAdmin) {
    return ListView.builder(
      itemCount: vendors.length,
      itemBuilder: (context, index) {
        final v = vendors[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primaryContainer,
                      child: Text(
                        v.vendorName.isNotEmpty ? v.vendorName[0].toUpperCase() : 'V',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (v.companyName.isNotEmpty)
                            Text(v.companyName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (v.phoneNumber.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(v.phoneNumber, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                if (v.address.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(child: Text(v.address, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  ),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.receipt_long, size: 16),
                      label: const Text('Purchases', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => VendorDetailsDialog(vendor: v),
                        );
                      },
                    ),
                    if (isAdmin) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AddEditVendorDialog(vendor: v),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmArchiveVendor(BuildContext context, WidgetRef ref, VendorModel vendor) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Vendor?'),
        content: Text('Are you sure you want to archive "${vendor.vendorName}"? Historical purchases will remain intact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(vendorRepositoryProvider).archiveVendor(vendor.vendorId, true);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Vendor "${vendor.vendorName}" archived.')),
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}
