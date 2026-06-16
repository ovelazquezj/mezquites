import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/providers.dart';
import '../copy.dart';
import '../widgets/branded_app_bar.dart';
import '../widgets/common.dart';
import 'account_screen.dart';
import 'help_screen.dart';
import 'rankings_screen.dart';

/// Perfil del voluntario (Q4): lifelist, etiqueta de identidad L3, insignias,
/// feedback AGREGADO (gate #9). La identidad NO desbloquea funciones (gate #3).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final feedbackAsync = ref.watch(feedbackProvider);

    return Scaffold(
      appBar: BrandedAppBar(
        title: Copy.profileTitle,
        actions: [
          IconButton(
            key: const Key('open_rankings'),
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RankingsScreen()),
            ),
          ),
          IconButton(
            key: const Key('open_account'),
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
            ),
          ),
          IconButton(
            key: const Key('profile_help'),
            icon: const Icon(Icons.help_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(profileProvider);
          ref.invalidate(feedbackProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Text('No se pudo cargar el perfil.'),
              data: (p) => _ProfileBody(profile: p),
            ),
            const SizedBox(height: 8),
            SectionCard(
              title: Copy.feedbackTitle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InfoNote(Copy.feedbackNote),
                  const SizedBox(height: 8),
                  feedbackAsync.when(
                    loading: () =>
                        const LinearProgressIndicator(),
                    error: (e, _) => const Text('Sin resumen por ahora.'),
                    // SOLO agregado: nunca por observación (gate #9).
                    data: (f) => Text(
                      f.message,
                      key: const Key('feedback_message'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.handle, style: theme.textTheme.displayLarge),
              const SizedBox(height: 4),
              // Etiqueta de identidad L3 (no desbloquea nada).
              Chip(
                key: const Key('identity_label'),
                label: Text(Copy.identityLabel(profile.identityLabel)),
              ),
              Text(
                profile.institution ?? 'Independiente',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              const InfoNote(Copy.identityNote),
            ],
          ),
        ),
        SectionCard(
          title: 'Tu actividad',
          child: Column(
            children: [
              StatTile(
                label: 'Árboles distintos registrados',
                value: '${profile.lifelistTrees}',
              ),
              StatTile(
                label: 'Observaciones',
                value: '${profile.totalObservations}',
              ),
              StatTile(label: 'Puntos', value: '${profile.totalPoints}'),
            ],
          ),
        ),
        SectionCard(
          title: 'Insignias',
          child: profile.badges.isEmpty
              ? Text('Aún sin insignias. ¡Tu primera observación cuenta!',
                  style: theme.textTheme.bodySmall,)
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: profile.badges
                      .map((b) => Chip(
                            avatar: const Icon(Icons.emoji_events_outlined,
                                size: 18,),
                            label: Text(Copy.badge(b)),
                          ),)
                      .toList(),
                ),
        ),
      ],
    );
  }
}
