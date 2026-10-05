import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase/supabase_provider.dart';
import '../organizations/providers/organization_providers.dart';

class PackDetails {
  const PackDetails(this.data);
  final Map<String, dynamic> data;
  String get name => data['plan_name'] as String;
  bool get operational => data['operational'] == true;
  bool get mobileAllowed =>
      operational && (data['features'] as Map)['mobile_app'] == true;
  bool get depotMissing => data['depot_missing'] == true;
  String get status =>
      const {
        'active': 'Actif',
        'expired': 'Expiré',
        'trial_active': 'Essai',
        'trial_locked': 'Essai expiré',
        'suspended': 'Suspendu',
      }[data['status']] ??
      data['status'].toString();
  factory PackDetails.fromJson(Map<String, dynamic> json) {
    if (json['plan_name'] is! String ||
        json['features'] is! Map ||
        json['operational'] is! bool) {
      throw const FormatException('Abonnement indisponible');
    }
    return PackDetails(json);
  }
}

final packProvider = FutureProvider.autoDispose<PackDetails>((ref) async {
  final access = await ref.watch(currentOrganizationProvider.future);
  if (access == null) throw StateError('Organisation requise');
  final timer = Timer(const Duration(seconds: 15), () => ref.invalidateSelf());
  ref.onDispose(timer.cancel);
  final data = await ref
      .watch(supabaseProvider)
      .rpc(
        'get_organization_plan_details',
        params: {'p_org_id': access.organization.id},
      );
  return PackDetails.fromJson(Map<String, dynamic>.from(data as Map));
});
final packCatalogueProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final data = await ref.watch(supabaseProvider).rpc('get_pack_catalogue');
      return List<Map<String, dynamic>>.from(data as List);
    });

class SubscriptionCard extends ConsumerWidget {
  const SubscriptionCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(packProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: pack.when(
          loading: () => const Text('Chargement de l’abonnement…'),
          error: (e, _) => Column(
            children: [
              const Text('Abonnement indisponible'),
              TextButton(
                onPressed: () => ref.invalidate(packProvider),
                child: const Text('Réessayer'),
              ),
            ],
          ),
          data: (p) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p.name} · ${p.status}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final q in const [
                ['Pharmacies', 'stores'],
                ['Produits actifs', 'products'],
                ['Collaborateurs', 'members'],
              ])
                Text(
                  '${q[0]} : ${p.data['current_${q[1]}']} / ${p.data['max_${q[1]}'] == -1 ? 'illimité' : p.data['max_${q[1]}']}',
                ),
              Text(
                'Dépôts : ${p.data['current_depots']} · ${p.data['depot_required'] == true ? 'Obligatoire' : 'Optionnel'}',
              ),
              if (p.data['over_quota'] == true)
                const Text(
                  'Quota dépassé : données conservées, nouvelles créations concernées bloquées.',
                ),
              if (p.depotMissing)
                const Text(
                  'Créez ou qualifiez un dépôt dans la plateforme web : Stock > Lieux de stock.',
                ),
              if (p.data['depot_required'] == true &&
                  (p.data['unassigned_members'] as num) > 0)
                Text(
                  '${p.data['unassigned_members']} collaborateur(s) à assigner depuis Équipe & Rôles.',
                ),
              for (final feature in (p.data['included_features'] as List))
                Text('✓ $feature'),
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const PackCatalogueSheet(),
                ),
                child: const Text('Changer ou renouveler le pack'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PackCatalogueSheet extends ConsumerStatefulWidget {
  const PackCatalogueSheet({super.key});
  @override
  ConsumerState<PackCatalogueSheet> createState() => _PackCatalogueSheetState();
}

class _PackCatalogueSheetState extends ConsumerState<PackCatalogueSheet> {
  bool pending = false;
  String? message;
  Future<void> request(String id) async {
    setState(() {
      pending = true;
      message = null;
    });
    try {
      final access = await ref.read(currentOrganizationProvider.future);
      await ref
          .read(supabaseProvider)
          .rpc(
            'request_plan_change',
            params: {'p_org_id': access!.organization.id, 'p_plan_id': id},
          );
      if (mounted) {
        setState(
          () => message =
              'Demande enregistrée. Activation après validation et paiement.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Demande non enregistrée. Vérifiez votre rôle et les demandes déjà en cours depuis la plateforme web.',
        );
      }
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: ref
          .watch(packCatalogueProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                const Center(child: Text('Tarification indisponible')),
            data: (plans) => ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Packs MaPharmacie'),
                if (message != null) Text(message!),
                for (final p in plans)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p['name']} · ${p['price_monthly']} MAD/mois'),
                          for (final f in p['features'] as List) Text('✓ $f'),
                          FilledButton(
                            onPressed: pending
                                ? null
                                : () => request(p['id'] as String),
                            child: const Text('Demander ce pack'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
    ),
  );
}
