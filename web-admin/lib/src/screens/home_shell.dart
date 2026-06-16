import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import '../ui/copy.dart';
import 'allies_screen.dart';
import 'institutions_screen.dart';
import 'monitor_screen.dart';
import 'org_indicators_screen.dart';
import 'public_dashboard_screen.dart';
import 'restricted_dashboard_screen.dart';
import 'review_screen.dart';
import 'snapshots_screen.dart';

/// Shell de la consola del consorcio. NavigationRail con los módulos, **gated por
/// rol** (CR-001):
/// - Módulos de administración (instituciones/aliados/indicadores/cortes): solo
///   `admin_consorcio`/`administrador`.
/// - Revisión de observaciones: `evaluador`/`administrador` (emiten veredicto).
/// - Monitor de revisión: `evaluador`/`analista`/`administrador` (solo lectura).
/// - Panel con ubicación exacta: solo `aliado_firmante` (gate #5).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _NavItem {
  const _NavItem(this.icon, this.label, this.builder);
  final IconData icon;
  final String label;
  final Widget Function() builder;
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  List<_NavItem> _items(SessionState session) {
    final isAdmin = session.isAdmin; // admin_consorcio o administrador
    return [
      _NavItem(Icons.dashboard_outlined, Copy.navPublic,
          () => const PublicDashboardScreen()),
      // Revisión de observaciones: evaluador/administrador (emiten veredicto).
      if (session.canEmitVerdict)
        _NavItem(Icons.rate_review_outlined, Copy.navReview,
            () => const ReviewScreen()),
      // Monitor: cualquier rol de revisión (incluye analista, solo lectura).
      if (session.canReview)
        _NavItem(Icons.insights_outlined, Copy.navMonitor,
            () => const MonitorScreen()),
      // Módulos de administración: solo admin_consorcio/administrador.
      if (isAdmin) ...[
        _NavItem(Icons.account_balance_outlined, Copy.navInstitutions,
            () => const InstitutionsScreen()),
        _NavItem(Icons.handshake_outlined, Copy.navAllies,
            () => const AlliesScreen()),
        _NavItem(Icons.fact_check_outlined, Copy.navIndicators,
            () => const OrgIndicatorsScreen()),
        _NavItem(Icons.camera_outlined, Copy.navSnapshots,
            () => const SnapshotsScreen()),
      ],
      // Vista restringida: SOLO si el rol autoriza coords exactas (gate #5).
      if (session.canSeeRestricted)
        _NavItem(Icons.lock_outline, Copy.navRestricted,
            () => const RestrictedDashboardScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);
    final items = _items(session);
    if (_index >= items.length) _index = 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración del consorcio — Mezquite'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                session.session?.handle ?? '',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onPrimary),
              ),
            ),
          ),
          IconButton(
            key: const Key('logout'),
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 220,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  label: Text(item.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: items[_index].builder()),
        ],
      ),
    );
  }
}
