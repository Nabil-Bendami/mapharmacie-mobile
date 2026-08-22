import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../organizations/providers/organization_providers.dart';
import '../providers/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider).value;
    final metrics = ref.watch(dashboardMetricsProvider);
    return RefreshIndicator(
      onRefresh: () async {
        final _ = await ref.refresh(dashboardMetricsProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Text(
            'Good day',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 3),
          Text(
            organization?.organization.name ?? 'MaPharmacie',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              onTap: () => context.go('/scanner'),
              borderRadius: BorderRadius.circular(22),
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 27,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    SizedBox(width: 17),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan product',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Identify a medicine in seconds',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Pharmacy overview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          metrics.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Text(AppError.from(error).message),
                    TextButton(
                      onPressed: () => ref.invalidate(dashboardMetricsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (value) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _MetricCard(
                  label: 'Products',
                  value: value.products,
                  icon: Icons.medication_outlined,
                  color: AppColors.primary,
                ),
                _MetricCard(
                  label: 'Low stock',
                  value: value.lowStock,
                  icon: Icons.trending_down_rounded,
                  color: Colors.orange.shade700,
                ),
                _MetricCard(
                  label: 'Out of stock',
                  value: value.outOfStock,
                  icon: Icons.inventory_2_outlined,
                  color: Colors.red.shade600,
                ),
                _MetricCard(
                  label: 'Expiring soon',
                  value: value.expiringSoon,
                  icon: Icons.event_busy_outlined,
                  color: Colors.purple.shade600,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
