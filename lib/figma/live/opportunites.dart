import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';
import 'console.dart';
import 'entreprise.dart';
import 'store.dart' show fcfa;

/// Opportunités (écrans 152 Kéla te recommande, 157 Résumé de Kéla, 203 Mes compétences, 204 Coup de pouce startup) :
/// uniquement des données réelles. Aucun pourcentage d'adéquation n'est affiché : le classement par Kéla n'existe pas encore côté serveur.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

final openMissionsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('missions', 'title,budget_min,budget_max,status,created_at,deadline', order: 'created_at'));

Widget _intro(double w, String t) => SizedBox(width: w, child: Text(t, style: _st(12.5, c: _grey).copyWith(height: 1.5)));

String _budget(Map<String, dynamic> r) {
  int? v(Object? x) => (x as num?)?.toInt();
  final a = v(r['budget_min']), b = v(r['budget_max']);
  if (a == null && b == null) return 'Budget non précisé';
  if (a == null || a == b) return fcfa((b ?? a)!);
  return '${fcfa(a)} – ${fcfa(b!)}';
}

/// 152 : besoins réellement ouverts, du plus récent au plus ancien.
class OpenOffers extends ConsumerWidget {
  const OpenOffers({super.key, this.width = 342, this.height = 440});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _intro(width, 'Voici les besoins actuellement ouverts. Le classement personnalisé par Kéla arrive bientôt.'),
        const SizedBox(height: 14),
        MobileList(
          provider: openMissionsProvider,
          where: (r) => '${r['status']}' == 'published',
          title: (r) => '${r['title']}',
          subtitle: (r) => '${_budget(r)} · publié le ${dateCourte(r['created_at'])}',
          emptyText: 'Aucune offre ouverte pour le moment.',
          width: width,
          height: height - 60,
        ),
      ]);
}

/// 157 : résumé calculé sur les propositions et besoins de l'entreprise.
class CompanySummary extends ConsumerWidget {
  const CompanySummary({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t) => Container(width: width, height: 150, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey)));
    if (ref.watch(authProvider.select((a) => a.current == null))) return note('Connectez-vous pour voir votre résumé.');
    final props = ref.watch(companyProposalsProvider);
    final missions = ref.watch(companyMissionsProvider);
    if (props == null || missions == null) return note('Chargement…');
    if (ref.read(companyProposalsProvider.notifier).error || ref.read(companyMissionsProvider.notifier).error) return note('Résumé indisponible pour le moment.');
    final received = props.length;
    final pending = props.where((p) => '${p['status']}' == 'submitted' || '${p['status']}' == 'pending').length;
    final now = DateTime.now();
    final soon = missions.where((m) {
      final d = DateTime.tryParse('${m['deadline'] ?? ''}');
      return d != null && d.isAfter(now) && d.difference(now).inDays <= 7;
    }).length;
    Widget tile(String l, String v) => Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: _st(11.5, c: _grey)), const SizedBox(height: 6), Text(v, style: _st(22, w: FontWeight.w800))])));
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [tile('Propositions reçues', '$received'), const SizedBox(width: 12), tile('À examiner', '$pending')]),
          const SizedBox(height: 12),
          Row(children: [tile('Besoins publiés', '${missions.length}'), const SizedBox(width: 12), tile('Échéances sous 7 jours', '$soon')]),
          const SizedBox(height: 22),
          Text('Dernières propositions', style: _st(15, w: FontWeight.w700)),
          const SizedBox(height: 10),
          if (props.isEmpty)
            Text('Aucune proposition reçue pour le moment.', style: _st(13, c: _grey))
          else
            for (final p in props.take(5))
              Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['author']}', style: _st(13.5, w: FontWeight.w600)), Text('${p['mission']} · ${proposalStatus(p['status'])}', style: _st(11.5, c: _grey))])),
        ]),
      ),
    );
  }
}

/// 203 : compétences déclarées sur le profil. Aucun score : le calcul de fiabilité n'existe pas encore.
class MySkills extends ConsumerWidget {
  const MySkills({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return SizedBox(width: width, child: Text('Connectez-vous pour voir vos compétences.', style: _st(13, c: _grey)));
    final a = ref.watch(profileAccountProvider);
    final skills = [for (final s in a.skills.split(RegExp(r'[,;\n]'))) if (s.trim().isNotEmpty) s.trim()];
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Domaines déclarés', style: _st(16, w: FontWeight.w700)),
        const SizedBox(height: 12),
        if (skills.isEmpty)
          Text('Aucune compétence renseignée.\nAjoutez-les depuis votre profil pour être mieux repéré.', style: _st(13, c: _grey).copyWith(height: 1.5))
        else
          Wrap(spacing: 8, runSpacing: 8, children: [for (final s in skills) Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(16)), child: Text(s, style: _st(12.5, w: FontWeight.w600, c: const Color(0xFF5A3FE0))))]),
        const SizedBox(height: 22),
        Text('Le score global, les avis et le respect des délais seront affichés ici quand des missions auront été notées.', style: _st(12, c: _grey).copyWith(height: 1.5)),
      ]),
    );
  }
}

/// 204 : projets réellement enregistrés ; le financement et les mentors ne sont pas encore suivis en ligne.
class StartupSupport extends ConsumerWidget {
  const StartupSupport({super.key, this.width = 342, this.height = 480});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(projectsCatalogProvider);
    final n = rows?.where((r) => '${r['status']}' == 'approved').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(n == null ? 'Projets validés : …' : 'Projets validés : $n', style: _st(16, w: FontWeight.w700)),
      const SizedBox(height: 6),
      _intro(width, 'Le suivi du financement et des mentors n’est pas encore disponible en ligne.'),
      const SizedBox(height: 14),
      MobileList(provider: projectsCatalogProvider, title: (r) => '${r['title']}', subtitle: (r) => [if ('${r['department'] ?? ''}'.isNotEmpty) '${r['department']}', '${r['summary'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '), trailing: (r) => projectStatus(r['status']), emptyText: 'Aucun projet pour le moment.', width: width, height: height - 90),
    ]);
  }
}
