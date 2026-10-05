import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ma_pharmacie_mobile/core/errors/app_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ma_pharmacie_mobile/features/subscription/subscription.dart';

Map<String, dynamic> details(
  String name, {
  bool active = true,
  bool mobile = true,
}) => {
  'plan_name': name,
  'operational': active,
  'status': active ? 'active' : 'expired',
  'features': {'mobile_app': mobile},
  'current_stores': 2,
  'max_stores': 2,
  'current_products': 250,
  'max_products': 250,
  'current_members': 2,
  'max_members': 2,
  'current_depots': 0,
  'depot_required': false,
  'depot_missing': false,
  'included_features': ['Scanner & Stock'],
  'over_quota': false,
  'unassigned_members': 0,
};
void main() {
  test('quota and depot errors retain actionable backend messages', () {
    for (final message in [
      'Limite de produits atteinte — Pack Plus',
      'Entreprise : créez un dépôt',
      'Abonnement expiré',
    ]) {
      expect(
        AppError.from(
          PostgrestException(message: message, code: 'P0001'),
        ).message,
        message,
      );
    }
  });
  test('paid packs permit mobile only while operational', () {
    for (final name in ['Pack Plus', 'Pro / Équipe', 'Entreprise']) {
      expect(PackDetails.fromJson(details(name)).mobileAllowed, isTrue);
      expect(
        PackDetails.fromJson(details(name, active: false)).mobileAllowed,
        isFalse,
      );
    }
  });
  test('trial and invalid entitlement responses fail closed', () {
    expect(
      PackDetails.fromJson(details('Essai', mobile: false)).mobileAllowed,
      isFalse,
    );
    expect(() => PackDetails.fromJson({}), throwsFormatException);
  });
  testWidgets(
    'profile shows database pack and exact quotas, Pro without depot',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            packProvider.overrideWith(
              (_) async => PackDetails.fromJson(details('Pro / Équipe')),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: SubscriptionCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pro / Équipe · Actif'), findsOneWidget);
      expect(find.text('Produits actifs : 250 / 250'), findsOneWidget);
      expect(find.text('Collaborateurs : 2 / 2'), findsOneWidget);
      expect(find.text('Dépôts : 0 · Optionnel'), findsOneWidget);
    },
  );
  testWidgets('Enterprise missing depot and downgraded excess remain visible', (
    tester,
  ) async {
    final json = details('Entreprise')
      ..addAll({
        'depot_required': true,
        'depot_missing': true,
        'over_quota': true,
        'max_products': -1,
      });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          packProvider.overrideWith((_) async => PackDetails.fromJson(json)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: SubscriptionCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dépôts : 0 · Obligatoire'), findsOneWidget);
    expect(find.textContaining('Créez ou qualifiez un dépôt'), findsOneWidget);
    expect(find.textContaining('Quota dépassé'), findsOneWidget);
    expect(find.text('Produits actifs : 250 / illimité'), findsOneWidget);
  });
}
