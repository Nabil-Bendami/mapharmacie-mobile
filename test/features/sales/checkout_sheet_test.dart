import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ma_pharmacie_mobile/features/inventory/domain/warehouse.dart';
import 'package:ma_pharmacie_mobile/features/organizations/domain/organization_access.dart';
import 'package:ma_pharmacie_mobile/features/sales/domain/sale.dart';
import 'package:ma_pharmacie_mobile/features/sales/presentation/cart_checkout_sheet.dart';

void main() {
  testWidgets(
    'multi-item checkout fits a phone and requires a phone for credit',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CartCheckoutSheet(
                access: OrganizationAccess(
                  membershipId: 'member',
                  role: 'owner',
                  organization: PharmacyOrganization(
                    id: 'org',
                    name: 'Pharmacie',
                    currency: 'MAD',
                    locale: 'fr-MA',
                  ),
                ),
                warehouses: [
                  Warehouse(
                    id: 'warehouse',
                    name: 'Principal',
                    isDefault: true,
                  ),
                ],
                lines: [
                  SaleLine(
                    productId: 'a',
                    productName: 'Produit A',
                    quantity: 1,
                    unitPrice: 10,
                    taxRate: 0,
                  ),
                  SaleLine(
                    productId: 'b',
                    productName: 'Produit B',
                    quantity: 2,
                    unitPrice: 5,
                    taxRate: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Produit A × 1'), findsOneWidget);
      expect(find.text('Produit B × 2'), findsOneWidget);
      expect(find.text('Total: 20.00 MAD'), findsOneWidget);
      await tester.tap(find.text('Tal9a / Crédit'));
      await tester.pump();
      await tester.ensureVisible(find.text('Confirmer la vente'));
      await tester.tap(find.text('Confirmer la vente'));
      await tester.pump();
      expect(find.text('Numéro obligatoire pour Tal9a.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
