import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/product_model.dart';
import '../../../../services/csv/csv_service.dart';
import '../../../authentication/providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';

class CsvImportDialog extends ConsumerStatefulWidget {
  final String productType;

  const CsvImportDialog({
    super.key,
    this.productType = AppConstants.productTypeOil,
  });

  @override
  ConsumerState<CsvImportDialog> createState() => _CsvImportDialogState();
}

class _CsvImportDialogState extends ConsumerState<CsvImportDialog> {
  String? _fileName;
  CsvValidationResult? _validationResult;
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final content = utf8.decode(bytes);
          _loadAndValidateCsv(content, file.name);
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error selecting file: $e';
      });
    }
  }

  void _loadAndValidateCsv(String content, String fileName) {
    setState(() {
      _fileName = fileName;
      _statusMessage = null;
    });

    final repo = ref.read(inventoryRepositoryProvider);
    repo.getProducts().then((existingProducts) {
      final existingCodes = existingProducts.map((p) => p.productCode.toUpperCase()).toSet();
      final result = CsvService.instance.parseAndValidateCsv(
        content,
        existingProductCodes: existingCodes,
        defaultProductType: widget.productType,
      );

      setState(() {
        _validationResult = result;
      });
    });
  }

  void _loadSampleData() {
    final sample = CsvService.instance.generateSampleCsv();
    _loadAndValidateCsv(sample, 'sample_template.csv');
  }

  void _copySampleCsv() {
    final sample = CsvService.instance.generateSampleCsv();
    Clipboard.setData(ClipboardData(text: sample));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sample CSV template copied to clipboard!')),
    );
  }

  Future<void> _confirmImport() async {
    final result = _validationResult;
    if (result == null || result.validProducts.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final user = ref.read(authStateProvider).asData?.value;
      final userId = user?.displayName ?? 'Admin';

      await repo.batchAddProducts(result.validProducts, userId: userId);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.cashGreen,
            content: Text('Successfully imported ${result.validProducts.length} products!'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Import error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _validationResult;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750, maxHeight: 680),
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
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.file_upload_outlined, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CSV Bulk Product Import',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Validate headers, detect duplicates, and batch ingest stock',
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
              const SizedBox(height: 18),

              // File Selection Row
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _pickFile,
                    icon: const Icon(Icons.file_open_outlined, size: 18),
                    label: const Text('Choose CSV File'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _loadSampleData,
                    icon: const Icon(Icons.science_outlined, size: 18),
                    label: const Text('Load Sample Demo Data'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _copySampleCsv,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy Template', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 14),
              ],

              // Preview & Validation Results
              Expanded(
                child: result == null
                    ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.background,
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.table_view_outlined, size: 48, color: AppColors.textMuted),
                              SizedBox(height: 12),
                              Text(
                                'Select a CSV file or load sample demo data to inspect records.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Columns: Product Name, Product Code, Product Type, Category, Unit, Selling Price, Vendor Price, Quantity, Low Stock Threshold',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Validation Summary Badges
                          Row(
                            children: [
                              _buildMetricChip(
                                label: 'Total Rows',
                                value: '${result.totalRows}',
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 10),
                              _buildMetricChip(
                                label: 'Valid Records',
                                value: '${result.validCount}',
                                color: AppColors.cashGreen,
                              ),
                              const SizedBox(width: 10),
                              _buildMetricChip(
                                label: 'Errors / Conflicts',
                                value: '${result.errors.length}',
                                color: result.hasErrors ? AppColors.danger : AppColors.textMuted,
                              ),
                              if (_fileName != null) ...[
                                const Spacer(),
                                Text(
                                  _fileName!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Valid Items Preview & Errors Table
                          Expanded(
                            child: DefaultTabController(
                              length: result.hasErrors ? 2 : 1,
                              child: Column(
                                children: [
                                  TabBar(
                                    labelColor: AppColors.primary,
                                    unselectedLabelColor: AppColors.textSecondary,
                                    indicatorColor: AppColors.primary,
                                    tabs: [
                                      Tab(text: 'Valid Products (${result.validCount})'),
                                      if (result.hasErrors)
                                        Tab(text: 'Errors & Conflicts (${result.errors.length})'),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: TabBarView(
                                      children: [
                                        // Valid list
                                        _buildValidProductsList(result.validProducts),
                                        // Error list
                                        if (result.hasErrors)
                                          _buildErrorsList(result.errors),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isProcessing ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    onPressed: (_isProcessing || result == null || result.validProducts.isEmpty)
                        ? null
                        : _confirmImport,
                    icon: _isProcessing
                        ? const SizedBox.shrink()
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text('Import ${result?.validCount ?? 0} Valid Products'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildValidProductsList(List<ProductModel> products) {
    if (products.isEmpty) {
      return const Center(child: Text('No valid products to import in this file.'));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        itemCount: products.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final p = products[index];
          return ListTile(
            dense: true,
            title: Text(p.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('SKU: ${p.productCode} • ${p.category} • ${p.productType}'),
            trailing: Text(
              '${p.availableQuantity} ${p.unit} @ ${AppConstants.currencySymbol}${p.sellingPricePerUnit}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorsList(List<CsvRowError> errors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        itemCount: errors.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (context, index) {
          final err = errors[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.dangerLight,
              child: Text('${err.rowNumber}', style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold)),
            ),
            title: Text('Row ${err.rowNumber}: ${err.reason}', style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            subtitle: err.productCode.isNotEmpty ? Text('Product Code: ${err.productCode}') : null,
          );
        },
      ),
    );
  }
}
