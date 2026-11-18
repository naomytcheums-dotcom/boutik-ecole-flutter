import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'access.dart' show roleKey;
import 'backend.dart';
import 'inert_actions.dart' show uiSoon;
import 'l10_ui.dart';
import 'lots.dart' show copyText;
import 'qr.dart' show QrView;
import 'share.dart' show openUrl, shareText, siteUrl;
import 'talents.dart' show askText;
import 'vendeur.dart' show MyProfileCard;

/// CV vivant et partage du CV (écrans 227, 228, 229) : lien stable lu sur le serveur (jamais régénéré par une simple copie),
/// consentement avant création, réglages de ce que voient les recruteurs, expiration, désactivation, vrai QR code.
/// La maquette reste servie hors connexion (demoContent).

final cvLinkProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  final r = await Backend.rpc('cv_link_get', {});
  if (r.error != null) throw r.error!;
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

final cvPreviewProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  final r = await Backend.rpc('cv_preview', {});
  if (r.error != null) throw r.error!;
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

final cvPublicProvider = FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, user) async {
  final r = await Backend.rpc('cv_public', {'p_user': user});
  if (r.error != null) throw r.error!;
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

String cvUrl(Object? token) => '$siteUrl/#/cv/$token';

/// Réalisations, missions menées à terme et avis d'un CV (même forme pour l'aperçu, le lien public et le CV d'un talent).
class CvSections extends StatelessWidget {
  const CvSections({super.key, required this.cv, this.identity = true});
  final Map<String, dynamic> cv;
  final bool identity;

  @override
  Widget build(BuildContext context) {
    final skills = [for (final s in '${cv['competences'] ?? ''}'.split(RegExp(r'[,;\n]'))) if (s.trim().isNotEmpty) s.trim()];
    final works = l10Rows(cv['realisations']);
    final levels = l10Rows(cv['competences_niveaux']);
    const levelText = {'debutant': 'Débutant', 'intermediaire': 'Intermédiaire', 'avance': 'Avancé', 'expert': 'Expert'};
    final detailed = {for (final l in levels) '${l['competence']}'.toLowerCase()};
    final chips = [
      for (final l in levels) '${l['competence']} · ${levelText['${l['niveau']}'] ?? ''}',
      for (final s in skills) if (!detailed.contains(s.toLowerCase())) s,
    ];
    const workKinds = {'realisation': 'Réalisation', 'image': 'Image', 'video': 'Vidéo', 'link': 'Lien'};
    final missions = l10Rows(cv['missions']);
    final reviews = cv['avis'] is Map ? Map<String, dynamic>.from(cv['avis'] as Map) : null;
    final last = l10Rows(reviews?['derniers']);
    Widget title(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: l10St(15, w: FontWeight.w700)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (identity) ...[
        Text('${cv['nom'] ?? ''}', style: l10St(22, w: FontWeight.w800)),
        const SizedBox(height: 4),
        Text([cv['departement'], cv['etablissement']].where((x) => x != null && '$x'.isNotEmpty).join(' · '), style: l10St(12.5, c: l10Grey)),
        if (cv['certifie'] == true) Text('✓ Profil certifié par l’établissement', style: l10St(12.5, w: FontWeight.w600, c: const Color(0xFF0F7A52))),
        if ('${cv['bio'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('${cv['bio']}', style: l10St(13.5, w: FontWeight.w400, h: 1.55))),
        if (chips.isNotEmpty) ...[
          title('Compétences'),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final s in chips) l10Chip(s)]),
        ],
      ],
      if (works.isNotEmpty) ...[
        title('Réalisations'),
        for (final w in works)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: l10Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${w['titre']}', style: l10St(13.5, w: FontWeight.w700)),
              if ('${w['categorie'] ?? ''}'.isNotEmpty || '${w['date'] ?? ''}'.isNotEmpty || workKinds.containsKey('${w['type']}')) Text([workKinds['${w['type']}'], w['categorie'], w['date']].where((x) => x != null && '$x'.isNotEmpty).join(' · '), style: l10St(11.5, c: l10Grey)),
              if ('${w['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${w['description']}', style: l10St(12, w: FontWeight.w400, c: const Color(0xFF4A4854), h: 1.45))),
            ])),
          ),
      ],
      if (missions.isNotEmpty) ...[
        title('Missions menées à terme'),
        for (final m in missions) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• ${m['titre']}', style: l10St(13))),
      ],
      if (reviews != null && ((reviews['nombre'] as num?) ?? 0) > 0) ...[
        title('Avis reçus'),
        Text('${reviews['moyenne']} / 5 · ${reviews['nombre']} avis', style: l10St(13, w: FontWeight.w700)),
        for (final r in last) Padding(padding: const EdgeInsets.only(top: 6), child: Text('« ${r['commentaire']} » (${r['note']}/5)', style: l10St(12, w: FontWeight.w400, c: const Color(0xFF4A4854), h: 1.4))),
      ],
      if (works.isEmpty && missions.isEmpty && (reviews == null || ((reviews['nombre'] as num?) ?? 0) == 0))
        Padding(padding: const EdgeInsets.only(top: 18), child: Text('Aucune réalisation, mission terminée ou avis à afficher pour le moment.', style: l10St(12, c: l10Grey))),
    ]);
  }
}

// ------------------------------------------------------------------ 227 : mon CV vivant

class CvLivePanel extends ConsumerWidget {
  const CvLivePanel({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authProvider.select((a) => a.current == null))) return l10Note(width, 'Connectez-vous pour voir votre CV.');
    final preview = ref.watch(cvPreviewProvider);
    return SizedBox(
      width: width,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MyProfileCard(width: width, passport: false),
          preview.when(
            loading: () => l10Note(width, 'Chargement…', height: 60),
            error: (_, _) => l10Note(width, 'Vos réalisations, missions et avis ne peuvent pas être chargés pour le moment.', height: 70),
            data: (cv) => cv == null ? const SizedBox.shrink() : CvSections(cv: cv, identity: false),
          ),
          const SizedBox(height: 18),
          Text('Ce que voient les recruteurs avec votre lien : nom, établissement, présentation, compétences et, selon vos réglages, réalisations, missions terminées et avis. Jamais votre téléphone ni votre e-mail.', style: l10St(11.5, c: l10Grey, h: 1.45)),
          const SizedBox(height: 12),
          l10Btn('Partager mon CV', () => gOpen(context, '228'), width: width),
        ]),
      ),
    );
  }
}

// ------------------------------------------------------------------ 228 : partager mon CV

class CvSharePanel extends ConsumerStatefulWidget {
  const CvSharePanel({super.key, this.width = 342});
  final double width;

  @override
  ConsumerState<CvSharePanel> createState() => _CvSharePanelState();
}

class _CvSharePanelState extends ConsumerState<CvSharePanel> {
  bool consent = false;
  int days = 0;
  bool missions = true, reviews = true, links = true, portfolio = true;
  bool busy = false;

  Future<bool> _call(String fn, Map<String, dynamic> params, String failTitle) async {
    if (busy) return false;
    setState(() => busy = true);
    final r = await Backend.rpc(fn, params);
    if (!mounted) return false;
    setState(() => busy = false);
    if (r.error != null) {
      await gAlert(context, failTitle, r.error!);
      return false;
    }
    ref.invalidate(cvLinkProvider);
    return true;
  }

  Future<bool> _setting(Map<String, dynamic> link, String key, Object value) => _call('cv_link_save', {
        'p_show_missions': link['show_missions'] == true,
        'p_show_reviews': link['show_reviews'] == true,
        'p_show_links': link['show_links'] == true,
        'p_show_portfolio': link['show_portfolio'] == true,
        'p_expires_days': null,
        key: value,
      }, 'Réglage non enregistré');

  Future<void> _create() async {
    if (!consent) return gToast(context, 'Cochez la case pour confirmer que vous acceptez de publier votre CV.');
    if (!await requireLogin(context, ref, 'partager votre CV') || !mounted) return;
    final ok = await _call('cv_link_save', {'p_consent': true, 'p_expires_days': days, 'p_show_missions': missions, 'p_show_reviews': reviews, 'p_show_links': links, 'p_show_portfolio': portfolio}, 'Lien non créé');
    if (ok && mounted) gToast(context, 'Lien créé. Il reste le même tant que vous ne le régénérez pas.');
  }

  Future<bool> _confirm(String title, String body, String ok) async =>
      await gDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(ok))],
        ),
      ) ==
      true;

  Widget _switch(String label, String hint, bool value, ValueChanged<bool> on) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: l10St(13, w: FontWeight.w600)),
        subtitle: Text(hint, style: l10St(11, c: l10Grey)),
        value: value,
        onChanged: on,
      );

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    if (ref.watch(authProvider.select((a) => a.current == null))) return l10Note(w, 'Connectez-vous pour créer le lien de votre CV.');
    return ref.watch(cvLinkProvider).when(
          loading: () => l10Note(w, 'Chargement…'),
          error: (_, _) => l10Note(w, 'Votre lien de CV ne peut pas être chargé pour le moment.'),
          data: (link) => SizedBox(
            width: w,
            child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 40), child: link == null ? _create_(w) : _manage(w, link)),
          ),
        );
  }

  Widget _create_(double w) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Créer mon lien de CV', style: l10St(17, w: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Vous n’avez pas encore de lien. Une fois créé, toute personne qui le possède peut voir votre CV sans compte : nom, établissement, présentation et compétences, plus ce que vous choisissez ci-dessous. Jamais votre téléphone ni votre e-mail.', style: l10St(12.5, w: FontWeight.w400, c: const Color(0xFF4A4854), h: 1.5)),
        const SizedBox(height: 14),
        _switch('Réalisations du portfolio', 'Vos réalisations (8 au plus)', portfolio, (v) => setState(() => portfolio = v)),
        _switch('Missions terminées', 'Titres des missions menées à terme', missions, (v) => setState(() => missions = v)),
        _switch('Avis reçus', 'Note moyenne et derniers commentaires', reviews, (v) => setState(() => reviews = v)),
        _switch('Liens du profil', 'Réseaux et sites que vous avez ajoutés', links, (v) => setState(() => links = v)),
        const SizedBox(height: 8),
        Text('Validité du lien', style: l10St(12.5, w: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [for (final d in const [0, 30, 90]) l10Btn(d == 0 ? 'Sans expiration' : '$d jours', () => setState(() => days = d), dark: days == d, compact: true)]),
        const SizedBox(height: 14),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => consent = !consent),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(consent ? Icons.check_box : Icons.check_box_outline_blank, color: consent ? l10Ink : l10Grey),
            const SizedBox(width: 10),
            Expanded(child: Text('J’accepte que toute personne qui a ce lien puisse voir ces informations. Je pourrai désactiver le lien à tout moment.', style: l10St(12.5, c: const Color(0xFF4A4854), h: 1.4))),
          ]),
        ),
        const SizedBox(height: 18),
        l10Btn(busy ? 'Création…' : 'Créer mon lien', busy ? null : _create, width: w),
      ]);

  Widget _manage(double w, Map<String, dynamic> link) {
    final url = cvUrl(link['token']);
    final expires = DateTime.tryParse('${link['expires_at'] ?? ''}');
    final currentDays = expires == null ? 0 : (expires.difference(DateTime.now()).inDays + 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: QrView(data: url, size: 200)),
      const SizedBox(height: 12),
      Center(child: Text(url, textAlign: TextAlign.center, style: l10St(12, w: FontWeight.w700))),
      const SizedBox(height: 4),
      Center(child: Text(expires == null ? 'Sans expiration · il reste le même tant que vous ne le régénérez pas' : 'Valable encore environ $currentDays jour(s)', textAlign: TextAlign.center, style: l10St(11.5, c: l10Grey))),
      const SizedBox(height: 16),
      l10Btn('Copier le lien', () async {
        final ok = await copyText(url);
        if (mounted) gToast(context, ok ? 'Lien copié.' : 'Copie impossible : autorisez l’accès au presse-papiers.');
      }, width: w),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: l10Btn('WhatsApp', () => openUrl(context, 'https://wa.me/?text=${Uri.encodeComponent('Mon CV sur Boutik-École : $url')}'), dark: false, compact: true)),
        const SizedBox(width: 8),
        Expanded(child: l10Btn('Partager', () => shareText(context, 'Mon CV sur Boutik-École : $url'), dark: false, compact: true)),
      ]),
      const SizedBox(height: 8),
      l10Btn('Envoyer à une organisation', () async {
        final mail = await askText(context, title: 'Envoyer mon CV', body: 'Adresse e-mail du compte de l’organisation sur Boutik-École. Elle reçoit une notification avec votre lien.', hint: 'contact@organisation.cm', ok: 'Envoyer', min: 5);
        if (mail == null || !mounted) return;
        final r = await Backend.rpc('send_cv_to_recruiter', {'p_email': mail, 'p_message': ''});
        if (!mounted) return;
        if (r.error != null) return gAlert(context, 'Envoi impossible', r.error!);
        gToast(context, 'Demande enregistrée. Si cette adresse est celle d’un compte organisation, votre CV lui est envoyé.');
      }, dark: false, width: w, compact: true),
      const SizedBox(height: 8),
      l10Btn('Télécharger en PDF', () => uiSoon(context, 'Télécharger le CV en PDF', 'Partagez le lien de votre CV : il s’ouvre dans tout navigateur et peut être imprimé.'), dark: false, width: w, compact: true),
      const SizedBox(height: 20),
      Text('Ce que voient les recruteurs', style: l10St(15, w: FontWeight.w700)),
      Text('Toujours : nom, établissement, présentation, compétences. Jamais : téléphone ni e-mail.', style: l10St(11.5, c: l10Grey, h: 1.4)),
      _switch('Réalisations du portfolio', '', link['show_portfolio'] == true, (v) => _setting(link, 'p_show_portfolio', v)),
      _switch('Missions terminées', '', link['show_missions'] == true, (v) => _setting(link, 'p_show_missions', v)),
      _switch('Avis reçus', '', link['show_reviews'] == true, (v) => _setting(link, 'p_show_reviews', v)),
      _switch('Liens du profil', '', link['show_links'] == true, (v) => _setting(link, 'p_show_links', v)),
      const SizedBox(height: 8),
      Text('Validité du lien', style: l10St(12.5, w: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in const [0, 30, 90]) l10Btn(d == 0 ? 'Sans expiration' : '$d jours', () => _setting(link, 'p_expires_days', d), dark: d == 0 ? expires == null : false, compact: true),
      ]),
      const SizedBox(height: 22),
      l10Btn('Régénérer le lien', () async {
        if (!await _confirm('Régénérer le lien ?', 'Un nouveau lien et un nouveau QR code sont créés. L’ancien lien cesse immédiatement de fonctionner pour tous ceux à qui vous l’avez envoyé.', 'Régénérer')) return;
        if (await _call('regenerate_cv_link', {}, 'Lien non régénéré') && mounted) gToast(context, 'Nouveau lien créé : l’ancien ne fonctionne plus.');
      }, dark: false, width: w, compact: true),
      const SizedBox(height: 8),
      l10Btn('Désactiver le lien', () async {
        if (!await _confirm('Désactiver le lien ?', 'Plus personne ne pourra ouvrir votre CV avec ce lien. Vous pourrez en créer un nouveau plus tard.', 'Désactiver')) return;
        if (await _call('cv_link_disable', {}, 'Lien non désactivé') && mounted) gToast(context, 'Lien désactivé : votre CV n’est plus accessible.');
      }, dark: false, width: w, compact: true),
    ]);
  }
}

// ------------------------------------------------------------------ 229 : CV d'un talent (ou le mien)

class CvTalentScreen extends ConsumerWidget {
  const CvTalentScreen({super.key});

  Future<void> _contact(BuildContext context, WidgetRef ref, String user, String kind) async {
    if (!await requireLogin(context, ref, kind == 'internship_offer' ? 'proposer un stage' : 'contacter ce talent') || !context.mounted) return;
    final msg = await askText(context, title: kind == 'internship_offer' ? 'Proposer un stage' : 'Contacter ce talent', body: 'Ajoutez un message (facultatif, 500 caractères au plus). Le talent reçoit une notification.', hint: 'Bonjour, …', ok: 'Envoyer');
    if (msg == null || !context.mounted) return;
    final r = await Backend.rpc('talent_contact_request', {'p_user': user, 'p_kind': kind, 'p_message': msg});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Demande non envoyée', r.error!);
    gToast(context, kind == 'internship_offer' ? 'Proposition de stage envoyée : le talent a été prévenu.' : 'Demande de contact envoyée : le talent a été prévenu.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = l10Query(context, 'user');
    final signedOut = ref.watch(authProvider.select((a) => a.current == null));
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    final own = user.isEmpty || user == me;
    final cv = own ? ref.watch(cvPreviewProvider) : ref.watch(cvPublicProvider(user));
    return L10Screen(
      title: own ? 'Mon CV vivant' : 'CV du talent',
      child: signedOut
          ? l10Note(342, 'Connectez-vous pour consulter un CV.')
          : !own && !l10IsUuid(user)
              ? l10Note(342, 'Ce talent est introuvable.')
              : cv.when(
                  loading: () => l10Note(342, 'Chargement…'),
                  error: (_, _) => l10Note(342, 'Ce CV ne peut pas être chargé pour le moment.'),
                  data: (d) => d == null
                      ? l10Note(342, 'Ce talent n’a pas publié son CV.\nVous ne pouvez pas le contacter depuis cet écran.')
                      : ListView(padding: const EdgeInsets.only(bottom: 30), children: [
                          CvSections(cv: d),
                          const SizedBox(height: 20),
                          if (!own && const {'company', 'client', 'dept', 'admin'}.contains(roleKey(ref.watch(authProvider).current))) ...[
                            l10Btn('Proposer un stage', () => _contact(context, ref, user, 'internship_offer'), width: 342),
                            const SizedBox(height: 8),
                            l10Btn('Contacter', () => _contact(context, ref, user, 'contact'), dark: false, width: 342),
                            const SizedBox(height: 8),
                            Text('Réservé aux organisations, aux clients et au département. Dix demandes par jour au plus.', style: l10St(11, c: l10Grey)),
                          ] else if (!own)
                            Text('Les propositions de stage et les demandes de contact sont réservées aux organisations, aux clients et au département.', style: l10St(11, c: l10Grey))
                          else
                            l10Btn('Partager mon CV', () => gOpen(context, '228'), width: 342),
                        ]),
                ),
    );
  }
}
