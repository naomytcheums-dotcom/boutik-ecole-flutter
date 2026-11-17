import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gdata.dart' show gNetImage;
import '../i18n.dart' show Text;
import 'backend.dart';
import 'f4_api.dart';
import 'company_screens.dart' show companySizes, companyStatusColor, companyStatusLabel;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'share.dart' show openUrl, shareText, siteUrl;
import 'tp_ui.dart' show GlassBack;

/// Page publique d'une entreprise : ce que voient les autres comptes. Tout vient de la fonction serveur company_public
/// (fiche approuvée uniquement pour les autres ; jamais RCCM, téléphone, interlocuteur, pièces ni identité de facturation).

/// Lien public de la page d'une entreprise.
String companyPageLink(String ownerId) => '$siteUrl/#/entreprise/fiche/${Uri.encodeComponent(ownerId.trim())}';

/// Fiche publique de l'entreprise [id] ; null quand aucune fiche n'est visible (inexistante, non vérifiée ou compte suspendu : même réponse).
final companyPublicProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, id) async {
  final r = await ref.read(f4RpcProvider)('company_public', {'p_owner': id});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

/// Page publique d'une entreprise (fiche vérifiée). [fallback] : affiché quand l'entreprise n'a aucune fiche visible (le profil de la personne, par exemple).
class CompanyPublicPage extends ConsumerWidget {
  const CompanyPublicPage({super.key, required this.ownerId, this.fallback});
  final String ownerId;
  final Widget Function()? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyPublicProvider(ownerId));
    return async.when(
      loading: () => _shell(context, const Center(child: CircularProgressIndicator())),
      error: (e, _) {
        if (fallback != null && e is MarcheException && (e.code == 'offline' || e.code == 'missing')) return fallback!();
        return _shell(context, _Retry(message: e is MarcheException ? e.toString() : marcheErrorText('$e'), onRetry: () => ref.invalidate(companyPublicProvider(ownerId))));
      },
      data: (c) {
        if (c == null) {
          if (fallback != null) return fallback!();
          return _shell(context, mNote('Cette entreprise n’a pas de fiche publique pour le moment.\nSeules les entreprises vérifiées ont une page visible par les autres.'));
        }
        return _shell(
          context,
          _Body(c: c, onRefresh: () async => ref.refresh(companyPublicProvider(ownerId).future)),
          title: '${c['company_name'] ?? 'Entreprise'}',
          share: c['verified'] == true ? () => shareText(context, 'Découvrez ${c['company_name']} sur Boutik-École : ${companyPageLink(ownerId)}', subject: '${c['company_name']} sur Boutik-École') : null,
        );
      },
    );
  }

  Widget _shell(BuildContext context, Widget child, {String title = 'Entreprise', VoidCallback? share}) => Scaffold(
        backgroundColor: const Color(0xFFF7F4FA),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: SizedBox(
                height: 48,
                child: Row(children: [
                  Semantics(button: true, label: 'Retour', excludeSemantics: true, child: GlassBack(onTap: () => context.canPop() ? context.pop() : context.go('/s/03'))),
                  Expanded(child: Text(title, maxLines: 1, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: mst(18, w: FontWeight.w800))),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: share == null ? null : IconButton(tooltip: 'Partager la page de l’entreprise', icon: const Icon(Icons.ios_share_rounded, color: kInk), onPressed: share),
                  ),
                ]),
              ),
            ),
            Expanded(child: child),
          ]),
        ),
      );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5)),
            const SizedBox(height: 14),
            mButton('Réessayer', onRetry, dark: false, icon: Icons.refresh_rounded),
          ]),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.c, required this.onRefresh});
  final Map<String, dynamic> c;
  final Future<void> Function() onRefresh;

  List<Map<String, dynamic>> _list(String k) => [for (final x in (c[k] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  @override
  Widget build(BuildContext context) {
    final verified = c['verified'] == true;
    final status = '${c['status'] ?? ''}';
    final mine = c['mine'] == true;
    final cover = '${c['cover_path'] ?? ''}', logo = '${c['logo_path'] ?? ''}';
    final site = '${c['website'] ?? ''}';
    final line = [
      if ('${c['sector'] ?? ''}'.isNotEmpty) '${c['sector']}',
      if ('${c['city'] ?? ''}'.isNotEmpty) '${c['city']}',
      if ('${c['size'] ?? ''}'.isNotEmpty) companySizes['${c['size']}'] ?? '',
      if (c['founded_year'] != null) 'Depuis ${c['founded_year']}',
    ].where((e) => e.isNotEmpty).join(' · ');
    final offers = _list('offers'), contests = _list('contests'), needs = _list('needs');
    final stats = <(String, int?)>[
      ('Offres ouvertes', (c['offers_open'] as num?)?.toInt()),
      ('Besoins ouverts', (c['needs_open'] as num?)?.toInt()),
      ('Défis ouverts', (c['contests_open'] as num?)?.toInt()),
      ('Recrutés', (c['recruits'] as num?)?.toInt()),
    ].where((s) => s.$2 != null).toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 132,
            child: cover.isEmpty
                ? Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF5A3FE0), Color(0xFF9B7BFF)])))
                : gNetImage(Backend.postMediaUrl(cover), fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFEFEBFA))),
          ),
        ),
        Transform.translate(
          offset: const Offset(12, -30),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)]),
              clipBehavior: Clip.antiAlias,
              child: logo.isEmpty ? const Icon(Icons.business, color: kViolet, size: 30) : gNetImage(Backend.postMediaUrl(logo), fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.business, color: kViolet)),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c['company_name'] ?? ''}', style: mst(22, w: FontWeight.w800)),
            const SizedBox(height: 6),
            if (verified)
              Row(children: [
                const Icon(Icons.verified_rounded, size: 18, color: kGreen),
                const SizedBox(width: 6),
                Text('Entreprise vérifiée', style: mst(13, w: FontWeight.w700, c: kGreen)),
              ])
            else if (status.isNotEmpty)
              Row(children: [Icon(Icons.info_outline, size: 18, color: companyStatusColor(status)), const SizedBox(width: 6), Flexible(child: Text(companyStatusLabel(status), style: mst(12.5, w: FontWeight.w700, c: companyStatusColor(status))))]),
            if (line.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(line, style: mst(13, c: kGrey))),
            if (mine && !verified)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Cette page n’est visible que de vous et de votre équipe : elle devient publique après la vérification de l’entreprise.', style: mst(12.5, c: kGrey).copyWith(height: 1.4)),
              ),
          ]),
        ),
        if ('${c['description'] ?? ''}'.trim().isNotEmpty) Text('${c['description']}'.trim(), style: mst(14).copyWith(height: 1.5)),
        if (site.isNotEmpty) ...[const SizedBox(height: 12), mButton('Visiter le site', () => openUrl(context, site), dark: false, icon: Icons.language_rounded)],
        if (mine) ...[const SizedBox(height: 10), mButton('Modifier la fiche', () => context.push('/entreprise/profil'), dark: false, icon: Icons.edit_outlined)],
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final s in stats) _Stat(label: s.$1, value: s.$2!)]),
        if (offers.isNotEmpty) ...[
          mSectionTitle('Offres en cours'),
          for (final o in offers) _Tile(title: '${o['title']}', subtitle: [_kind('${o['kind']}'), if ('${o['location'] ?? ''}'.isNotEmpty) '${o['location']}', if (o['deadline'] != null) 'Avant le ${_date('${o['deadline']}')}'].join(' · '), onTap: () => context.push('/opportunites/${o['id']}')),
        ],
        if (contests.isNotEmpty) ...[
          mSectionTitle('Défis et concours'),
          for (final o in contests) _Tile(title: '${o['title']}', subtitle: [if (o['deadline'] != null) 'Avant le ${_date('${o['deadline']}')}'].join(' · '), onTap: () => context.push('/concours/${o['id']}')),
        ],
        if (needs.isNotEmpty) ...[
          mSectionTitle('Besoins en cours'),
          for (final n in needs) _Tile(title: '${n['title']}', subtitle: _budget(n), onTap: () => context.push('/marche/appels')),
        ],
        if (offers.isEmpty && contests.isEmpty && needs.isEmpty)
          Padding(padding: const EdgeInsets.only(top: 18), child: Text('Aucune offre, aucun défi ni aucun besoin ouvert pour le moment.', textAlign: TextAlign.center, style: mst(13, c: kGrey))),
      ]),
    );
  }

  static String _kind(String k) => const {'stage': 'Stage', 'emploi': 'Emploi', 'mission': 'Mission', 'defi': 'Défi', 'benevolat': 'Bénévolat', 'formation': 'Formation', 'contest': 'Concours', 'hackathon': 'Hackathon', 'scholarship': 'Bourse'}[k] ?? 'Offre';

  static String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _budget(Map<String, dynamic> n) {
    final a = (n['budget_min'] as num?)?.toInt(), b = (n['budget_max'] as num?)?.toInt();
    String f(int v) => v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');
    final parts = [
      if (a != null && b != null) 'Budget : ${f(a)} à ${f(b)} FCFA' else if (b != null) 'Budget : jusqu’à ${f(b)} FCFA' else if (a != null) 'Budget : dès ${f(a)} FCFA',
      if ('${n['deadline'] ?? ''}'.isNotEmpty) 'Échéance : ${n['deadline']}',
    ];
    return parts.join(' · ');
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('$value', style: mst(20, w: FontWeight.w800)),
          Text(label, style: mst(11.5, c: kGrey)),
        ]),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.subtitle, required this.onTap});
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: kLine)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(14, w: FontWeight.w700)),
                  if (subtitle.isNotEmpty) Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: mst(12, c: kGrey)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: kGrey),
            ]),
          ),
        ),
      );
}

/// Ouvre la page publique d'une entreprise.
void openCompanyPublic(BuildContext context, String ownerId) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CompanyPublicPage(ownerId: ownerId)));
}
