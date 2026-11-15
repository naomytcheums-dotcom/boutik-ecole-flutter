import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'home_live.dart' show LiveTalent, TalentAvatar;
import 'l8_common.dart';
import 'talents.dart';

/// Liste des talents (écran 70) : défilante, lue et filtrée par le serveur (recherche et catégorie), avec ouverture du profil
/// (et du portfolio) de la personne et proposition de mission. Aucune disponibilité n'est affichée pour un vrai profil : le serveur n'en fournit pas.
class TalentsDirectory extends ConsumerWidget {
  const TalentsDirectory({super.key, this.width = 342, this.height = 484});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Backend.ready) {
      final demo = ref.watch(visibleTalentsProvider);
      if (demo.isEmpty) return l8Note(width, 'Aucun talent ne correspond à votre recherche.', height: height);
      return SizedBox(
        width: width,
        height: height,
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: demo.length,
          separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: Color(0xFFF2EFF6)),
          itemBuilder: (_, i) => _TalentTile(
            name: demo[i].name,
            sub: demo[i].sub,
            avatar: TalentAvatar(demoIndex: i),
            status: demo[i].showStatus ? (demo[i].available ? 'Disponible' : 'Occupée') : null,
            available: demo[i].available,
            onTap: () => talentDialog(context, ref, demo[i]),
            onPropose: () => talentDialog(context, ref, demo[i]),
          ),
        ),
      );
    }
    if (ref.watch(authProvider.select((a) => a.current == null))) {
      return l8Note(width, 'Connectez-vous pour découvrir les talents.', height: height, action: 'Se connecter', onAction: () => requireLogin(context, ref, 'découvrir les talents'));
    }
    final async = ref.watch(talentSearchProvider);
    final limit = ref.watch(talentLimitProvider);
    return async.when(
      loading: () => l8Note(width, 'Recherche des talents…', height: height),
      error: (_, _) => l8Note(width, 'Les talents ne peuvent pas être chargés pour le moment.', height: height, action: 'Réessayer', onAction: () => ref.invalidate(talentSearchProvider)),
      data: (list) {
        if (list.isEmpty) {
          final filtered = ref.read(talentQueryProvider).trim().isNotEmpty || ref.read(talentTabProvider) != 0;
          return l8Note(width, filtered ? 'Aucun talent ne correspond à votre recherche.' : 'Aucun talent à présenter pour le moment.\nLes étudiants qui complètent leur profil apparaissent ici.', height: height);
        }
        final canMore = list.length >= limit && limit < 50;
        return SizedBox(
          width: width,
          height: height,
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 90),
            itemCount: list.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1, thickness: 1, color: Color(0xFFF2EFF6)),
            itemBuilder: (_, i) {
              if (i == list.length) {
                if (canMore) return Padding(padding: const EdgeInsets.only(top: 14), child: Center(child: l8Pill('Voir plus de talents', onTap: () => ref.read(talentLimitProvider.notifier).more())));
                if (list.length >= 50) return Padding(padding: const EdgeInsets.all(16), child: Text('Les 50 premiers résultats sont affichés : précisez votre recherche pour affiner.', textAlign: TextAlign.center, style: l8St(11.5, c: l8Grey)));
                return const SizedBox.shrink();
              }
              final t = list[i];
              return _TalentTile(
                name: t.name,
                sub: [if (t.department.isNotEmpty) t.department, t.skills].where((e) => e.isNotEmpty).join(' · '),
                avatar: TalentAvatar(talent: t),
                certified: t.certified,
                onTap: () => GoRouter.of(context).push('/etudiant/${t.id}'),
                onPropose: () => talentDialog(context, ref, _asTalent(t)),
              );
            },
          ),
        );
      },
    );
  }

  Talent _asTalent(LiveTalent t) => Talent(t.name, t.department, t.skills, '', showStatus: false, avatarUrl: t.avatarUrl, userId: t.id, certified: t.certified);
}

class _TalentTile extends StatelessWidget {
  const _TalentTile({required this.name, required this.sub, required this.avatar, required this.onTap, required this.onPropose, this.certified = false, this.status, this.available = true});
  final String name, sub;
  final Widget avatar;
  final bool certified, available;
  final String? status;
  final VoidCallback onTap, onPropose;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(width: 50, height: 50, child: avatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: l8St(13.5, w: FontWeight.w600))),
                  if (certified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, size: 14, color: Color(0xFF2F6BFF))),
                ]),
                const SizedBox(height: 2),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: l8St(11.5, c: l8Grey)),
                if (status != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(status!, style: l8St(11, w: FontWeight.w600, c: available ? const Color(0xFF0F7A52) : const Color(0xFF8F5400)))),
              ]),
            ),
            const SizedBox(width: 8),
            l8Pill('Proposer', onTap: onPropose),
          ]),
        ),
      );
}

/// « 12 talents » (« 1 talent ») : le nombre de résultats lus par le serveur ; en démonstration, les talents disponibles de la maquette.
class TalentsCount extends ConsumerWidget {
  const TalentsCount({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String plural(int n) => '$n talent${n > 1 ? 's' : ''}';
    if (!Backend.ready) {
      final n = ref.watch(visibleTalentsProvider).where((t) => t.showStatus ? t.available : true).length;
      return Text('${plural(n)} disponibles', style: l8St(15, w: FontWeight.w700));
    }
    final list = ref.watch(talentSearchProvider).asData?.value;
    if (list == null) return const SizedBox.shrink();
    final more = list.length >= ref.watch(talentLimitProvider) && list.length < 50;
    return Text(list.isEmpty ? '' : '${plural(list.length)}${more ? ' ou plus' : ''}', style: l8St(15, w: FontWeight.w700));
  }
}
