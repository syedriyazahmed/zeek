import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/sale_model.dart';

class InvoiceService {
  InvoiceService._();
  static final InvoiceService instance = InvoiceService._();

  Future<Uint8List> generateInvoicePdf(SaleModel sale) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Store Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AL-ABEER PERFUMES & ATHAR',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#B8860B'),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Exclusive Natural Ouds, Athar Oils & Fine Fragrances',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Main Market Road, Perfume District | Phone: +91 98765 43210',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'TAX INVOICE',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '#${sale.invoiceNumber}',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                      ),
                      pw.Text(
                        DateFormatter.formatDateTime(sale.timestamp),
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Staff & Customer info
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Cashier / Staff: ${sale.createdByName ?? sale.createdBy}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'Payment Mode: ${sale.paymentType.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Items Table
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.black),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                headers: ['#', 'Product Description', 'Unit', 'Qty', 'Rate', 'Amount'],
                data: List<List<dynamic>>.generate(sale.items.length, (index) {
                  final item = sale.items[index];
                  return [
                    '${index + 1}',
                    item.productName,
                    item.unit,
                    '${item.quantity}',
                    CurrencyFormatter.formatPlain(item.unitPrice),
                    CurrencyFormatter.formatPlain(item.totalPrice),
                  ];
                }),
              ),
              pw.SizedBox(height: 14),

              // Financial Summary
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 240,
                    child: pw.Column(
                      children: [
                        _buildSummaryRow('Subtotal:', CurrencyFormatter.formatPlain(sale.subtotal)),
                        if (sale.discount > 0)
                          _buildSummaryRow('Discount:', '- ${CurrencyFormatter.formatPlain(sale.discount)}', color: PdfColors.red700),
                        pw.Divider(thickness: 1, color: PdfColors.grey400),
                        _buildSummaryRow(
                          'Grand Total:',
                          CurrencyFormatter.formatPlain(sale.grandTotal),
                          isBold: true,
                          fontSize: 13,
                        ),
                        pw.SizedBox(height: 8),
                        // Payment Breakdown
                        if (sale.paymentType == AppConstants.paymentSplit) ...[
                          _buildSummaryRow('Cash Paid:', CurrencyFormatter.formatPlain(sale.cashAmount), fontSize: 9),
                          _buildSummaryRow('Online Paid:', CurrencyFormatter.formatPlain(sale.onlineAmount), fontSize: 9),
                        ] else if (sale.paymentType == AppConstants.paymentCash) ...[
                          _buildSummaryRow('Cash Paid:', CurrencyFormatter.formatPlain(sale.cashAmount), fontSize: 9),
                        ] else ...[
                          _buildSummaryRow('Online Paid:', CurrencyFormatter.formatPlain(sale.onlineAmount), fontSize: 9),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),

              // Footer
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Thank you for your patronage! Visit again for authentic perfumery.',
                      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Goods once opened/tested cannot be returned | Subject to local jurisdiction',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    double fontSize = 10,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : null)),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> printInvoice(SaleModel sale) async {
    final pdfBytes = await generateInvoicePdf(sale);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${sale.invoiceNumber}.pdf',
    );
  }
}
