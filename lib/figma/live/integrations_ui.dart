import 'dart:math';

import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'integrations_data.dart';
import 'integrations_model.dart';
import 'integrations_momo.dart';
import 'integrations_widgets.dart';
import 'lots.dart' show addProfileLink, copyText, pendingLinksProvider, saveProfileLinks;

/// Les quatre écrans de la rubrique « Applications connectées » partagent le même hub (mêmes données, mêmes composants).
enum IntMode {
  /// P5 · Connecter mes outils : toutes les familles.
  hub('Connecter mes outils', 'Réseaux, productivité, collaboration, Mobile Money'),

  /// 271 · Mes liens et réseaux : réseaux affichés sur le profil + autres liens.
  links('Mes liens et réseaux', 'Icônes et liens affichés sur votre profil'),

  /// P3 · Avis et outils connectés : mes comptes reliés et leurs contenus.
  connected('Avis et outils connectés', 'Vos comptes reliés et les contenus importés'),

  /// 280 · Intégrations : état des connecteurs pour l'administration.
  admin('Intégrations', 'Connecteurs, approbations et accès à fournir');

  const IntMode(this.title, this.subtitle);
  final String title, subtitle;
}

void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

Future<void> _open(BuildContext context, String? url) async {
  if (url == null || !url.startsWith('https://')) return;
  final ok = await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  if (!ok && context.mounted) gToast(context, 'Impossible d’ouvrir le lien.');
}

// ---------------------------------------------------------------- hub

class IntegrationsHubScreen extends ConsumerStatefulWidget {
  const IntegrationsHubScreen({super.key, this.mode = IntMode.hub});
  final IntMode mode;

  @override
  ConsumerState<IntegrationsHubScreen> createState() => _HubState();
}

class _HubState extends ConsumerState<IntegrationsHubScreen> {
  final _search = TextEditingController();
  IntFamily? _family;
  bool _toastDone = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == IntMode.links) _family = IntFamily.reseaux;
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceReturn());
  }

  /// Retour du fournisseur : …/s/P5?connexion=ok&p=facebook ou connexion=erreur&m=message.
  void _announceReturn() {
    if (_toastDone || !mounted) return;
    _toastDone = true;
    try {
      final q = GoRouterState.of(context).uri.queryParameters;
      final c = q['connexion'];
      if (c == null) return;
      final p = providerById(q['p'] ?? '')?.name ?? 'Le fournisseur';
      if (c == 'ok') {
        gToast(context, '$p est connecté.');
        ref.read(integrationsProvider.notifier).refresh();
      } else {
        gAlert(context, 'Connexion non établie', '$p : ${q['m'] ?? 'autorisation refusée'}');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(integrationsProvider);
    final account = ref.watch(authProvider.select((a) => a.current));
    final mode = widget.mode;
    final list = filterProviders(_search.text, family: _family);
    final connectedProviders = {for (final c in st.connections) if (c.status != ConnStatus.revoked) c.provider};
    final shown = mode == IntMode.connected ? [for (final p in list) if (connectedProviders.contains(p.id)) p] : list;

    return IntPage(
      title: mode.title,
      subtitle: mode.subtitle,
      onBack: () => gBack(context),
      children: [
        if (!Backend.ready)
          const _Notice('Hors connexion', 'Les connexions se font avec le serveur : le catalogue est affiché, mais aucun compte ne peut être relié pour le moment.')
        else if (account == null)
          _Notice('Connectez-vous', 'Un compte Boutik-École est nécessaire pour relier vos outils.', action: 'Se connecter', onAction: () => requireLogin(context, ref, 'relier vos outils')),
        if (mode != IntMode.admin) ..._shortcuts(st, account != null),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            textField: true,
            label: 'Rechercher un outil',
            child: IntField(controller: _search, label: 'Rechercher un outil ou un réseau', onChanged: (_) => setState(() {})),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            height: 52,
            child: Row(children: [
              _Chip('Tous', _family == null, () => setState(() => _family = null)),
              for (final f in IntFamily.values) _Chip(f.label, _family == f, () => setState(() => _family = f)),
            ]),
          ),
        ),
        if (mode == IntMode.links) ..._linksExtra(),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Text(
              mode == IntMode.connected && _search.text.isEmpty ? 'Aucun compte relié pour le moment. Ouvrez « Connecter mes outils » pour en ajouter.' : 'Aucun résultat pour cette recherche.',
              textAlign: TextAlign.center,
              style: intText(13, color: kMuted, height: 1.4),
            ),
          ),
        for (final f in IntFamily.values)
          if (shown.any((p) => p.family == f)) ...[
            IntSectionTitle(f.label, hint: f.hint),
            for (final p in shown.where((p) => p.family == f)) _ProviderCard(p, st, adminView: mode == IntMode.admin),
          ],
        if (mode == IntMode.admin) ...[
          const IntSectionTitle('API publique et clés', hint: 'Clés d’intégration et webhooks existants'),
          IntCard(
            onTap: () => context.push('/integrations/api'),
            semantics: 'Ouvrir l’API publique et les clés',
            child: Row(children: [
              const Icon(Icons.vpn_key_outlined, color: kInk),
              const SizedBox(width: 12),
              Expanded(child: Text('API publique, clés d’intégration, webhooks', style: intText(13.5, weight: FontWeight.w700))),
              const Icon(Icons.chevron_right_rounded, color: kMuted),
            ]),
          ),
        ],
      ],
    );
  }

  List<Widget> _shortcuts(IntegrationsState st, bool signedIn) => [
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _Shortcut(Icons.collections_bookmark_outlined, 'Mes contenus connectés', '${st.items.length} importé${st.items.length > 1 ? 's' : ''}', () => _push(context, const ConnectedContentScreen()))),
            const SizedBox(width: 10),
            Expanded(child: _Shortcut(Icons.campaign_outlined, 'Publier sur mes réseaux', 'Texte adapté à chaque plateforme', () => _push(context, const PublishScreen()))),
          ]),
        ),
        const SizedBox(height: 10),
        _Shortcut(Icons.account_balance_wallet_outlined, 'Mobile Money', st.numbers.isEmpty ? 'MTN MoMo · Orange Money' : '${st.numbers.length} numéro${st.numbers.length > 1 ? 's' : ''} · ${st.dashboard.pending} en cours', () => _push(context, const MomoHubScreen()), wide: true),
        const SizedBox(height: 14),
      ];

  List<Widget> _linksExtra() {
    final pending = ref.watch(pendingLinksProvider);
    return [
      const IntSectionTitle('Autres liens du profil', hint: 'Portfolio, site, Drive…'),
      IntCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final l in pending)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${l['label']} · ${l['url']}', style: intText(12.5, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
          IntButton('+ Ajouter un autre lien', filled: false, onTap: () => addProfileLink(context, ref)),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 8),
            IntButton('Enregistrer ${pending.length} lien${pending.length > 1 ? 's' : ''}', onTap: () => saveProfileLinks(context, ref)),
          ],
        ]),
      ),
    ];
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, this.on, this.onTap);
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: on ? kInk : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: on ? kInk : kLine)),
              child: Text(label, style: intText(13, weight: FontWeight.w600, color: on ? Colors.white : kInk)),
            ),
          ),
        ),
      );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut(this.icon, this.title, this.sub, this.onTap, {this.wide = false});
  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) => IntCard(
        margin: EdgeInsets.zero,
        onTap: onTap,
        semantics: title,
        child: wide
            ? Row(children: [
                Icon(icon, color: kAccent),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: intText(13.5, weight: FontWeight.w700)), Text(sub, style: intText(11.5, color: kMuted))])),
                const Icon(Icons.chevron_right_rounded, color: kMuted),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, color: kAccent),
                const SizedBox(height: 8),
                Text(title, style: intText(13, weight: FontWeight.w700), maxLines: 2),
                Text(sub, style: intText(11, color: kMuted), maxLines: 2),
              ]),
      );
}

class _Notice extends StatelessWidget {
  const _Notice(this.title, this.body, {this.action, this.onAction});
  final String title, body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => IntCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: intText(13.5, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(body, style: intText(12.5, color: kMuted, height: 1.4)),
          if (action != null) ...[const SizedBox(height: 10), IntButton(action!, onTap: onAction)],
        ]),
      );
}

// ---------------------------------------------------------------- carte fournisseur

({String label, Color color}) providerStatus(IntProvider p, IntegrationsState st) {
  if (p.linkOnly) {
    return st.activeOf(p.id) != null ? (label: 'Lien enregistré', color: kOk) : (label: 'Non connecté', color: kMuted);
  }
  if (p.isMobileMoney) {
    final n = st.numbers.where((n) => n.operator == (p.id == 'mtn_momo' ? 'MTN' : 'ORANGE')).length;
    return n > 0 ? (label: '$n numéro${n > 1 ? 's' : ''}', color: kOk) : (label: 'Aucun numéro', color: kMuted);
  }
  final c = st.activeOf(p.id);
  if (c != null) {
    return switch (c.status) {
      ConnStatus.connected => (label: 'Connecté', color: kOk),
      ConnStatus.expired => (label: 'À reconnecter', color: kWarn),
      ConnStatus.error => (label: 'Erreur', color: kBad),
      ConnStatus.revoked => (label: 'Déconnecté', color: kMuted),
    };
  }
  if (!st.isReady(p)) return (label: 'En attente de configuration', color: kWarn);
  return (label: 'Non connecté', color: kMuted);
}

class _ProviderCard extends ConsumerWidget {
  const _ProviderCard(this.p, this.st, {this.adminView = false});
  final IntProvider p;
  final IntegrationsState st;
  final bool adminView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = providerStatus(p, st);
    final conn = st.activeOf(p.id);
    return IntCard(
      semantics: '${p.name}, ${s.label}',
      onTap: () => p.isMobileMoney ? _push(context, const MomoHubScreen()) : showProviderSheet(context, p),
      child: Row(children: [
        IntLogo(p.id),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: intText(14.5, weight: FontWeight.w700)),
            Text(conn != null && conn.displayName.isNotEmpty ? conn.displayName : p.summary, style: intText(12, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            IntPill(s.label, color: s.color),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: kMuted),
      ]),
    );
  }
}

// ---------------------------------------------------------------- fiche d'un fournisseur

Future<void> showProviderSheet(BuildContext context, IntProvider p) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF8F5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => ProviderSheet(provider: p),
    );

class ProviderSheet extends ConsumerStatefulWidget {
  const ProviderSheet({super.key, required this.provider});
  final IntProvider provider;

  @override
  ConsumerState<ProviderSheet> createState() => _SheetState();
}

class _SheetState extends ConsumerState<ProviderSheet> {
  bool _busy = false;
  final _link = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() job, {String? ok}) async {
    setState(() => _busy = true);
    final err = await job();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      await gAlert(context, widget.provider.name, err);
    } else if (ok != null) {
      gToast(context, ok);
    }
  }

  Future<void> _connect() async {
    if (!await requireLogin(context, ref, 'relier ${widget.provider.name}') || !mounted) return;
    await _run(() => ref.read(integrationsProvider.notifier).connect(widget.provider.id));
  }

  Future<void> _disconnect(IntConnection c) async {
    final choice = await gDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Déconnecter ${widget.provider.name} ?', style: intText(17, weight: FontWeight.w700)),
        content: Text(
          'Les jetons sont supprimés de nos serveurs et l’accès est révoqué chez ${widget.provider.name} quand son API le permet. '
          'Les contenus déjà importés peuvent être conservés ou supprimés.',
          style: intText(13.5, color: kMuted, height: 1.45),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Annuler', style: intText(13, weight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: Text('Déconnecter', style: intText(13, weight: FontWeight.w700, color: kBad))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'purge'), child: Text('Déconnecter et supprimer les contenus', style: intText(13, weight: FontWeight.w700, color: kBad))),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    final (err, revoked) = await ref.read(integrationsProvider.notifier).disconnect(c.id, purge: choice == 'purge');
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) return gAlert(context, 'Déconnexion', err);
    if (!widget.provider.linkOnly && !revoked) {
      await gAlert(context, 'Déconnecté', 'Nos copies du jeton sont supprimées. ${widget.provider.name} n’a pas confirmé la révocation : vous pouvez aussi retirer Boutik-École dans les paramètres de sécurité de ${widget.provider.name}.');
    } else {
      gToast(context, '${widget.provider.name} est déconnecté.');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final st = ref.watch(integrationsProvider);
    final c = st.activeOf(p.id);
    final s = providerStatus(p, st);
    final ready = st.isReady(p);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(children: [
            IntLogo(p.id, size: 52),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(p.name, style: intText(20, weight: FontWeight.w800)), const SizedBox(height: 4), IntPill(s.label, color: s.color)])),
          ]),
          const SizedBox(height: 6),
          if (c != null) ...[
            const SizedBox(height: 8),
            Text(c.displayName, style: intText(14, weight: FontWeight.w600)),
            if (c.lastSync != null) Text('Dernière synchronisation : ${_when(c.lastSync!)}', style: intText(12, color: kMuted)),
            if (c.status == ConnStatus.expired) Padding(padding: const EdgeInsets.only(top: 6), child: Text(c.lastError ?? 'Autorisation expirée : reconnectez ce compte.', style: intText(12.5, color: kWarn, weight: FontWeight.w600))),
          ],
          IntSectionTitle(c != null && c.permissions.isNotEmpty ? 'Permissions accordées' : 'Permissions demandées'),
          IntCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (p.permissions.isEmpty) Text('Aucune permission : seule l’adresse publique est enregistrée.', style: intText(12.5, color: kMuted)),
              for (final line in p.permissions) _Bullet(Icons.check_circle_outline, line, kOk),
              if (c != null && c.permissions.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Portées techniques : ${c.permissions.map((e) => e.split('/').last).join(', ')}', style: intText(11, color: kMuted, height: 1.4)),
              ],
            ]),
          ),
          if (p.limit != null || p.alternative != null || p.review != null) ...[
            const IntSectionTitle('Limites de l’API officielle'),
            IntCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (p.limit != null) _Bullet(Icons.info_outline, p.limit!, kWarn),
                if (p.review != null) _Bullet(Icons.verified_user_outlined, 'Approbation : ${p.review}', kWarn),
                if (p.alternative != null) _Bullet(Icons.alt_route_rounded, 'Alternative : ${p.alternative}', kAccent),
              ]),
            ),
          ],
          if (ref.watch(authProvider.select((a) => a.current?.staff == 'Admin global'))) ...[
            const IntSectionTitle('À fournir par le propriétaire', hint: 'Rien n’est inventé : le connecteur s’active quand ces éléments existent'),
            IntCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final r in ownerRequirements(p)) _Bullet(Icons.assignment_outlined, r, kInk)])),
          ],
          if (p.linkOnly) ..._linkOnly(c) else ...[
            if (c != null && p.canPublish && c.accounts.isNotEmpty) ...[
              const IntSectionTitle('Comptes proposés dans « Publier »', hint: 'Cochés par défaut dans l’écran de publication'),
              for (final a in c.accounts)
                IntCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                  child: Row(children: [
                    Expanded(child: Text(a.name, style: intText(13, weight: FontWeight.w600), maxLines: 2)),
                    Semantics(
                      label: 'Proposer ${a.name} dans Publier',
                      child: Switch(value: a.publish, onChanged: _busy ? null : (v) => _run(() => ref.read(integrationsProvider.notifier).setPublishAccount(a.id, v))),
                    ),
                  ]),
                ),
            ] else if (c != null && c.accounts.isNotEmpty) ...[
              const IntSectionTitle('Comptes liés'),
              for (final a in c.accounts.take(8)) IntCard(margin: const EdgeInsets.only(bottom: 8), child: Text(a.name, style: intText(13, weight: FontWeight.w600))),
            ],
            const SizedBox(height: 14),
            if (c == null || c.status == ConnStatus.revoked) ...[
              IntButton('Connecter ${p.name}', busy: _busy, onTap: ready ? _connect : null),
              if (!ready)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    st.catalogKnown
                        ? 'En attente : l’application développeur de ${p.name} n’est pas encore enregistrée côté serveur. Dès que l’équipe l’aura configurée, le bouton s’activera.'
                        : 'Le serveur d’intégrations ne répond pas pour le moment (ou vous n’êtes pas connecté).',
                    style: intText(12.5, color: kWarn, height: 1.4),
                  ),
                ),
            ] else ...[
              if (c.status == ConnStatus.expired || c.status == ConnStatus.error) ...[IntButton('Reconnecter', busy: _busy, onTap: ready ? _connect : null), const SizedBox(height: 10)],
              if (p.canImport && c.status == ConnStatus.connected) ...[
                IntButton('Synchroniser maintenant', filled: false, busy: _busy, onTap: () async {
                  setState(() => _busy = true);
                  final (ok, msg) = await ref.read(integrationsProvider.notifier).sync(c.id);
                  if (!mounted) return;
                  setState(() => _busy = false);
                  ok ? gToast(context, msg) : gAlert(context, 'Synchronisation', msg);
                }),
                const SizedBox(height: 10),
              ],
              IntButton('Déconnecter', danger: true, filled: false, busy: _busy, onTap: () => _disconnect(c)),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _linkOnly(IntConnection? c) => [
        const IntSectionTitle('Adresse publique de votre portfolio'),
        if (c != null) IntCard(child: Row(children: [Expanded(child: Text(c.displayName, style: intText(13, weight: FontWeight.w600), maxLines: 2)), TextButton(onPressed: () => _open(context, c.profileUrl), child: const Text('Ouvrir'))])),
        IntField(controller: _link, label: 'https://www.behance.net/votre-nom', keyboard: TextInputType.url),
        IntButton(c == null ? 'Enregistrer le lien' : 'Remplacer le lien', busy: _busy, onTap: () async {
          if (!await requireLogin(context, ref, 'enregistrer ce lien') || !mounted) return;
          final url = _link.text.trim();
          if (!RegExp(r'^https://\S{3,300}$').hasMatch(url)) return gAlert(context, 'Lien invalide', 'Une adresse commençant par https:// est attendue.');
          await _run(() => ref.read(integrationsProvider.notifier).saveLink(widget.provider.id, url), ok: 'Lien enregistré.');
        }),
        if (c != null) ...[const SizedBox(height: 10), IntButton('Retirer ce lien', danger: true, filled: false, busy: _busy, onTap: () => _disconnect(c))],
      ];
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.text, this.color);
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: intText(12.5, color: const Color(0xFF3D3B45), height: 1.4))),
        ]),
      );
}

String _when(DateTime d) {
  final n = DateTime.now();
  final diff = n.difference(d);
  if (diff.inMinutes < 1) return 'à l’instant';
  if (diff.inHours < 1) return 'il y a ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'il y a ${diff.inHours} h';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ---------------------------------------------------------------- Mes contenus connectés

class ConnectedContentScreen extends ConsumerStatefulWidget {
  const ConnectedContentScreen({super.key});

  @override
  ConsumerState<ConnectedContentScreen> createState() => _ContentState();
}

class _ContentState extends ConsumerState<ConnectedContentScreen> {
  String? _provider;
  bool _busy = false;

  Future<void> _syncAll() async {
    final st = ref.read(integrationsProvider);
    final targets = [for (final c in st.connections) if (c.active && (providerById(c.provider)?.canImport ?? false)) c];
    if (targets.isEmpty) return gAlert(context, 'Actualiser', 'Aucun compte relié ne permet l’import.');
    setState(() => _busy = true);
    final lines = <String>[];
    for (final c in targets) {
      final (_, msg) = await ref.read(integrationsProvider.notifier).sync(c.id);
      lines.add('${providerById(c.provider)?.name ?? c.provider} : $msg');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await gAlert(context, 'Synchronisation terminée', lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(integrationsProvider);
    final providers = {for (final i in st.items) i.provider};
    final items = [for (final i in st.items) if (_provider == null || i.provider == _provider) i];
    return IntPage(
      title: 'Mes contenus connectés',
      subtitle: 'Publications, vidéos, dépôts et fichiers importés',
      bottom: IntButton('Actualiser depuis mes comptes', busy: _busy, onTap: _syncAll),
      children: [
        if (providers.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 52,
              child: Row(children: [
                _Chip('Tous', _provider == null, () => setState(() => _provider = null)),
                for (final id in providers) _Chip(providerById(id)?.name ?? id, _provider == id, () => setState(() => _provider = id)),
              ]),
            ),
          ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          IntCard(
            child: Text(
              'Rien n’est importé pour le moment. Reliez un compte (Réseaux, GitHub, Drive…) puis touchez « Actualiser ». '
              'Seuls les contenus que le fournisseur autorise sont lus, et chaque contenu reste privé tant que vous ne le rendez pas visible.',
              style: intText(12.5, color: kMuted, height: 1.45),
            ),
          ),
        for (final i in items) _ItemCard(i),
      ],
    );
  }
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard(this.item);
  final IntItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(integrationsProvider.notifier);
    return IntCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IntLogo(item.provider, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title.isEmpty ? kindLabel(item.kind) : item.title, style: intText(13.5, weight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
              Text('${kindLabel(item.kind)} · ${providerById(item.provider)?.name ?? item.provider}${item.publishedAt == null ? '' : ' · ${_when(item.publishedAt!)}'}', style: intText(11.5, color: kMuted)),
            ]),
          ),
        ]),
        if (item.body != null && item.body!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(item.body!, maxLines: 3, overflow: TextOverflow.ellipsis, style: intText(12.5, color: const Color(0xFF3D3B45), height: 1.4))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          IntPill(visibilityLabel(item.visibility), color: item.visibility == 'private' ? kMuted : kOk),
          PopupMenuButton<String>(
            tooltip: 'Changer la visibilité',
            onSelected: (v) async {
              final err = await notifier.setVisibility(item.id, v);
              if (context.mounted) err == null ? gToast(context, 'Visibilité : ${visibilityLabel(v)}.') : gAlert(context, 'Visibilité', err);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'private', child: Text('Privé — visible par moi seul')),
              PopupMenuItem(value: 'portfolio', child: Text('Portfolio — dans mon portfolio')),
              PopupMenuItem(value: 'public', child: Text('Public — visible par tous')),
            ],
            child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48), child: Center(child: Text('Visibilité', style: intText(12.5, weight: FontWeight.w700, color: kAccent)))),
          ),
          if (item.url != null) TextButton(onPressed: () => _open(context, item.url), child: Text('Ouvrir', style: intText(12.5, weight: FontWeight.w700, color: kAccent))),
          TextButton(
            onPressed: () async {
              final err = await notifier.deleteItem(item.id);
              if (context.mounted && err != null) gAlert(context, 'Suppression', err);
            },
            child: Text('Supprimer', style: intText(12.5, weight: FontWeight.w700, color: kBad)),
          ),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- Publier sur mes réseaux

class _Target {
  _Target(this.conn, this.account, this.provider);
  final IntConnection conn;
  final IntAccount? account;
  final IntProvider provider;
  String get key => '${conn.id}|${account?.id ?? ''}';
  String get label => account != null && account!.name.isNotEmpty ? account!.name : provider.name;
}

String newIdempotencyKey() => '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${Random().nextInt(1 << 32).toRadixString(36)}';

class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key});

  @override
  ConsumerState<PublishScreen> createState() => _PublishState();
}

class _PublishState extends ConsumerState<PublishScreen> {
  final _text = TextEditingController();
  final _link = TextEditingController();
  final _media = TextEditingController();
  final _selected = <String>{};
  bool _init = false, _busy = false;
  String _key = newIdempotencyKey();
  List<PublishResult> _results = const [];

  @override
  void dispose() {
    _text.dispose();
    _link.dispose();
    _media.dispose();
    super.dispose();
  }

  List<_Target> _targets(IntegrationsState st) {
    final out = <_Target>[];
    for (final c in st.connections) {
      final p = providerById(c.provider);
      if (p == null || !p.canPublish || !c.active) continue;
      if (c.accounts.isEmpty) {
        out.add(_Target(c, null, p));
      } else {
        for (final a in c.accounts) {
          out.add(_Target(c, a, p));
        }
      }
    }
    return out;
  }

  Future<void> _publish(List<_Target> chosen) async {
    final confirm = await gDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Publier sur ${chosen.length} destination${chosen.length > 1 ? 's' : ''} ?', style: intText(17, weight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Le texte sera publié publiquement, en votre nom :', style: intText(13, color: kMuted)),
          const SizedBox(height: 8),
          for (final t in chosen) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• ${t.provider.name} — ${t.label}', style: intText(13, weight: FontWeight.w600))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: intText(13, weight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Publier', style: intText(13, weight: FontWeight.w700, color: kAccent))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(integrationsProvider.notifier).publish(
          content: _text.text.trim(),
          link: _link.text.trim(),
          media: _media.text.trim(),
          idempotencyKey: _key,
          targets: [for (final t in chosen) (connectionId: t.conn.id, accountId: t.account?.id)],
        );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r.error == null) _results = r.results;
    });
    if (r.error != null) return gAlert(context, 'Publication', r.error!);
    // Une nouvelle clé n'est créée que si tout est parti : un nouvel appui après un échec ne renvoie pas les cibles déjà publiées.
    if (r.results.isNotEmpty && r.results.every((x) => x.sent)) {
      _key = newIdempotencyKey();
      gToast(context, 'Publié sur ${r.results.length} destination${r.results.length > 1 ? 's' : ''}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(integrationsProvider);
    final targets = _targets(st);
    if (!_init && targets.isNotEmpty) {
      _init = true;
      _selected.addAll([for (final t in targets) if (t.account?.publish ?? true) t.key]);
    }
    final chosen = [for (final t in targets) if (_selected.contains(t.key)) t];
    final text = _text.text.trim();
    final needsMedia = chosen.any((t) => t.provider.id == 'instagram') && _media.text.trim().isEmpty;
    return IntPage(
      title: 'Publier sur mes réseaux',
      subtitle: 'Un texte, adapté à chaque plateforme choisie',
      bottom: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        IntButton(chosen.isEmpty ? 'Choisissez une destination' : 'Publier sur ${chosen.length} destination${chosen.length > 1 ? 's' : ''}', busy: _busy, onTap: text.isEmpty || chosen.isEmpty || needsMedia ? null : () => _publish(chosen)),
      ]),
      children: [
        IntField(controller: _text, label: 'Votre publication', hint: 'Annoncez un produit, un projet, un événement…', maxLines: 6, maxLength: 5000, onChanged: (_) => setState(() {})),
        IntField(controller: _link, label: 'Lien à joindre (facultatif)', hint: 'https://boutik-ecole.vercel.app/…', keyboard: TextInputType.url, onChanged: (_) => setState(() {})),
        IntField(controller: _media, label: 'Image ou vidéo (adresse https, facultatif)', keyboard: TextInputType.url, onChanged: (_) => setState(() {})),
        const IntSectionTitle('Destinations', hint: 'Comptes reliés qui permettent la publication'),
        if (targets.isEmpty)
          IntCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Aucune destination disponible. Reliez Facebook (Page), Instagram (professionnel), LinkedIn, Slack, Discord, Notion, Teams ou Google Docs/Sheets depuis « Connecter mes outils ».', style: intText(12.5, color: kMuted, height: 1.45)),
              const SizedBox(height: 10),
              IntButton('Copier le texte', filled: false, onTap: text.isEmpty ? null : () async {
                final ok = await copyText(text);
                if (context.mounted) gToast(context, ok ? 'Texte copié' : 'Copie impossible');
              }),
            ]),
          ),
        for (final t in targets) _targetTile(t, text),
        if (needsMedia) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Instagram exige une image ou une vidéo : ajoutez une adresse de média ou décochez Instagram.', style: intText(12.5, color: kWarn, weight: FontWeight.w600))),
        if (_results.isNotEmpty) ...[
          const IntSectionTitle('Résultat'),
          for (final r in _results)
            IntCard(
              child: Row(children: [
                IntLogo(r.provider, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(providerById(r.provider)?.name ?? r.provider, style: intText(13.5, weight: FontWeight.w700)),
                    IntPill(publishStatusLabel(r.status), color: r.sent ? kOk : kBad),
                    if (r.error != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.error!, style: intText(12, color: kBad, height: 1.35))),
                  ]),
                ),
                if (r.url != null) TextButton(onPressed: () => _open(context, r.url), child: Text('Voir', style: intText(13, weight: FontWeight.w700, color: kAccent))),
              ]),
            ),
        ],
      ],
    );
  }

  Widget _targetTile(_Target t, String text) {
    final on = _selected.contains(t.key);
    final ad = adaptForPlatform(t.provider.id, text, link: _link.text);
    final max = kTextLimits[t.provider.id] ?? 3000;
    return IntCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => setState(() => on ? _selected.remove(t.key) : _selected.add(t.key)),
      semantics: '${t.provider.name} ${t.label}, ${on ? 'sélectionné' : 'non sélectionné'}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IntLogo(t.provider.id, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.provider.name, style: intText(13.5, weight: FontWeight.w700)), Text(t.label, style: intText(12, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis)])),
          ExcludeSemantics(child: Checkbox(value: on, onChanged: (v) => setState(() => v == true ? _selected.add(t.key) : _selected.remove(t.key)))),
        ]),
        if (on && text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF7F5F2), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad.text, maxLines: 6, overflow: TextOverflow.ellipsis, style: intText(12.5, height: 1.4)),
              const SizedBox(height: 4),
              Text('${ad.text.length} / $max caractères${ad.link != null ? ' · lien joint en aperçu' : ''}', style: intText(11, color: kMuted)),
              if (ad.note != null) Text(ad.note!, style: intText(11, color: kWarn)),
            ]),
          ),
        ],
      ]),
    );
  }
}
