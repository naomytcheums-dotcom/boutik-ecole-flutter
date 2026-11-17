import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gAlert, gDialog, gToast;
import '../i18n.dart' show Text;
import '../nav.dart' show gOpen;
import 'auth.dart' show authProvider;
import 'backend.dart';
import 'company_public_page.dart' show openCompanyPublic;
import 'company_screens.dart' show companyProvider, companyStatusColor, companyStatusLabel;
import 'tp_ui.dart' show TpButton, TpEmpty, TpPage, tpGrey, tpNote, tpSt, tpViolet;
import 'docs_prestataire.dart' show downloadMissionInvoice;
import 'entreprise.dart';
import 'lots.dart' show missionDossierDialog, payStatusLabel;
import 'missions.dart';
import 'need_pages.dart' show MyNeedsPage, NeedFormPage;
import 'opportunites_screens.dart' show oppMyPostedProvider;
import 'quote_negotiation.dart' show openQuoteNegotiation;
import 'store.dart' show fcfa;

/// Espace entreprise sur téléphone (écrans 93, 93b, 94, 95, 96, 97, 98, 99, 285) : pastilles qui filtrent vraiment, lignes qui ouvrent une fiche,
/// comparaison des propositions cochées, décisions confirmées, recrutement et espace projet lus sur les données réelles du serveur.
/// Aucune note, aucun classement ni aucune analyse « IA » : seules les données disponibles sont comparées.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
const _violet = Color(0xFF5A3FE0);
const _green = Color(0xFF0F7A52);
const _red = Color(0xFFC0261B);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink, double? h}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: h);

String _money(Object? v) => fcfa(((v is num ? v : num.tryParse('$v')) ?? 0).toInt());

Widget _note(String t, double width, {Widget? action, double height = 190}) => Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey, h: 1.5)), ?action]),
    );

/// Bouton plein ou à contour, d'au moins 48 dp de haut.
class EntButton extends StatelessWidget {
  const EntButton(this.label, this.onTap, {super.key, this.dark = true, this.danger = false, this.icon});
  final String label;
  final VoidCallback? onTap;
  final bool dark, danger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = danger ? _red : _ink;
    final fg = dark ? Colors.white : color;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: dark ? color : Colors.transparent, border: dark ? null : Border.all(color: danger ? _red : const Color(0xFFD9D3E6), width: 1.5), borderRadius: BorderRadius.circular(24)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w700, c: fg))),
          ]),
        ),
      ),
    );
  }
}

/// Pastilles de filtre : une seule active à la fois, zone de toucher de 48 dp, défilement horizontal si elles débordent.
class EntChips extends StatelessWidget {
  const EntChips({super.key, required this.labels, required this.selected, required this.onChanged, this.width = 342});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 48,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (var i = 0; i < labels.length; i++)
            Semantics(
              button: true,
              selected: i == selected,
              label: labels[i],
              excludeSemantics: true,
              onTap: () => onChanged(i),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Center(
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: i == selected ? _ink : const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(17)),
                      child: Text(labels[i], softWrap: false, style: _st(12.5, w: i == selected ? FontWeight.w600 : FontWeight.w500, c: i == selected ? Colors.white : _grey)),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// Liste de lignes déjà filtrées (offres, devis…) : titre, sous-titre, pastille de statut, ligne cliquable de 56 dp au moins.
class EntRows extends StatelessWidget {
  const EntRows({super.key, required this.rows, required this.title, required this.subtitle, this.trailing, this.onTap, required this.emptyText, this.width = 342, this.height = 400});
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) title, subtitle;
  final String Function(Map<String, dynamic>)? trailing;
  final void Function(Map<String, dynamic>)? onTap;
  final String emptyText;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return _note(emptyText, width);
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 4, thickness: 1, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final r = rows[i];
          final content = ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title(r), maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(13.5, w: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle(r), maxLines: 3, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                  ]),
                ),
              ),
              if (trailing != null && trailing!(r).isNotEmpty) ...[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(11)), child: Text(trailing!(r), maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11, w: FontWeight.w600, c: _violet))),
                ),
              ],
              if (onTap != null) const Icon(Icons.chevron_right, size: 20, color: _grey),
            ]),
          );
          if (onTap == null) return content;
          return Semantics(button: true, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => onTap!(r), child: content));
        },
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------------------ 93 : propositions reçues

bool _isOpen(Map<String, dynamic> r) => const {'submitted', 'pending'}.contains('${r['status']}') && '${r['mission_status']}' != 'cancelled';
bool _isRefused(Map<String, dynamic> r) => const {'declined', 'rejected', 'withdrawn'}.contains('${r['status']}');

class ProposalsPanel extends ConsumerStatefulWidget {
  const ProposalsPanel({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  ConsumerState<ProposalsPanel> createState() => _ProposalsPanelState();
}

class _ProposalsPanelState extends ConsumerState<ProposalsPanel> {
  int chip = 0;

  bool _match(int c, Map<String, dynamic> r) => switch (c) {
        1 => _isOpen(r),
        2 => '${r['status']}' == 'accepted',
        3 => _isRefused(r),
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(companyProposalsProvider) ?? const <Map<String, dynamic>>[];
    final sel = ref.watch(proposalSelectionProvider);
    int n(int c) => all.where((r) => _match(c, r)).length;
    final labels = ['Toutes (${n(0)})', 'Reçues (${n(1)})', 'Acceptées (${n(2)})', 'Refusées (${n(3)})'];
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EntChips(labels: labels, selected: chip, onChanged: (i) => setState(() => chip = i), width: widget.width),
        SizedBox(
          height: 40,
          child: Row(children: [
            Expanded(child: Text(sel.isEmpty ? 'Touchez une proposition pour l’ouvrir ; cochez-en au moins deux pour les comparer.' : '${sel.length} proposition${sel.length > 1 ? 's' : ''} cochée${sel.length > 1 ? 's' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey))),
            if (sel.isNotEmpty) TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 40)), onPressed: ref.read(proposalSelectionProvider.notifier).clear, child: Text('Effacer', style: _st(12, w: FontWeight.w700, c: _violet))),
          ]),
        ),
        MobileList(
          provider: companyProposalsProvider,
          width: widget.width,
          height: widget.height - 88,
          where: (r) => _match(chip, r),
          selection: sel,
          onToggle: ref.read(proposalSelectionProvider.notifier).toggle,
          onRow: openProposal,
          title: (r) => '${r['author']}',
          subtitle: (r) => '${_money(r['amount'])} · ${daysLabel(r['delay_days'])} · ${r['mission']}',
          trailing: (r) => proposalStatus(r['status']),
          emptyText: chip == 0 ? 'Aucune proposition reçue pour le moment.\nLes propositions apparaissent ici quand des étudiants répondent à vos besoins.' : 'Aucune proposition dans cette catégorie.',
        ),
      ]),
    );
  }
}

/// Fond du bouton « Comparer la sélection » : sombre avec au moins deux propositions cochées, grisé sinon.
class CompareButtonFace extends ConsumerWidget {
  const CompareButtonFace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(proposalSelectionProvider.select((s) => s.length >= 2));
    return DecoratedBox(
      decoration: BoxDecoration(color: ready ? _ink : const Color(0xFF8D8A96), borderRadius: BorderRadius.circular(27), boxShadow: const [BoxShadow(color: Color(0x24122640), offset: Offset(0, 4), blurRadius: 10)]),
    );
  }
}

void compareSelection(BuildContext context, WidgetRef ref) {
  if (ref.read(proposalSelectionProvider).length < 2) {
    gToast(context, 'Cochez au moins deux propositions pour les comparer.');
    return;
  }
  gOpen(context, '94');
}

// ------------------------------------------------------------------------------------------------------------ 93b : fiche d'une proposition

Map<String, dynamic>? _openedProposal(WidgetRef ref) {
  final id = ref.read(openedProposalProvider);
  for (final p in ref.read(companyProposalsProvider) ?? const <Map<String, dynamic>>[]) {
    if ('${p['id']}' == id) return p;
  }
  return null;
}

/// Vrai quand la proposition ouverte attend une décision (les boutons Refuser / Accepter ne s'affichent alors que dans ce cas).
bool openedProposalIsOpen(WidgetRef ref) {
  final id = ref.watch(openedProposalProvider);
  for (final p in ref.watch(companyProposalsProvider) ?? const <Map<String, dynamic>>[]) {
    if ('${p['id']}' == id) return _isOpen(p);
  }
  return false;
}

/// Fiche de la proposition ouverte : auteur abrégé, offre, message et jalons prévus. Aucun avis ni note inventés.
class ProposalDetail extends ConsumerWidget {
  const ProposalDetail({super.key, this.width = 342, this.height = 600});
  final double width, height;

  Widget _line(String k, String v, {Color? c}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(k, style: _st(12.5, c: _grey))),
          const SizedBox(width: 12),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: _st(12.5, w: FontWeight.w700, c: c ?? _ink))),
        ]),
      );

  Widget _card(String title, List<Widget> kids) => Container(
        width: width,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _st(14, w: FontWeight.w700)), const SizedBox(height: 6), ...kids]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(openedProposalProvider);
    final all = ref.watch(companyProposalsProvider);
    if (id.isEmpty) {
      return _note('Aucune proposition ouverte.\nChoisissez-en une dans « Propositions reçues ».', width, action: EntButton('Voir les propositions', () => gOpen(context, '93'), dark: false));
    }
    if (all == null) return _note('Chargement…', width);
    if (ref.read(companyProposalsProvider.notifier).error) {
      return _note('Cette proposition ne peut pas être chargée pour le moment.', width, action: TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => ref.invalidate(companyProposalsProvider), child: Text('Réessayer', style: _st(13, w: FontWeight.w700, c: _violet))));
    }
    final matches = all.where((p) => '${p['id']}' == id);
    if (matches.isEmpty) {
      return _note('Cette proposition n’est plus disponible.\nElle a peut-être été retirée ou le besoin supprimé.', width, action: EntButton('Voir les propositions', () => gOpen(context, '93'), dark: false));
    }
    final p = matches.first;
    final amount = ((p['amount'] as num?) ?? 0).toInt();
    final m1 = (amount * 0.3).round(), m2 = (amount * 0.4).round(), m3 = amount - m1 - m2;
    final projects = ((p['author_projects'] as num?) ?? 0).toInt();
    final message = '${p['message'] ?? ''}'.trim();
    final attempts = ((p['attempts'] as num?) ?? 1).toInt();
    final authorId = '${p['author_id'] ?? ''}';
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 25, backgroundColor: const Color(0xFFEEE9FF), child: Text('${p['author']}'.isEmpty ? '?' : '${p['author']}'.substring(0, 1).toUpperCase(), style: _st(18, w: FontWeight.w700, c: _violet))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['author']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(15, w: FontWeight.w700)),
                Text([p['author_certified'] == true ? 'Compte certifié' : 'Compte non certifié', '$projects projet${projects > 1 ? 's' : ''} public${projects > 1 ? 's' : ''}'].join(' · '), style: _st(11.5, c: p['author_certified'] == true ? _green : _grey)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: EntButton('Voir le profil', authorId.isEmpty ? null : () => GoRouter.of(context).push('/etudiant/$authorId'), dark: false, icon: Icons.person_outline)),
            const SizedBox(width: 8),
            Expanded(child: EntButton('Poser une question', authorId.isEmpty ? null : () => _askAuthor(context, ref, authorId, '${p['author']}'), dark: false, icon: Icons.chat_bubble_outline)),
          ]),
          const SizedBox(height: 14),
          _card('Offre', [
            _line('Besoin', '${p['mission']}'),
            _line('Montant', _money(amount)),
            _line('Délai', daysLabel(p['delay_days'])),
            _line('Statut', proposalStatus(p['status']), c: '${p['status']}' == 'accepted' ? _green : (_isRefused(p) ? _red : _ink)),
            _line('Reçue le', dateCourte(p['created_at'])),
            if (attempts > 1) _line('Dépôt', 'n° $attempts'),
          ]),
          _card('Message du talent', [Text(message.isEmpty ? 'Aucun message joint à cette proposition.' : message, style: _st(13, c: message.isEmpty ? _grey : const Color(0xFF4A4854), h: 1.5))]),
          _card('Jalons prévus si vous acceptez', [
            _line('1 · Brief validé (30 %)', _money(m1)),
            _line('2 · Propositions (40 %)', _money(m2)),
            _line('3 · Livraison finale (30 %)', _money(m3)),
            Text('Chaque jalon est livré avec une preuve, puis validé par vous. Boutik-École ne verse aucun argent : le paiement se règle directement avec le prestataire.', style: _st(11.5, c: _grey, h: 1.45)),
          ]),
          if (!_isOpen(p)) Text(const {'accepted': 'Cette proposition a été acceptée : la mission est attribuée.'}['${p['status']}'] ?? (_isRefused(p) ? 'Cette proposition n’est plus en attente.' : 'Ce besoin n’accepte plus de décision.'), style: _st(12, c: _grey, h: 1.45)),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

Future<void> _askAuthor(BuildContext context, WidgetRef ref, String authorId, String name) async {
  final ctrl = TextEditingController();
  final text = await gDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Question à $name', style: _st(16, w: FontWeight.w700)),
      content: TextField(controller: ctrl, maxLength: 1000, maxLines: 4, decoration: const InputDecoration(labelText: 'Votre question', border: OutlineInputBorder())),
      actions: [
        TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Envoyer')),
      ],
    ),
  );
  ctrl.dispose();
  if (text == null || text.isEmpty || !context.mounted) return;
  final r = await Backend.startDirectConversation(authorId, 'À propos de ma proposition de mission :\n\n$text');
  if (!context.mounted) return;
  if (r.error != null) {
    await gAlert(context, 'Message non envoyé', Backend.userMessage(r.error!));
    return;
  }
  gToast(context, 'Question envoyée : la réponse arrive dans vos messages.');
}

class _DecisionDialog extends StatefulWidget {
  const _DecisionDialog({required this.accept, required this.title, required this.text});
  final bool accept;
  final String title, text;

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(widget.title, style: _st(16, w: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.text, style: _st(13, c: _grey, h: 1.5)),
            if (!widget.accept) ...[
              const SizedBox(height: 12),
              TextField(controller: ctrl, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: 'Motif (facultatif, transmis au talent)', border: OutlineInputBorder())),
            ],
          ]),
        ),
        actions: [
          TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48), backgroundColor: widget.accept ? _ink : _red),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(widget.accept ? 'Accepter' : 'Refuser'),
          ),
        ],
      );
}

/// Accepter ou refuser la proposition ouverte : confirmation, motif de refus facultatif, effet réel (decide_proposal), puis listes relues.
Future<void> decideOpenedProposal(BuildContext context, WidgetRef ref, {required bool accept}) async {
  final p = _openedProposal(ref);
  if (p == null) {
    gToast(context, 'Ouvrez d’abord une proposition depuis « Propositions reçues ».');
    return;
  }
  if (!_isOpen(p)) {
    gToast(context, '${p['status']}' == 'accepted' ? 'Cette proposition est déjà acceptée.' : 'Cette proposition est déjà traitée.');
    return;
  }
  if (accept && '${p['mission_status']}' != 'published') {
    gToast(context, 'Ce besoin est déjà attribué : vous ne pouvez plus accepter d’autre proposition.');
    return;
  }
  final who = '${p['author']}';
  final reason = await gDialog<String>(
    context: context,
    builder: (_) => _DecisionDialog(
      accept: accept,
      title: accept ? 'Accepter la proposition de $who ?' : 'Refuser la proposition de $who ?',
      text: accept
          ? 'La mission est attribuée à $who pour ${_money(p['amount'])} en ${daysLabel(p['delay_days'])}. Les autres propositions reçues pour ce besoin sont refusées et leurs auteurs prévenus. Trois jalons (30 / 40 / 30 %) sont créés. Cette décision est définitive.'
          : 'L’auteur est prévenu que sa proposition n’est pas retenue. Vous ne pouvez pas revenir sur ce refus.',
    ),
  );
  if (reason == null || !context.mounted) return;
  final missionNotifier = ref.read(missionProvider.notifier);
  final container = ProviderScope.containerOf(context, listen: false);
  final r = await Backend.rpc('decide_proposal', {'p_id': p['id'], 'p_accept': accept, if (!accept && reason.isNotEmpty) 'p_reason': reason});
  if (!context.mounted) return;
  if (r.error != null) {
    await gAlert(context, 'Action impossible', Backend.userMessage(r.error!));
    return;
  }
  await refreshCompanyData(container);
  missionNotifier.refresh();
  if (!context.mounted) return;
  gToast(context, accept ? 'Proposition acceptée : la mission est attribuée.' : 'Proposition refusée : son auteur est prévenu.');
  if (accept) {
    selectMission(ref, '${p['mission_id']}');
    gOpen(context, '285');
  }
}

// ------------------------------------------------------------------------------------------------------------ 94 : comparaison

/// Compare les propositions cochées sur les seules données disponibles : montant, délai, certification de l'auteur, projets publics.
class CompareProposals extends ConsumerStatefulWidget {
  const CompareProposals({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  ConsumerState<CompareProposals> createState() => _CompareProposalsState();
}

class _CompareProposalsState extends ConsumerState<CompareProposals> {
  int sort = 0;

  List<Map<String, dynamic>> selected() {
    final ids = ref.watch(proposalSelectionProvider);
    final rows = [for (final p in ref.watch(companyProposalsProvider) ?? const <Map<String, dynamic>>[]) if (ids.contains('${p['id']}')) p];
    num amount(Map<String, dynamic> r) => (r['amount'] as num?) ?? 0;
    num delay(Map<String, dynamic> r) => (r['delay_days'] as num?) ?? 0;
    num projects(Map<String, dynamic> r) => (r['author_projects'] as num?) ?? 0;
    rows.sort((a, b) => switch (sort) {
          1 => delay(a).compareTo(delay(b)),
          2 => projects(b).compareTo(projects(a)),
          _ => amount(a).compareTo(amount(b)),
        });
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = selected();
    if (rows.length < 2) {
      return _note('Aucune comparaison à afficher.\nCochez au moins deux propositions dans « Propositions reçues ».', widget.width, action: EntButton('Voir les propositions', () => gOpen(context, '93'), dark: false));
    }
    num minOf(num Function(Map<String, dynamic>) f) => rows.map(f).reduce((a, b) => a < b ? a : b);
    final minAmount = minOf((r) => (r['amount'] as num?) ?? 0), minDelay = minOf((r) => (r['delay_days'] as num?) ?? 0);
    final distinctAmounts = rows.map((r) => r['amount']).toSet().length > 1, distinctDelays = rows.map((r) => r['delay_days']).toSet().length > 1;
    Widget line(String k, String v, {Color? c}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [Expanded(child: Text(k, style: _st(12, c: _grey))), Text(v, style: _st(12.5, w: FontWeight.w700, c: c ?? _ink))]),
        );
    Widget tag(String t) => Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFDDF5EC), borderRadius: BorderRadius.circular(9)), child: Text(t, style: _st(10.5, w: FontWeight.w700, c: _green)));
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EntChips(labels: const ['Prix', 'Délai', 'Portfolio'], selected: sort, onChanged: (i) => setState(() => sort = i), width: widget.width),
        Text(const ['Du moins cher au plus cher.', 'Du plus rapide au plus long.', 'Du plus grand nombre de projets publics au plus petit.'][sort], style: _st(11.5, c: _grey)),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = rows[i];
              final projects = ((r['author_projects'] as num?) ?? 0).toInt();
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text('${r['author']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(14, w: FontWeight.w700))),
                    if (distinctAmounts && ((r['amount'] as num?) ?? 0) == minAmount) tag('Le moins cher'),
                    if (distinctDelays && ((r['delay_days'] as num?) ?? 0) == minDelay) tag('Le plus rapide'),
                  ]),
                  Text('${r['mission']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(11.5, c: _grey)),
                  const SizedBox(height: 6),
                  line('Montant', _money(r['amount'])),
                  line('Délai', daysLabel(r['delay_days'])),
                  line('Certification', r['author_certified'] == true ? 'Compte certifié' : 'Non certifié', c: r['author_certified'] == true ? _green : _grey),
                  line('Projets publics', '$projects'),
                  line('Statut', proposalStatus(r['status'])),
                  const SizedBox(height: 6),
                  EntButton('Ouvrir la proposition', () => openProposal(context, ref, r), dark: false),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// « Choisir une proposition » (94) : choisit, parmi les propositions comparées, celle à ouvrir en fiche pour la décider.
Future<void> chooseCompared(BuildContext context, WidgetRef ref) async {
  final ids = ref.read(proposalSelectionProvider);
  final rows = [for (final p in ref.read(companyProposalsProvider) ?? const <Map<String, dynamic>>[]) if (ids.contains('${p['id']}')) p];
  if (rows.length < 2) {
    gToast(context, 'Cochez au moins deux propositions dans « Propositions reçues ».');
    return;
  }
  final chosen = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Colors.white,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.all(16), child: Text('Quelle proposition ouvrir ?', style: _st(15, w: FontWeight.w700))),
        for (final r in rows)
          ListTile(minTileHeight: 56, title: Text('${r['author']}'), subtitle: Text('${_money(r['amount'])} · ${daysLabel(r['delay_days'])}'), onTap: () => Navigator.pop(ctx, r)),
      ]),
    ),
  );
  if (chosen != null && context.mounted) openProposal(context, ref, chosen);
}

// ------------------------------------------------------------------------------------------------------------ 95 : devis

class QuotesPanel extends ConsumerStatefulWidget {
  const QuotesPanel({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  ConsumerState<QuotesPanel> createState() => _QuotesPanelState();
}

class _QuotesPanelState extends ConsumerState<QuotesPanel> {
  int chip = 0;

  bool _match(int c, Map<String, dynamic> r) {
    final s = '${r['status']}';
    return switch (c) {
      1 => s == 'accepted',
      2 => const {'refused', 'declined', 'rejected', 'cancelled', 'expired'}.contains(s),
      _ => const {'requested', 'quoted'}.contains(s),
    };
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.width,
        height: widget.height,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          EntChips(labels: const ['En cours', 'Acceptés', 'Refusés'], selected: chip, onChanged: (i) => setState(() => chip = i), width: widget.width),
          MobileList(
            provider: quotesListProvider,
            width: widget.width,
            height: widget.height - 52,
            where: (r) => _match(chip, r),
            onRow: (context, ref, r) => openQuoteNegotiation(context, ref, r),
            title: (r) => '${r['brief']}',
            subtitle: (r) => r['quote_amount'] == null ? 'En attente de devis' : '${_money(r['quote_amount'])} · ${daysLabel(r['quote_delay_days'])}',
            trailing: (r) => quoteStatus(r['status']),
            emptyText: const ['Aucun devis en cours.\nVos demandes de devis apparaissent ici.', 'Aucun devis accepté pour le moment.', 'Aucun devis refusé, annulé ou expiré.'][chip],
          ),
        ]),
      );
}

// ------------------------------------------------------------------------------------------------------------ 96 : défis

String _kindLabel(Object? k) => const {'contest': 'Concours', 'hackathon': 'Hackathon', 'call': 'Appel à projets'}['$k'] ?? '$k';

String defiPrize(Map<String, dynamic> r) {
  final amount = ((r['prize_amount'] as num?) ?? 0).toInt();
  if (amount > 0) return fcfa(amount);
  return '${r['reward'] ?? ''}'.trim();
}

String defiDateLine(Map<String, dynamic> r) {
  final deadline = parseDate(r['deadline']), opens = parseDate(r['opens_on']);
  return switch ('${r['phase']}') {
    'upcoming' => opens == null ? 'À venir' : 'Ouvre le ${dateCourte(opens)}',
    'ended' => deadline == null ? 'Terminé' : 'Terminé le ${dateCourte(deadline)}',
    _ => deadline == null ? 'Sans date limite' : 'Clôture le ${dateCourte(deadline)}',
  };
}

/// Texte posé sur la bannière : nombre de défis ouverts et à venir (données réelles).
class DefisBanner extends ConsumerWidget {
  const DefisBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(defisListProvider);
    final open = rows?.where((r) => '${r['phase']}' == 'open').length ?? 0, soon = rows?.where((r) => '${r['phase']}' == 'upcoming').length ?? 0;
    return Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Concours et hackathons', style: _st(18, w: FontWeight.w700, c: Colors.white)),
      const SizedBox(height: 4),
      Text(rows == null ? 'Chargement…' : '$open ouvert${open > 1 ? 's' : ''} · $soon à venir', style: _st(12, c: const Color(0xFFE3ECF7))),
    ]);
  }
}

class DefisPanel extends ConsumerStatefulWidget {
  const DefisPanel({super.key, this.width = 342, this.height = 420});
  final double width, height;

  @override
  ConsumerState<DefisPanel> createState() => _DefisPanelState();
}

class _DefisPanelState extends ConsumerState<DefisPanel> {
  int phase = 0, kind = 0;

  @override
  Widget build(BuildContext context) {
    const phases = ['open', 'upcoming', 'ended'];
    const kinds = ['', 'contest', 'hackathon', 'call'];
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EntChips(labels: const ['Ouverts', 'À venir', 'Terminés'], selected: phase, onChanged: (i) => setState(() => phase = i), width: widget.width),
        EntChips(labels: const ['Tous', 'Concours', 'Hackathons', 'Appels'], selected: kind, onChanged: (i) => setState(() => kind = i), width: widget.width),
        MobileList(
          provider: defisListProvider,
          width: widget.width,
          height: widget.height - 96,
          where: (r) => '${r['phase']}' == phases[phase] && (kinds[kind].isEmpty || '${r['kind']}' == kinds[kind]),
          onRow: (context, ref, r) {
            final id = '${r['id'] ?? ''}';
            if (id.isNotEmpty) GoRouter.of(context).push('/concours/$id');
          },
          title: (r) => '${r['title']}',
          subtitle: (r) => ['${r['organizer'] ?? ''}', _kindLabel(r['kind']), defiDateLine(r)].where((e) => e.isNotEmpty).join(' · '),
          trailing: defiPrize,
          emptyText: const ['Aucun défi ouvert pour le moment.', 'Aucun défi à venir pour le moment.', 'Aucun défi terminé pour le moment.'][phase],
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------------------------ 97 : recrutement

const _offerStatus = {'pending': 'En attente', 'published': 'Publiée', 'rejected': 'Refusée', 'closed': 'Clôturée'};

/// Offres publiées par l'entreprise (stages, emplois…) et leurs candidatures : liens vers la publication et le suivi des offres.
class RecruitPanel extends ConsumerStatefulWidget {
  const RecruitPanel({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  ConsumerState<RecruitPanel> createState() => _RecruitPanelState();
}

class _RecruitPanelState extends ConsumerState<RecruitPanel> {
  int chip = 0;

  bool _match(int c, Map<String, dynamic> r) => switch (c) {
        1 => '${r['kind']}' == 'stage',
        2 => '${r['kind']}' == 'emploi',
        3 => !const {'stage', 'emploi'}.contains('${r['kind']}'),
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final posted = ref.watch(oppMyPostedProvider);
    final w = widget.width;
    Widget body() => posted.when(
          loading: () => _note('Chargement…', w),
          error: (_, _) => _note('Vos offres ne peuvent pas être chargées pour le moment.', w, action: TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => ref.invalidate(oppMyPostedProvider), child: Text('Réessayer', style: _st(13, w: FontWeight.w700, c: _violet)))),
          data: (all) {
            final rows = [for (final r in all) if (_match(chip, r)) r];
            final apps = all.fold<int>(0, (a, r) => a + (((r['applications'] as num?) ?? 0).toInt()));
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${all.length} offre${all.length > 1 ? 's' : ''} · $apps candidature${apps > 1 ? 's' : ''} reçue${apps > 1 ? 's' : ''}', style: _st(12, c: _grey))),
              EntRows(
                rows: rows,
                width: w,
                height: widget.height - 48 - 24 - 110,
                emptyText: all.isEmpty ? 'Vous n’avez publié aucune offre.\nPubliez un stage ou un emploi pour recevoir des candidatures.' : 'Aucune offre dans cette catégorie.',
                title: (r) => '${r['title']}',
                subtitle: (r) {
                  final n = ((r['applications'] as num?) ?? 0).toInt();
                  return '$n candidature${n > 1 ? 's' : ''}${'${r['kind']}'.isEmpty ? '' : ' · ${const {'stage': 'Stage', 'emploi': 'Emploi'}['${r['kind']}'] ?? 'Autre offre'}'}';
                },
                trailing: (r) => _offerStatus['${r['status']}'] ?? '${r['status']}',
                onTap: (r) => GoRouter.of(context).push('/opportunites/${r['id']}/candidatures'),
              ),
            ]);
          },
        );
    return SizedBox(
      width: w,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EntChips(labels: const ['Toutes', 'Stages', 'Emplois', 'Autres'], selected: chip, onChanged: (i) => setState(() => chip = i), width: w),
        Expanded(child: body()),
        EntButton('Publier une offre', () => GoRouter.of(context).push('/opportunites/publier'), icon: Icons.add),
        const SizedBox(height: 6),
        EntButton('Mes offres et candidatures', () => GoRouter.of(context).push('/opportunites/mes'), dark: false),
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------------------------ 98 : collaborations, 99 : historique

/// Ouvre le dossier d'une mission (espace projet : contrat, jalons, messagerie).
void openMissionSpace(BuildContext context, WidgetRef ref, Map<String, dynamic> row) {
  final id = '${row['id'] ?? ''}';
  if (id.isEmpty) return;
  selectMission(ref, id);
  gOpen(context, '285');
}

class CollabPanel extends ConsumerStatefulWidget {
  const CollabPanel({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  ConsumerState<CollabPanel> createState() => _CollabPanelState();
}

class _CollabPanelState extends ConsumerState<CollabPanel> {
  int chip = 0;

  bool _match(int c, Map<String, dynamic> r) {
    final s = '${r['status']}';
    return switch (c) {
      1 => s == 'delivered',
      2 => const {'closed', 'completed', 'released'}.contains(s),
      _ => const {'assigned', 'in_progress'}.contains(s),
    };
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(companyMissionsProvider) ?? const <Map<String, dynamic>>[];
    int n(int c) => all.where((r) => _match(c, r)).length;
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EntChips(labels: ['En cours (${n(0)})', 'Livrées (${n(1)})', 'Terminées'], selected: chip, onChanged: (i) => setState(() => chip = i), width: widget.width),
        MobileList(
          provider: companyMissionsProvider,
          width: widget.width,
          height: widget.height - 52,
          where: (r) => _match(chip, r),
          onRow: openMissionSpace,
          title: (r) => '${r['title']}',
          subtitle: (r) => ('${r['team']}'.isEmpty ? 'Équipe en cours d’attribution' : 'Équipe : ${r['team']}') + (deadlineOf(r) == null ? '' : ' · pour le ${dateCourte(deadlineOf(r))}'),
          trailing: (r) => missionStatus(r['status']),
          emptyText: const ['Aucune collaboration en cours.\nUn besoin attribué à une équipe apparaît ici.', 'Aucune mission livrée à valider.', 'Aucune mission terminée pour le moment.'][chip],
        ),
      ]),
    );
  }
}

class HistoryPanel extends ConsumerStatefulWidget {
  const HistoryPanel({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  ConsumerState<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<HistoryPanel> {
  int chip = 0;

  @override
  Widget build(BuildContext context) {
    final missions = ref.watch(companyMissionsProvider) ?? const <Map<String, dynamic>>[];
    final props = ref.watch(companyProposalsProvider) ?? const <Map<String, dynamic>>[];
    final c = companyCounters(missions, props, DateTime.now());
    final w = widget.width;
    const dossier = {'assigned', 'in_progress', 'delivered', 'closed', 'completed', 'released'};
    final summary = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('${c.needs} besoin${c.needs > 1 ? 's' : ''} publié${c.needs > 1 ? 's' : ''} · ${missions.where((m) => dossier.contains('${m['status']}')).length} mission${missions.where((m) => dossier.contains('${m['status']}')).length > 1 ? 's' : ''} · ${c.deadlines} échéance${c.deadlines > 1 ? 's' : ''} sous 7 jours', style: _st(12, c: _grey)),
    );
    final Widget list = switch (chip) {
      1 => MobileList(
          provider: quotesListProvider,
          width: w,
          height: widget.height - 48 - 28,
          onRow: (context, ref, r) => openQuoteNegotiation(context, ref, r),
          title: (r) => '${r['brief']}',
          subtitle: (r) => r['quote_amount'] == null ? 'En attente de devis' : '${_money(r['quote_amount'])} · ${daysLabel(r['quote_delay_days'])}',
          trailing: (r) => quoteStatus(r['status']),
          emptyText: 'Aucune demande de devis pour le moment.',
        ),
      2 => MobileList(
          provider: companyMissionsProvider,
          width: w,
          height: widget.height - 48 - 28,
          where: (r) => dossier.contains('${r['status']}'),
          onRow: openMissionSpace,
          title: (r) => '${r['title']}',
          subtitle: (r) => ('${r['team']}'.isEmpty ? 'Équipe en cours d’attribution' : 'Équipe : ${r['team']}') + (deadlineOf(r) == null ? '' : ' · pour le ${dateCourte(deadlineOf(r))}'),
          trailing: (r) => missionStatus(r['status']),
          emptyText: 'Aucune mission attribuée pour le moment.',
        ),
      3 => ref.watch(oppMyPostedProvider).when(
            loading: () => _note('Chargement…', w),
            error: (_, _) => _note('Vos offres ne peuvent pas être chargées pour le moment.', w, action: TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => ref.invalidate(oppMyPostedProvider), child: Text('Réessayer', style: _st(13, w: FontWeight.w700, c: _violet)))),
            data: (all) => EntRows(
              rows: all,
              width: w,
              height: widget.height - 48 - 28,
              emptyText: 'Vous n’avez publié aucune offre.',
              title: (r) => '${r['title']}',
              subtitle: (r) {
                final n = ((r['applications'] as num?) ?? 0).toInt();
                return '$n candidature${n > 1 ? 's' : ''}';
              },
              trailing: (r) => _offerStatus['${r['status']}'] ?? '${r['status']}',
              onTap: (r) => GoRouter.of(context).push('/opportunites/${r['id']}/candidatures'),
            ),
          ),
      _ => MobileList(
          provider: companyMissionsProvider,
          width: w,
          height: widget.height - 48 - 28,
          onRow: (context, ref, r) {
            if (dossier.contains('${r['status']}')) return openMissionSpace(context, ref, r);
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MyNeedsPage()));
          },
          title: (r) => '${r['title']}',
          subtitle: (r) => '${needDateLine(r)} · ${proposalsCount(r['proposals'])}',
          trailing: (r) => missionStatus(r['status']),
          emptyText: 'Vous n’avez publié aucun besoin pour le moment.',
        ),
    };
    return SizedBox(
      width: w,
      height: widget.height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        EntChips(labels: const ['Besoins', 'Devis', 'Missions', 'Offres'], selected: chip, onChanged: (i) => setState(() => chip = i), width: w),
        summary,
        list,
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------------------------ 285 : espace projet

/// Contrat (accord), jalons et messagerie du projet choisi, lus sur le serveur ; libellé honnête quand une donnée n'existe pas encore.
class ProjectSpacePanel extends ConsumerWidget {
  const ProjectSpacePanel({super.key, this.width = 342, this.height = 540});
  final double width, height;

  Widget _card(String title, List<Widget> kids) => Container(
        width: width,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8F2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: _st(14, w: FontWeight.w700)), const SizedBox(height: 6), ...kids]),
      );

  Widget _line(String k, String v, {Color? c}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(k, style: _st(12.5, c: _grey))), const SizedBox(width: 12), Flexible(child: Text(v, textAlign: TextAlign.right, style: _st(12.5, w: FontWeight.w700, c: c ?? _ink)))]),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(missionProvider);
    final loaded = ref.watch(missionLoadedProvider);
    final choices = ref.watch(missionChoicesProvider);
    if (!m.real) {
      if (!loaded) {
        return _note('Chargement…', width, action: TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: ref.read(missionProvider.notifier).refresh, child: Text('Réessayer', style: _st(13, w: FontWeight.w700, c: _violet))));
      }
      return _note('Aucun projet en cours.\nQuand vous acceptez une proposition, le contrat, les jalons et la messagerie du projet apparaissent ici.', width, action: EntButton('Voir les propositions reçues', () => gOpen(context, '93'), dark: false));
    }
    final selected = choices.indexWhere((c) => '${c['id']}' == m.uuid);
    final steps = m.steps;
    Color stateColor(String s) => s == 'Validé' ? _green : (s == 'Livré, à valider' ? const Color(0xFF8F5400) : _grey);
    return SizedBox(
      width: width,
      height: height,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (choices.length > 1)
            EntChips(
              labels: [for (final c in choices) '${c['title'] ?? c['number']}'],
              selected: selected < 0 ? 0 : selected,
              onChanged: (i) => selectMission(ref, '${choices[i]['id']}'),
              width: width,
            ),
          Text(m.kind, maxLines: 2, overflow: TextOverflow.ellipsis, style: _st(16, w: FontWeight.w700)),
          Text(missionStatusLabel(m.status), style: _st(12, c: _grey)),
          const SizedBox(height: 10),
          _card('Contrat de mission', [
            _line('Montant convenu', m.total > 0 ? fcfa(m.total) : 'Non défini'),
            _line('Accord', m.invoice.isEmpty ? 'Pas encore d’accord enregistré' : 'N° ${m.invoice}', c: m.invoice.isEmpty ? _grey : _green),
            _line(m.isProvider ? 'Client' : 'Équipe', m.isProvider ? (m.counterpart.isEmpty ? 'Client Boutik-École' : m.counterpart) : (m.team.isEmpty ? 'À attribuer' : m.team)),
            if (m.deadline.isNotEmpty) _line('Livraison', m.deadline),
            if (m.invoice.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: EntButton('Voir la facture de mission (PDF)', () => downloadMissionInvoice(context, ref, m.uuid), dark: false)),
          ]),
          _card('Jalons', [
            if (steps.isEmpty) Text('Les jalons sont définis lors de l’attribution de la mission.', style: _st(12.5, c: _grey, h: 1.4)),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4, right: 10), decoration: BoxDecoration(color: stateColor(steps[i].$2), shape: BoxShape.circle)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${i + 1} · ${steps[i].$1}', style: _st(13, w: FontWeight.w600)),
                      Text(m.milestoneAmounts.length > i ? fcfa(m.milestoneAmounts[i]) : '', style: _st(11.5, c: _grey)),
                      if (steps[i].$2 == 'Validé' && i < m.pays.length) Text(payStatusLabel(m.pays[i], ''), style: _st(11, c: _grey, h: 1.35)),
                    ]),
                  ),
                  Text(steps[i].$2, style: _st(11.5, w: FontWeight.w700, c: stateColor(steps[i].$2))),
                ]),
              ),
          ]),
          _card('Messagerie du projet', [
            Text('Échangez avec ${m.isProvider ? 'le client' : (m.counterpart.isEmpty ? 'l’équipe retenue' : m.counterpart)} et déposez les fichiers du projet.', style: _st(12.5, c: _grey, h: 1.4)),
            const SizedBox(height: 8),
            EntButton('Ouvrir la messagerie du projet', () => missionDossierDialog(context, ref), dark: false, icon: Icons.chat_bubble_outline),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

/// Libellé et action du bouton du bas de l'espace projet : valider le jalon livré, sinon ouvrir la messagerie, sinon retrouver les propositions.
({String label, VoidCallback action}) projectSpaceAction(BuildContext context, WidgetRef ref) {
  final m = ref.watch(missionProvider);
  if (!m.real) return (label: 'Voir les propositions reçues', action: () => gOpen(context, '93'));
  final j = deliveredMilestone(m);
  if (j != null && m.isClient) return (label: 'Valider le jalon ${j.position}', action: () => releaseMilestone(ref, context));
  return (label: 'Ouvrir la messagerie du projet', action: () => missionDossierDialog(context, ref));
}

/// Raccourci : publier un besoin depuis un état vide.
void openNeedForm(BuildContext context) => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NeedFormPage()));

/// Publier une offre (stage, emploi) : formulaire du module Opportunités.
void openOfferForm(BuildContext context) => GoRouter.of(context).push('/opportunites/publier');

// ------------------------------------------------------------------------------------------------------------ 89 : profil de l'entreprise

/// Fiche réelle de l'entreprise (company_get) : raison sociale, secteur, statut de vérification réel, indicateurs calculés, accès à la page publique.
/// Plus de texte figé, de badge toujours affiché, de réseau social, de « Suivre » ni de « Portfolio ».
class CompanyProfileView extends ConsumerWidget {
  const CompanyProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) {
      return const TpPage(title: 'Profil de l’entreprise', children: [TpEmpty(title: 'Connexion requise', text: 'Connectez-vous avec votre compte entreprise pour voir votre fiche.')]);
    }
    final company = ref.watch(companyProvider);
    final missions = ref.watch(companyMissionsProvider) ?? const <Map<String, dynamic>>[];
    final props = ref.watch(companyProposalsProvider) ?? const <Map<String, dynamic>>[];
    final c = companyCounters(missions, props, DateTime.now());
    Widget stat(String label, int n, String screen) => Expanded(
          child: Semantics(
            button: true,
            label: '$label : $n',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => gOpen(context, screen),
              child: Container(
                constraints: const BoxConstraints(minHeight: 64),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF4F3F6), borderRadius: BorderRadius.circular(16)),
                child: Column(children: [Text('$n', style: tpSt(18, w: FontWeight.w800)), Text(label, textAlign: TextAlign.center, style: tpSt(11, c: tpGrey))]),
              ),
            ),
          ),
        );
    return TpPage(
      title: 'Profil de l’entreprise',
      children: [
        company.when(
          loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
          error: (_, _) => TpEmpty(title: 'Fiche indisponible', text: 'La fiche de votre entreprise ne peut pas être chargée pour le moment.', icon: Icons.cloud_off_rounded, action: 'Réessayer', onAction: () => ref.invalidate(companyProvider)),
          data: (f) {
            if (f == null) {
              return TpEmpty(title: 'Aucune fiche entreprise', text: 'Renseignez la raison sociale, le secteur et les pièces justificatives : une fois la fiche vérifiée, vous pouvez publier des besoins, des offres et des défis.', icon: Icons.business_outlined, action: 'Compléter la fiche', onAction: () => GoRouter.of(context).push('/entreprise/profil'));
            }
            final name = '${f['company_name'] ?? ''}'.trim();
            final status = '${f['status'] ?? ''}';
            final approved = status == 'approved';
            final sub = [for (final k in ['sector', 'city']) if ('${f[k] ?? ''}'.trim().isNotEmpty) '${f[k]}'.trim()].join(' · ');
            final desc = '${f['description'] ?? ''}'.trim();
            final extra = [
              if ('${f['website'] ?? ''}'.trim().isNotEmpty) 'Site : ${f['website']}'.trim(),
              if ('${f['size'] ?? ''}'.trim().isNotEmpty) 'Effectif : ${f['size']}',
              if ('${f['founded_year'] ?? ''}'.trim().isNotEmpty) 'Créée en ${f['founded_year']}',
            ];
            return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(height: 8),
              CircleAvatar(radius: 44, backgroundColor: const Color(0xFFEEE9FF), child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: tpSt(34, w: FontWeight.w700, c: tpViolet))),
              const SizedBox(height: 12),
              Text(name.isEmpty ? 'Entreprise' : name, textAlign: TextAlign.center, style: tpSt(22, w: FontWeight.w700)),
              if (sub.isNotEmpty) Text(sub, textAlign: TextAlign.center, style: tpSt(12.5, c: tpGrey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: companyStatusColor(status).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (approved) Icon(Icons.verified, size: 16, color: companyStatusColor(status)),
                  if (approved) const SizedBox(width: 6),
                  Flexible(child: Text(companyStatusLabel(status), textAlign: TextAlign.center, style: tpSt(12, w: FontWeight.w700, c: companyStatusColor(status)))),
                ]),
              ),
              if (desc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Text(desc, textAlign: TextAlign.center, style: tpSt(13, c: const Color(0xFF4A4854), h: 1.5))),
              for (final line in extra) Padding(padding: const EdgeInsets.only(top: 6), child: Text(line, textAlign: TextAlign.center, style: tpSt(12.5, c: tpGrey))),
              const SizedBox(height: 18),
              Row(children: [stat('Besoins publiés', c.needs, '99'), stat('Propositions', c.proposals, '93'), stat('Collaborations', c.collaborations, '98')]),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: TpButton('Publier un besoin', () => openNeedForm(context), icon: Icons.add_rounded)),
              const SizedBox(height: 10),
              if (approved) SizedBox(width: double.infinity, child: TpButton('Voir ma page publique', () => openCompanyPublic(context, '${f['owner_id']}'), dark: false, icon: Icons.public)) else tpNote('La page publique de l’entreprise est affichée après la vérification de la fiche.'),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: TpButton('Modifier la fiche', () => GoRouter.of(context).push('/entreprise/profil'), dark: false, icon: Icons.edit_outlined)),
            ]);
          },
        ),
      ],
    );
  }
}
