import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/session.dart';
import 'allies_screen.dart';
import 'institutions_screen.dart';
import 'org_indicators_screen.dart';
import 'public_dashboard_screen.dart';
import 'restricted_dashboard_screen.dart';
import 'snapshots_screen.dart';

/// Shell de la web admin (rol `admin_consorcio`). NavigationRail con los módulos.
///
/// La vista RESTRINGIDA (coords exactas) solo se ofrece si el token autenticado
/// es `aliado_firmante`/autorizado (gate #5): para un `admin_consorcio` puro NO
/// aparece en la navegación.
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

  List<_NavItem> _items(bool canSeeRestricted) {
    return [
      _NavItem(Icons.dashboard_outlined, 'Dashboard público',
          () => const PublicDashboardScreen()),
      _NavItem(Icons.account_balance_outlined, 'Lista F3',
          () => const InstitutionsScreen()),
      _NavItem(Icons.handshake_outlined, 'Aliados firmantes',
          () => const AlliesScreen()),
      _NavItem(Icons.fact_check_outlined, 'Indicadores org.',
          () => const OrgIndicatorsScreen()),
      _NavItem(Icons.camera_outlined, 'Snapshots',
          () => const SnapshotsScreen()),
      // Vista restringida: SOLO si el rol autoriza coords exactas (gate #5).
      if (canSeeRestricted)
        _NavItem(Icons.lock_outline, 'Dashboard restringido',
            () => const RestrictedDashboardScreen()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);
    final items = _items(session.canSeeRestricted);
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
