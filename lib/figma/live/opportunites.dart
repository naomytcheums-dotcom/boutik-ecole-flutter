import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouter;
import '../nav.dart' show gOpen;
import 'auth.dart';
import 'access.dart' show roleKey;
import 'company_screens.dart' show companyProvider, companyStatusLabel;
import 'ent_f3b.dart' show EntButton, openNeedForm;
import 'entreprise.dart';
import 's8_etudiant.dart';

/// Opportunités (écrans 157 Résumé de mes besoins, 203 Mes compétences, 204 Coup de pouce startup) :
/// uniquement des données réelles. Les offres recommandées (152) sont dans l8_opportunites.dart, classées par le score de correspondance du serveur.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

Widget _intro(double w, String t) => SizedBox(width: w, child: Text(t, style: _st(12.5, c: _grey).copyWith(height: 1.5)));

/// 157 : résumé calculé sur les propositions et besoins de l'entreprise.
class CompanySummary extends ConsumerWidget {
  const CompanySummary({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget note(String t) => Container(width: width, height: 150, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey)));
    if (ref.watch(authProvider.select((a) => a.current == null))) return note('Connectez-vous pour voir votre résumé.');
    if (roleKey(ref.watch(authProvider).current) == 'student') return StudentApplicationsSummary(width: width, height: height);
    final props = ref.watch(companyProposalsProvider);
    final missions = ref.watch(companyMissionsProvider);
    if (props == null || missions == null) return note('Chargement…');
    if (ref.read(companyProposalsProvider.notifier).error || ref.read(companyMissionsProvider.notifier).error) {
      return Container(
        width: width,
        height: 190,
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Résumé indisponible pour le moment.', style: _st(13, c: _grey)),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () {
              ref.invalidate(companyProposalsProvider);
              ref.invalidate(companyMissionsProvider);
            },
            child: Text('Réessayer', style: _st(13, w: FontWeight.w700, c: const Color(0xFF5A3FE0))),
          ),
        ]),
      );
    }
    final c = companyCounters(missions, props, DateTime.now());
    final company = ref.watch(companyProvider).asData?.value;
    Widget tile(String l, String v, String screen) => Expanded(
          child: Semantics(
            button: true,
            label: '$l : $v',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => gOpen(context, screen),
              child: Container(constraints: const BoxConstraints(minHeight: 72), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: _st(11.5, c: _grey)), const SizedBox(height: 6), Text(v, style: _st(22, w: FontWeight.w800))])),
            ),
          ),
        );
    final empty = missions.isEmpty && props.isEmpty;
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (company != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${company['company_name'] ?? ''} · ${companyStatusLabel('${company['status']}')}', style: _st(12.5, c: _grey))),
          Row(children: [tile('Propositions reçues', '${c.proposals}', '93'), const SizedBox(width: 12), tile('À examiner', '${c.toReview}', '93')]),
          const SizedBox(height: 12),
          Row(children: [tile('Besoins publiés', '${c.needs}', '99'), const SizedBox(width: 12), tile('Échéances sous 7 jours', '${c.deadlines}', '99')]),
          const SizedBox(height: 12),
          Row(children: [tile('Collaborations en cours', '${c.collaborations}', '98'), const SizedBox(width: 12), const Expanded(child: SizedBox.shrink())]),
          const SizedBox(height: 18),
          if (empty) ...[
            Text('Vous n’avez encore publié aucun besoin.\nDécrivez ce que vous cherchez : les talents qualifiés vous envoient leurs propositions.', style: _st(13, c: _grey).copyWith(height: 1.5)),
            const SizedBox(height: 12),
            EntButton('Publier un besoin', () => openNeedForm(context), icon: Icons.add),
          ] else ...[
            Text('Dernières propositions', style: _st(15, w: FontWeight.w700)),
            const SizedBox(height: 6),
            if (props.isEmpty)
              Text('Aucune proposition reçue pour le moment.', style: _st(13, c: _grey))
            else
              for (final p in props.take(5))
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openProposal(context, ref, p),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['author']}', style: _st(13.5, w: FontWeight.w600)), Text('${p['mission']} · ${proposalStatus(p['status'])}', style: _st(11.5, c: _grey))])),
                      const Icon(Icons.chevron_right, size: 20, color: _grey),
                    ]),
                  ),
                ),
            const SizedBox(height: 12),
            EntButton('Publier un besoin', () => openNeedForm(context), dark: false, icon: Icons.add),
          ],
          const SizedBox(height: 12),
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
      _intro(width, 'Demandez un accompagnement (mentor, financement, matériel, compétences) pour l’un de vos projets : le département répond et vous suivez l’état de chaque demande. Aucun financement n’est promis.'),
      const SizedBox(height: 10),
      SizedBox(width: width, child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => GoRouter.of(context).push('/accompagnement'),
        child: Container(height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(4)), child: Text('Mon accompagnement', style: _st(14, w: FontWeight.w700, c: Colors.white))),
      )),
      const SizedBox(height: 14),
      MobileList(provider: projectsCatalogProvider, title: (r) => '${r['title']}', subtitle: (r) => [if ('${r['department'] ?? ''}'.isNotEmpty) '${r['department']}', '${r['summary'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '), trailing: (r) => projectStatus(r['status']), emptyText: 'Aucun projet pour le moment.', width: width, height: (height - 180).clamp(120.0, double.infinity)),
    ]);
  }
}
