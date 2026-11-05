import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:perfume_pos/app.dart';
import 'package:perfume_pos/core/utils/currency_formatter.dart';
import 'package:perfume_pos/data/models/product_model.dart';

void main() {
  group('Business Logic & Currency Formatter Tests', () {
    test('CurrencyFormatter handles decimal-safe rounding and formatting', () {
      expect(CurrencyFormatter.format(1250), '₹1,250.00');
      expect(CurrencyFormatter.round(10.004), 10.0);
      expect(CurrencyFormatter.round(10.006), 10.01);
      expect(CurrencyFormatter.rupeesToPaise(50.25), 5025);
      expect(CurrencyFormatter.paiseToRupees(5025), 50.25);
    });

    test('ProductModel calculations work accurately', () {
      final product = ProductModel(
        productId: 'prod_1',
        productName: 'Oud Premium',
        normalizedName: 'oud premium',
        productCode: 'OUD-001',
        productType: 'Oil',
        category: 'Oud',
        unit: 'ml',
        totalPurchased: 500,
        totalSold: 100,
        availableQuantity: 400,
        vendorPricePerUnit: 3.0,
        sellingPricePerUnit: 5.0,
        lowStockThreshold: 50,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.isOil, isTrue);
      expect(product.isNonOil, isFalse);
      expect(product.isLowStock, isFalse);
      expect(product.isOutOfStock, isFalse);
      expect(product.potentialSellingValue, 2000.0); // 400 * 5.0
      expect(product.currentStockCost, 1200.0); // 400 * 3.0
      expect(product.expectedMargin, 800.0); // 2000 - 1200
    });
  });

  group('Widget Navigation Smoke Tests', () {
    testWidgets('Perfume POS App smoke test initializes cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: PerfumePosApp(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // App initializes without crashing and displays initial POS / Login elements
      expect(find.byType(PerfumePosApp), findsOneWidget);
    });
  });
}
