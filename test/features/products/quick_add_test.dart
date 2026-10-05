import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_pharmacie_mobile/features/products/data/product_repository.dart';
import 'package:ma_pharmacie_mobile/features/products/domain/product.dart';
import 'package:ma_pharmacie_mobile/features/products/providers/product_providers.dart';
import 'package:ma_pharmacie_mobile/features/products/presentation/quick_add_product_screen.dart';
import 'package:ma_pharmacie_mobile/features/inventory/data/inventory_repository.dart';
import 'package:ma_pharmacie_mobile/features/inventory/domain/warehouse.dart';
import 'package:ma_pharmacie_mobile/features/inventory/providers/inventory_providers.dart';
import 'package:ma_pharmacie_mobile/features/organizations/domain/organization_access.dart';
import 'package:ma_pharmacie_mobile/features/organizations/providers/organization_providers.dart';

class ProductsFake extends ProductRepository {
  ProductsFake(super.client);
  final categories = <Category>[];
  int creations = 0;
  String? savedCategory;
  num? savedQuantity;
  String? savedWarehouse;
  @override
  Future<List<Category>> getCategories(String organizationId) async =>
      categories;
  @override
  Future<Category> createCategory(String organizationId, String name) async {
    final category = Category(id: 'new-category', name: name.trim());
    categories.add(category);
    return category;
  }

  @override
  Future<Product> quickCreate({
    required String requestId,
    num initialQuantity = 0,
    String? warehouseId,
    required String organizationId,
    required String barcode,
    required String name,
    required num sellingPrice,
    String? categoryId,
    String? brand,
    String? dosage,
    String? form,
    num? purchasePrice,
  }) async {
    creations++;
    savedCategory = categoryId;
    savedQuantity = initialQuantity;
    savedWarehouse = warehouseId;
    return Product.fromJson({
      'id': 'product',
      'organization_id': organizationId,
      'name': name,
      'barcode': barcode,
      'selling_price': sellingPrice,
    });
  }
}

class InventoryFake extends InventoryRepository {
  InventoryFake(super.client);
  num? quantity;
  @override
  Future<num> addOpeningStock({
    required String productId,
    required String warehouseId,
    required num quantity,
  }) async {
    this.quantity = quantity;
    return quantity;
  }
}

void main() {
  late SupabaseClient client;
  late ProductsFake products;
  late InventoryFake inventory;
  setUp(() {
    client = SupabaseClient('http://localhost', 'test');
    products = ProductsFake(client);
    inventory = InventoryFake(client);
  });
  tearDown(() => client.dispose());

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/new',
      routes: [
        GoRoute(
          path: '/new',
          builder: (_, _) => const QuickAddProductScreen(barcode: '123456789'),
        ),
        GoRoute(
          path: '/scanner',
          builder: (_, _) => const Scaffold(body: Text('Scanner ready')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productRepositoryProvider.overrideWithValue(products),
          inventoryRepositoryProvider.overrideWithValue(inventory),
          currentOrganizationProvider.overrideWith(
            (ref) async => const OrganizationAccess(
              membershipId: 'member',
              role: 'owner',
              organization: PharmacyOrganization(
                id: 'org',
                name: 'Pharmacie',
                currency: 'MAD',
                locale: 'fr-MA',
              ),
            ),
          ),
          activeWarehousesProvider.overrideWith(
            (ref) async => const [
              Warehouse(id: 'warehouse', name: 'Principal', isDefault: true),
            ],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  testWidgets(
    'quantity is visible immediately; inline category preserves draft and is selected',
    (tester) async {
      await open(tester);
      expect(
        find.byKey(const ValueKey('initial-stock')).hitTestable(),
        findsOneWidget,
      );
      await tester.enterText(field('Nom du produit *'), 'Mon produit');
      await tester.enterText(find.byKey(const ValueKey('initial-stock')), '24');
      await tester.tap(find.text('Créer une catégorie'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Nom de la catégorie'), 'Parapharmacie');
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();
      expect(find.text('Mon produit'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      expect(find.text('Parapharmacie'), findsOneWidget);
      await tester.ensureVisible(field('Prix de vente *'));
      await tester.enterText(field('Prix de vente *'), '12,50');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Enregistrer le produit et le stock'),
      );
      await tester.tap(find.text('Enregistrer le produit et le stock'));
      await tester.pumpAndSettle();
      expect(products.creations, 1);
      expect(products.savedCategory, 'new-category');
      expect(products.savedQuantity, 24);
      expect(products.savedWarehouse, 'warehouse');
      expect(
        inventory.quantity,
        isNull,
      ); // Stock is in the same backend transaction.
      expect(find.text('Scanner ready'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('zero creates a product without an invalid zero stock movement', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('Nom du produit *'), 'Sans stock');
    await tester.enterText(find.byKey(const ValueKey('initial-stock')), '0');
    await tester.ensureVisible(field('Prix de vente *'));
    await tester.enterText(field('Prix de vente *'), '10');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enregistrer le produit et le stock'));
    await tester.tap(find.text('Enregistrer le produit et le stock'));
    await tester.pumpAndSettle();
    expect(products.creations, 1);
    expect(products.savedQuantity, 0);
    expect(inventory.quantity, isNull);
    expect(find.text('Scanner ready'), findsOneWidget);
  });
}
