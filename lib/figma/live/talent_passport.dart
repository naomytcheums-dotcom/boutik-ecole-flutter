import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'backend.dart';
import 'innovations_screens.dart' show levelColors, levelLabels;
import 'tp_ui.dart';

/// Talent Passport réel (écran 74 et profil d'une autre personne) : compétences avec niveau, années et justificatif, niveau de points
/// et badges calculés sur des données réelles (RPC talent_passport). Rien n'est inventé : une section vide est dite vide.

const _skillLevelLabels = {'debutant': 'Débutant', 'intermediaire': 'Intermédiaire', 'avance': 'Avancé', 'expert': 'Expert'};
const _skillLevelFraction = {'debutant': .25, 'intermediaire': .5, 'avance': .75, 'expert': 1.0};

String passportSkillLevel(Object? level) => _skillLevelLabels['$level'] ?? '';
double passportLevelFraction(Object? level) => _skillLevelFraction['$level'] ?? .25;

String passportYears(Object? y) {
  final n = (y as num?)?.toDouble();
  if (n == null) return '';
  if (n == 0) return 'moins d’un an';
  final t = n == n.roundToDouble() ? n.round().toString() : n.toString().replaceAll('.', ',');
  return '$t an${n > 1 ? 's' : ''}';
}

/// Libellé d'un badge du passport (code et nombre renvoyés par le serveur) ; vide pour un code inconnu.
String passportBadgeLabel(String code, int n, {String level = 'none'}) {
  String plural(String one, String many) => n > 1 ? '$n $many' : '$n $one';
  return switch (code) {
    'certified' => 'Profil certifié par l’établissement',
    'certificates' => plural('certificat Boutik-École', 'certificats Boutik-École'),
    'verified_documents' => plural('pièce justificative vérifiée', 'pièces justificatives vérifiées'),
    'proven_skills' => plural('compétence justifiée par une pièce vérifiée', 'compétences justifiées par une pièce vérifiée'),
    'expert_skills' => plural('compétence de niveau Expert', 'compétences de niveau Expert'),
    'missions' => plural('mission menée à terme', 'missions menées à terme'),
    'helper' => levelLabels[level] ?? 'Aidant',
    _ => '',
  };
}

final talentPassportProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, userId) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  final r = await Backend.rpc('talent_passport', {if (userId.isNotEmpty) 'p_user': userId});
  if (r.error != null) throw StateError(r.error!);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

/// Contenu du passport : [userId] vide = le mien.
class TalentPassportSection extends ConsumerWidget {
  const TalentPassportSection({super.key, this.userId = '', this.width = 342});
  final String userId;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(talentPassportProvider(userId));
    return SizedBox(
      width: width,
      child: async.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
        error: (_, _) => Row(children: [
          Expanded(child: Text('Le passport ne peut pas être chargé pour le moment.', style: tpSt(12.5, c: tpRed))),
          TextButton(onPressed: () => ref.invalidate(talentPassportProvider(userId)), child: Text('Réessayer', style: tpSt(12.5, w: FontWeight.w700, c: tpViolet))),
        ]),
        data: (p) => p == null ? Text('Ce passport n’est pas visible : le profil est masqué ou introuvable.', style: tpSt(12.5, c: tpGrey, h: 1.45)) : _body(p),
      ),
    );
  }

  Widget _body(Map<String, dynamic> p) {
    final own = p['own'] == true;
    final level = '${p['level'] ?? 'none'}';
    final points = (p['points'] as num?)?.toInt() ?? 0;
    final skills = [for (final s in (p['skills'] as List? ?? const [])) if (s is Map) Map<String, dynamic>.from(s)];
    final badges = [
      for (final b in (p['badges'] as List? ?? const []))
        if (b is Map && passportBadgeLabel('${b['code']}', (b['count'] as num?)?.toInt() ?? 1, level: level).isNotEmpty) (code: '${b['code']}', text: passportBadgeLabel('${b['code']}', (b['count'] as num?)?.toInt() ?? 1, level: level)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: (levelColors[level] ?? tpGrey).withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
          child: Text(levelLabels[level] ?? 'Pas encore de niveau', style: tpSt(12.5, w: FontWeight.w700, c: levelColors[level] ?? tpGrey)),
        ),
        const SizedBox(width: 10),
        Text('$points point${points > 1 ? 's' : ''}', style: tpSt(12, c: tpGrey)),
      ]),
      const SizedBox(height: 16),
      Text('Niveau des compétences', style: tpSt(15, w: FontWeight.w700)),
      const SizedBox(height: 8),
      if (skills.isEmpty)
        Text(own ? 'Aucune compétence dans votre Talent Passport. Ajoutez-en avec « Mes compétences ».' : 'Aucune compétence détaillée pour le moment.', style: tpSt(12.5, c: tpGrey))
      else
        for (final s in skills)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${s['skill']}', style: tpSt(13.5, w: FontWeight.w700))),
                Text(passportSkillLevel(s['level']), style: tpSt(12, w: FontWeight.w700, c: tpViolet)),
              ]),
              Text([s['domain'], if ('${s['job'] ?? ''}'.isNotEmpty) s['job']].join(' · '), style: tpSt(11.5, c: tpGrey)),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: passportLevelFraction(s['level']), minHeight: 6, backgroundColor: const Color(0xFFE9E5F5), color: tpViolet)),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Wrap(spacing: 10, children: [
                  if (s['years'] != null) Text('Expérience : ${passportYears(s['years'])}', style: tpSt(11.5, c: tpGrey)),
                  if (s['proof_verified'] == true) Text('Justificatif vérifié', style: tpSt(11.5, w: FontWeight.w600, c: tpGreen))
                  else if (s['has_proof'] == true) Text('Justificatif joint (non vérifié)', style: tpSt(11.5, c: tpGrey)),
                ]),
              ),
            ]),
          ),
      const SizedBox(height: 6),
      Text('Badges', style: tpSt(15, w: FontWeight.w700)),
      const SizedBox(height: 8),
      if (badges.isEmpty)
        Text(own ? 'Aucun badge pour le moment : ils apparaissent avec la certification, vos pièces vérifiées, vos missions et vos points.' : 'Aucun badge pour le moment.', style: tpSt(12.5, c: tpGrey, h: 1.45))
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final b in badges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: const Color(0xFFF4EFE6), borderRadius: BorderRadius.circular(14)),
              child: Text(b.text, style: tpSt(12, w: FontWeight.w600)),
            ),
        ]),
      if (own) ...[
        const SizedBox(height: 10),
        Text('Le niveau, les années d’expérience et l’état du justificatif de vos compétences sont visibles de ceux qui peuvent voir votre profil ; la description et le fichier du justificatif restent privés.', style: tpSt(11.5, c: tpGrey, h: 1.45)),
      ],
    ]);
  }
}

const _providerNames = {'facebook': 'Facebook', 'instagram': 'Instagram', 'linkedin': 'LinkedIn', 'tiktok': 'TikTok', 'youtube': 'YouTube', 'github': 'GitHub', 'behance': 'Behance'};

String importedProviderName(Object? id) => _providerNames['$id'] ?? '$id';

/// Contenus importés des réseaux connectés que la personne a choisi de montrer (« Portfolio » ou « Public ») ; les contenus privés n'apparaissent jamais ici
/// sauf dans MON portfolio (RPC profile_imported_items).
final importedItemsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) async {
  final r = await Backend.rpc('profile_imported_items', {if (userId.isNotEmpty) 'p_user': userId});
  if (r.error != null) throw StateError(r.error!);
  return [for (final x in (r.data is List ? r.data as List : const [])) if (x is Map) Map<String, dynamic>.from(x)];
}, retry: (_, _) => null);

class ImportedItemsSection extends ConsumerWidget {
  const ImportedItemsSection({super.key, this.userId = ''});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final own = userId.isEmpty;
    final async = ref.watch(importedItemsProvider(userId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        final shown = own ? items.where((x) => x['visibility'] != 'private').toList() : items;
        if (shown.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          Text('Contenus de mes réseaux', style: tpSt(15, w: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final x in shown)
            TpCard(
              onTap: '${x['url'] ?? ''}'.isEmpty ? null : () => tpOpenUrl(context, '${x['url']}'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${x['title'] ?? ''}'.isEmpty ? importedProviderName(x['provider']) : '${x['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: tpSt(14, w: FontWeight.w700)),
                Text(importedProviderName(x['provider']), style: tpSt(11.5, c: tpGrey)),
                if ('${x['body'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${x['body']}', maxLines: 3, overflow: TextOverflow.ellipsis, style: tpSt(12.5, h: 1.4))),
              ]),
            ),
        ]);
      },
    );
  }
}

/// Passport d'une autre personne (depuis son profil).
class TalentPassportPage extends StatelessWidget {
  const TalentPassportPage({super.key, required this.userId, this.ownerName = ''});
  final String userId;
  final String ownerName;

  @override
  Widget build(BuildContext context) => TpPage(
        title: 'Talent Passport',
        subtitle: ownerName.isEmpty ? null : ownerName,
        children: [TalentPassportSection(userId: userId)],
      );
}
