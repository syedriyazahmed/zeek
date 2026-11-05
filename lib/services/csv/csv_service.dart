import 'package:csv/csv.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/account_entry_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/sale_model.dart';

class CsvValidationResult {
  final List<ProductModel> validProducts;
  final List<CsvRowError> errors;
  final int totalRows;

  const CsvValidationResult({
    required this.validProducts,
    required this.errors,
    required this.totalRows,
  });

  bool get hasErrors => errors.isNotEmpty;
  int get validCount => validProducts.length;
}

class CsvRowError {
  final int rowNumber;
  final String productCode;
  final String reason;

  const CsvRowError({
    required this.rowNumber,
    required this.productCode,
    required this.reason,
  });
}

class CsvService {
  CsvService._();
  static final CsvService instance = CsvService._();

  static const List<String> expectedHeaders = [
    'Product Name',
    'Product Code',
    'Product Type',
    'Category',
    'Unit',
    'Selling Price',
    'Vendor Price',
    'Available Quantity',
    'Low Stock Threshold',
  ];

  /// Generate sample CSV template content
  String generateSampleCsv() {
    final List<List<dynamic>> rows = [
      expectedHeaders,
      ['Oud Cambodi Special', 'OUD-001', 'Oil', 'Oud', 'ml', 15.00, 10.00, 500, 50],
      ['Royal White Musk', 'MSK-002', 'Oil', 'Musk', 'ml', 8.00, 5.00, 750, 100],
      ['Bakhoor Al-Abeer 100g', 'BKH-001', 'Non-Oil', 'Bakhoor', 'piece', 450.00, 300.00, 25, 5],
      ['Attar Rose Taif', 'ROS-003', 'Oil', 'Floral', 'ml', 12.00, 7.50, 300, 30],
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Export products to CSV string
  String exportProductsToCsv(List<ProductModel> products) {
    final List<List<dynamic>> rows = [
      expectedHeaders,
      ...products.map((p) => [
            p.productName,
            p.productCode,
            p.productType,
            p.category,
            p.unit,
            p.sellingPricePerUnit,
            p.vendorPricePerUnit,
            p.availableQuantity,
            p.lowStockThreshold,
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Parse and validate CSV data
  CsvValidationResult parseAndValidateCsv(
    String csvContent, {
    Set<String> existingProductCodes = const {},
    String defaultProductType = AppConstants.productTypeOil,
  }) {
    final List<List<dynamic>> csvRows = const CsvToListConverter(
      shouldParseNumbers: true,
      eol: '\n',
    ).convert(csvContent.trim());

    if (csvRows.isEmpty) {
      return const CsvValidationResult(
        validProducts: [],
        errors: [
          CsvRowError(rowNumber: 1, productCode: '', reason: 'CSV file is completely empty.')
        ],
        totalRows: 0,
      );
    }

    final headerRow = csvRows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    // Map header indexes
    int findHeaderIndex(List<String> variants) {
      for (final v in variants) {
        final idx = headerRow.indexOf(v.toLowerCase());
        if (idx != -1) return idx;
      }
      return -1;
    }

    final nameIdx = findHeaderIndex(['Product Name', 'name', 'product_name']);
    final codeIdx = findHeaderIndex(['Product Code', 'code', 'product_code', 'sku']);
    final typeIdx = findHeaderIndex(['Product Type', 'type', 'product_type']);
    final categoryIdx = findHeaderIndex(['Category', 'category_name']);
    final unitIdx = findHeaderIndex(['Unit', 'unit_of_measure', 'uom']);
    final sellPriceIdx = findHeaderIndex(['Selling Price', 'selling_price', 'price']);
    final vendorPriceIdx = findHeaderIndex(['Vendor Price', 'purchase_price', 'cost']);
    final qtyIdx = findHeaderIndex(['Available Quantity', 'quantity', 'stock', 'opening_stock']);
    final lowStockIdx = findHeaderIndex(['Low Stock Threshold', 'threshold', 'low_stock']);

    if (nameIdx == -1 || codeIdx == -1 || sellPriceIdx == -1) {
      return const CsvValidationResult(
        validProducts: [],
        errors: [
          CsvRowError(
            rowNumber: 1,
            productCode: '',
            reason: 'Missing mandatory columns: "Product Name", "Product Code", or "Selling Price".',
          )
        ],
        totalRows: 0,
      );
    }

    final List<ProductModel> validProducts = [];
    final List<CsvRowError> errors = [];
    final Set<String> seenCodesInCsv = {};

    for (int i = 1; i < csvRows.length; i++) {
      final row = csvRows[i];
      if (row.isEmpty || row.every((c) => c == null || c.toString().trim().isEmpty)) {
        continue; // skip blank rows
      }

      final rowNum = i + 1;
      final rawName = (nameIdx < row.length ? row[nameIdx]?.toString() : '')?.trim() ?? '';
      final rawCode = (codeIdx < row.length ? row[codeIdx]?.toString() : '')?.trim() ?? '';

      if (rawName.isEmpty) {
        errors.add(CsvRowError(rowNumber: rowNum, productCode: rawCode, reason: 'Product name cannot be empty.'));
        continue;
      }

      if (rawCode.isEmpty) {
        errors.add(CsvRowError(rowNumber: rowNum, productCode: '', reason: 'Product code/SKU cannot be empty.'));
        continue;
      }

      final normalizedCode = rawCode.toUpperCase();

      if (seenCodesInCsv.contains(normalizedCode)) {
        errors.add(CsvRowError(rowNumber: rowNum, productCode: rawCode, reason: 'Duplicate product code in CSV.'));
        continue;
      }

      if (existingProductCodes.contains(normalizedCode)) {
        errors.add(CsvRowError(
          rowNumber: rowNum,
          productCode: rawCode,
          reason: 'Product code "$rawCode" already exists in shop inventory.',
        ));
        continue;
      }

      seenCodesInCsv.add(normalizedCode);

      // Parse numerical fields
      double parseDouble(int idx, double defaultVal) {
        if (idx < 0 || idx >= row.length || row[idx] == null) return defaultVal;
        return double.tryParse(row[idx].toString().trim()) ?? defaultVal;
      }

      final sellPrice = parseDouble(sellPriceIdx, -1.0);
      if (sellPrice <= 0) {
        errors.add(CsvRowError(rowNumber: rowNum, productCode: rawCode, reason: 'Selling price must be greater than 0.'));
        continue;
      }

      final vendorPrice = parseDouble(vendorPriceIdx, 0.0);
      final qty = parseDouble(qtyIdx, 0.0);
      final lowStock = parseDouble(lowStockIdx, 10.0);

      String rawType = (typeIdx != -1 && typeIdx < row.length ? row[typeIdx]?.toString().trim() : '') ?? '';
      if (rawType.isEmpty) {
        rawType = defaultProductType;
      } else if (rawType.toLowerCase().contains('oil') && !rawType.toLowerCase().contains('non')) {
        rawType = AppConstants.productTypeOil;
      } else {
        rawType = AppConstants.productTypeNonOil;
      }

      String rawUnit = (unitIdx != -1 && unitIdx < row.length ? row[unitIdx]?.toString().trim() : '') ?? '';
      if (rawUnit.isEmpty) {
        rawUnit = rawType == AppConstants.productTypeOil ? AppConstants.unitMl : AppConstants.unitPiece;
      }

      // Whole number validation for piece products
      if (rawUnit == AppConstants.unitPiece && qty != qty.truncateToDouble()) {
        errors.add(CsvRowError(
          rowNumber: rowNum,
          productCode: rawCode,
          reason: 'Piece-based products must have whole number quantities.',
        ));
        continue;
      }

      final rawCategory = (categoryIdx != -1 && categoryIdx < row.length ? row[categoryIdx]?.toString().trim() : '') ?? 'General';

      final now = DateTime.now();
      validProducts.add(
        ProductModel(
          productId: 'prod_${normalizedCode.replaceAll(RegExp(r'[^A-Z0-9]'), '_')}_${now.millisecondsSinceEpoch}',
          productName: rawName,
          normalizedName: rawName.toLowerCase(),
          productCode: normalizedCode,
          productType: rawType,
          category: rawCategory.isEmpty ? 'General' : rawCategory,
          unit: rawUnit,
          totalPurchased: qty,
          totalSold: 0.0,
          availableQuantity: qty,
          vendorPricePerUnit: vendorPrice,
          sellingPricePerUnit: sellPrice,
          lowStockThreshold: lowStock,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return CsvValidationResult(
      validProducts: validProducts,
      errors: errors,
      totalRows: csvRows.length - 1,
    );
  }

  /// Export account entries to CSV string
  String exportAccountLedgerToCsv(List<AccountEntryModel> entries) {
    final List<List<dynamic>> rows = [
      ['Date', 'Time', 'Entry ID', 'Type', 'Description', 'Cash Amount', 'Online Amount', 'Total Amount', 'Created By'],
      ...entries.map((e) => [
            e.date,
            DateFormatter.formatTime(e.createdAt),
            e.entryId,
            e.transactionType,
            e.description,
            e.cashAmount,
            e.onlineAmount,
            e.totalAmount,
            e.createdBy,
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Export sales transactions to CSV string
  String exportSalesToCsv(List<SaleModel> sales) {
    final List<List<dynamic>> rows = [
      ['Date', 'Time', 'Invoice Number', 'Items Count', 'Subtotal', 'Discount', 'Grand Total', 'Payment Mode', 'Cash Paid', 'Online Paid', 'Status', 'Staff'],
      ...sales.map((s) => [
            s.date,
            DateFormatter.formatTime(s.timestamp),
            s.invoiceNumber,
            s.items.length,
            s.subtotal,
            s.discount,
            s.grandTotal,
            s.paymentType,
            s.cashAmount,
            s.onlineAmount,
            s.status,
            s.createdByName ?? s.createdBy,
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Export product sales performance to CSV
  String exportStockSoldToCsv(List<Map<String, dynamic>> items) {
    final List<List<dynamic>> rows = [
      ['Product Name', 'SKU / Code', 'Category', 'Type', 'Unit', 'Qty Sold', 'Available Stock', 'Total Revenue', 'COGS', 'Gross Profit', 'Margin %'],
      ...items.map((item) => [
            item['productName'],
            item['productCode'],
            item['category'],
            item['productType'],
            item['unit'],
            item['soldQuantity'],
            item['availableQuantity'],
            item['totalRevenue'],
            item['totalCogs'],
            item['grossProfit'],
            '${item['marginPercent']}%',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }
}
