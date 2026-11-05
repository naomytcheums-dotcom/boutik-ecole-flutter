import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'console.dart';
import 'entreprise.dart';
import 'impact.dart' show RpcMap;

/// Modules ajoutés par la migration 20261105001000 : réglages de la plateforme, contenus éditoriaux, duels de talents, lives et casiers de
/// retrait, radar des compétences, code de parrainage. Chargement, état vide et erreur explicites ; rien n'est inventé.

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) => TextStyle(fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c);

Widget _note(double w, String t, {double h = 140}) => Container(width: w, height: h, alignment: Alignment.center, padding: const EdgeInsets.symmetric(horizontal: 24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))), child: Text(t, textAlign: TextAlign.center, style: _st(13, c: _grey).copyWith(height: 1.5)));
bool _signedOut(WidgetRef ref) => ref.watch(authProvider.select((a) => a.current == null));
Widget _btn(String t, VoidCallback f, {bool dark = true, double? w}) => GestureDetector(onTap: f, child: Container(width: w, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), alignment: Alignment.center, decoration: BoxDecoration(color: dark ? _ink : Colors.white, borderRadius: BorderRadius.circular(18), border: dark ? null : Border.all(color: const Color(0xFFE6E1EE))), child: Text(t, style: _st(12.5, w: FontWeight.w700, c: dark ? Colors.white : _ink))));

Future<bool> _run(BuildContext context, String fn, Map<String, dynamic> args, String ok) async {
  final r = await Backend.rpc(fn, args);
  if (!context.mounted) return false;
  if (r.error != null) {
    gToast(context, '${r.error}');
    return false;
  }
  gToast(context, ok);
  return true;
}

// ------------------------------------------------------------------ réglages de la plateforme

final settingsProvider = NotifierProvider<RpcMap, Map<String, dynamic>?>(() => RpcMap('settings_all', needsLogin: true));

class SettingDef {
  const SettingDef(this.key, this.label, this.sub);
  final String key, label, sub;
}

class SettingsToggles extends ConsumerWidget {
  const SettingsToggles({super.key, required this.defs, this.width = 984});
  final List<SettingDef> defs;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_signedOut(ref)) return _note(width, 'Connectez-vous avec un compte de gestion pour voir ces réglages.');
    final s = ref.watch(settingsProvider);
    if (s == null) return _note(width, 'Chargement…');
    if (ref.read(settingsProvider.notifier).error) return _note(width, 'Accès réservé à la gestion, ou réglages indisponibles pour le moment.');
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final d in defs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d.label, style: _st(14, w: FontWeight.w700)), const SizedBox(height: 2), Text(d.sub, style: _st(12, c: _grey))])),
              Switch(
                value: s[d.key] == true,
                onChanged: (v) async {
                  final ok = await _run(context, 'setting_set', {'p_key': d.key, 'p_value': v}, 'Réglage enregistré.');
                  if (ok) await ref.read(settingsProvider.notifier).refresh();
                },
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Text('Les réglages sont enregistrés et journalisés ; seul un administrateur peut les modifier.', style: _st(11.5, c: _grey)),
      ]),
    );
  }
}

const settings136 = [SettingDef('security.2fa_required', 'Double authentification obligatoire', 'Pour les rôles sensibles'), SettingDef('security.ip_restriction', 'Restriction par adresse IP', 'Espaces administrateurs'), SettingDef('security.lock_on_failures', 'Blocage temporaire de connexion', 'Après plusieurs échecs')];
const settings138 = [SettingDef('modules.crowdfunding', 'Financement participatif', 'Module de campagnes'), SettingDef('modules.messaging', 'Messagerie interne', 'Conversations entre comptes'), SettingDef('modules.b2b', 'Espace B2B', 'Besoins et devis des entreprises'), SettingDef('modules.mobile_money', 'Paiement Mobile Money', 'Déclaration de paiement')];
const settings144 = [SettingDef('payments.orange_money', 'Orange Money', 'Paiement marchand'), SettingDef('payments.mtn_momo', 'MTN Mobile Money', 'Paiement marchand'), SettingDef('payments.cash_kiosk', 'Espèces au kiosque', 'Pour les retraits sur place')];
const settings280 = [SettingDef('integrations.api_public', 'API publique', 'Lecture du catalogue'), SettingDef('integrations.webhooks', 'Webhooks', 'Notifications vers des services externes'), SettingDef('integrations.sms', 'Envoi de SMS', 'Alertes par SMS')];
const settings122 = [SettingDef('validation.listings_required', 'Validation des annonces', 'Contrôle avant publication'), SettingDef('validation.double_over_limit', 'Double validation des gros montants', 'Département puis institution')];

// ------------------------------------------------------------------ contenus éditoriaux

final cmsItemsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('cms_items', 'id,kind,title,body,active,updated_at', order: 'updated_at'));

class CmsPanel extends ConsumerWidget {
  const CmsPanel({super.key, required this.kinds, this.width = 984, this.height = 600});
  final List<String> kinds;
  final double width, height;

  static const labels = {'page': 'Page', 'banner': 'Bannière', 'faq': 'Question', 'template': 'Modèle'};

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_signedOut(ref)) return _note(width, 'Connectez-vous avec un compte de gestion pour voir ces contenus.');
    final all = ref.watch(cmsItemsProvider);
    if (all == null) return _note(width, 'Chargement…');
    final rows = [for (final r in all) if (kinds.contains('${r['kind']}')) r];
    return SizedBox(
      width: width,
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${rows.length} contenu${rows.length > 1 ? 's' : ''}', style: _st(15, w: FontWeight.w700))),
          _btn('Ajouter', () => cmsDialog(context, ref, kinds.first)),
        ]),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Expanded(child: _note(width, 'Aucun contenu pour le moment.\nUtilisez « Ajouter » pour en créer un (réservé aux administrateurs).'))
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 18, color: Color(0xFFF2EFF6)),
              itemBuilder: (_, i) {
                final r = rows[i];
                return Row(children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => cmsDialog(context, ref, '${r['kind']}', existing: r),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['title']}', style: _st(13.5, w: FontWeight.w700)), const SizedBox(height: 2), Text('${labels['${r['kind']}']} · ${r['active'] == true ? 'actif' : 'masqué'} · ${dateCourte(r['updated_at'])}', style: _st(11.5, c: _grey))]),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      if (await _run(context, 'cms_delete', {'p_id': '${r['id']}'}, 'Contenu supprimé.')) await ref.read(cmsItemsProvider.notifier).refresh();
                    },
                  ),
                ]);
              },
            ),
          ),
      ]),
    );
  }
}

Future<void> cmsDialog(BuildContext context, WidgetRef ref, String kind, {Map<String, dynamic>? existing}) async {
  final title = TextEditingController(text: '${existing?['title'] ?? ''}'), body = TextEditingController(text: '${existing?['body'] ?? ''}');
  var active = existing?['active'] != false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(existing == null ? 'Nouveau contenu' : 'Modifier le contenu'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Titre')),
          TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Texte')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Actif'), value: active, onChanged: (v) => set(() => active = v)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Enregistrer'))],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  if (await _run(context, 'cms_save', {'p_id': existing?['id'], 'p_kind': kind, 'p_title': title.text, 'p_body': body.text, 'p_active': active}, 'Contenu enregistré.')) {
    await ref.read(cmsItemsProvider.notifier).refresh();
  }
}

// ------------------------------------------------------------------ journal d'audit

final auditRowsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('audit_log', 'actor,action,target,category,level,created_at', order: 'created_at'));

Widget auditListing({double width = 984, double height = 640}) => MobileList(
      provider: auditRowsProvider,
      title: (r) => '${r['action']}',
      subtitle: (r) => '${r['target'] ?? ''} · ${r['category'] ?? ''} · ${dateCourte(r['created_at'])}',
      trailing: (r) => '${r['level']}',
      emptyText: 'Aucune entrée dans le journal pour le moment.\nLa lecture est réservée à l’administration.',
      width: width,
      height: height,
    );

// ------------------------------------------------------------------ radar des compétences

final radarProvider = NotifierProvider<RpcMap, Map<String, dynamic>?>(() => RpcMap('skills_radar', needsLogin: true));

class RadarPanel extends ConsumerWidget {
  const RadarPanel({super.key, this.width = 984});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_signedOut(ref)) return _note(width, 'Connectez-vous avec un compte de gestion pour voir le radar.');
    final d = ref.watch(radarProvider);
    if (d == null) return _note(width, 'Chargement…');
    if (ref.read(radarProvider.notifier).error) return _note(width, 'Accès réservé à la gestion, ou radar indisponible pour le moment.');
    final skills = [for (final x in (d['skills'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
    final maxC = skills.fold<int>(1, (a, s) => ((s['count'] as num).toInt()) > a ? (s['count'] as num).toInt() : a);
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${d['students']} étudiants · ${d['open_needs']} besoin${(d['open_needs'] as num?) == 1 ? '' : 's'} ouvert${(d['open_needs'] as num?) == 1 ? '' : 's'}', style: _st(14, w: FontWeight.w700)),
        const SizedBox(height: 14),
        Text('Compétences déclarées', style: _st(15, w: FontWeight.w700)),
        const SizedBox(height: 10),
        if (skills.isEmpty)
          Text('Aucune compétence déclarée pour le moment.', style: _st(13, c: _grey))
        else
          for (final s in skills)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 180, child: Text('${s['skill']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12.5))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 8, value: (s['count'] as num) / maxC, backgroundColor: const Color(0xFFF2EFF6), color: const Color(0xFF5A3FE0)))),
                SizedBox(width: 36, child: Text('${s['count']}', textAlign: TextAlign.right, style: _st(12, c: _grey))),
              ]),
            ),
      ]),
    );
  }
}

// ------------------------------------------------------------------ parrainage

final referralProvider = NotifierProvider<RpcText, String?>(RpcText.new);

class RpcText extends Notifier<String?> {
  @override
  String? build() {
    if (!Backend.ready || ref.watch(authProvider.select((a) => a.current == null))) return null;
    Future.microtask(() async {
      final r = await Backend.rpc('my_referral_code', const {});
      if (ref.mounted) state = r.error == null && r.data is String ? r.data as String : '';
    });
    return null;
  }
}

class ReferralKit extends ConsumerWidget {
  const ReferralKit({super.key, this.width = 342});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_signedOut(ref)) return _note(width, 'Connectez-vous pour obtenir votre code.');
    final c = ref.watch(referralProvider);
    if (c == null) return _note(width, 'Chargement…');
    if (c.isEmpty) return _note(width, 'Code indisponible pour le moment.');
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Votre code de parrainage', style: _st(15, w: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(width: width, padding: const EdgeInsets.all(18), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(20)), child: SelectableText(c, style: _st(26, w: FontWeight.w800, c: const Color(0xFF5A3FE0)))),
        const SizedBox(height: 14),
        Text('Message à partager :\n« Rejoins Boutik-École avec mon code $c : https://boutik-ecole.vercel.app »', style: _st(13).copyWith(height: 1.5)),
        const SizedBox(height: 12),
        Text('Le suivi des parrainages et des gains n’est pas encore disponible.', style: _st(12, c: _grey)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ duels de talents

final duelsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('duels_list'));

class _DuelsBase extends ConsumerWidget {
  const _DuelsBase({super.key, required this.open, required this.width, required this.height});
  final bool open;
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(duelsProvider);
    if (!Backend.ready || all == null) return _note(width, _signedOut(ref) ? 'Connectez-vous pour voir les duels.' : 'Chargement…');
    final rows = [for (final d in all) if ((d['open'] == true) == open) d];
    if (rows.isEmpty) return _note(width, open ? 'Aucun duel en cours.' : 'Aucun duel terminé pour le moment.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, i) {
          final d = rows[i];
          final entries = [for (final e in (d['entries'] as List? ?? const [])) Map<String, dynamic>.from(e as Map)];
          final best = entries.isEmpty ? null : entries.reduce((a, b) => (b['votes'] as num) > (a['votes'] as num) ? b : a);
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d['need']}', style: _st(15, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text([if ('${d['prize']}'.isNotEmpty) 'Prix : ${d['prize']}', if (open) 'fin le ${dateCourte(d['ends_at'])}' else 'terminé le ${dateCourte(d['ends_at'])}'].join(' · '), style: _st(11.5, c: _grey)),
              const SizedBox(height: 10),
              if (entries.isEmpty) Text('Aucune participation pour le moment.', style: _st(12.5, c: _grey)),
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text('${e['author']} · ${e['title']}${!open && best != null && e['id'] == best['id'] && (e['votes'] as num) > 0 ? '  🏆' : ''}', style: _st(13, w: FontWeight.w600))),
                    Text('${e['votes']} vote${(e['votes'] as num) == 1 ? '' : 's'}', style: _st(11.5, c: _grey)),
                    if (open) ...[const SizedBox(width: 8), _btn('Voter', () async { if (await _run(context, 'duel_vote', {'p_entry': '${e['id']}'}, 'Vote enregistré.')) await ref.read(duelsProvider.notifier).refresh(); })],
                  ]),
                ),
              if (open) Padding(padding: const EdgeInsets.only(top: 8), child: _btn('Participer', () => enterDuelDialog(context, ref, '${d['id']}'), dark: false)),
            ]),
          );
        },
      ),
    );
  }
}

class DuelsOpenPanel extends _DuelsBase {
  const DuelsOpenPanel({super.key, double width = 342, double height = 600}) : super(open: true, width: width, height: height);
}

class DuelResultsPanel extends _DuelsBase {
  const DuelResultsPanel({super.key, double width = 342, double height = 600}) : super(open: false, width: width, height: height);
}

Future<void> enterDuelDialog(BuildContext context, WidgetRef ref, String duel) async {
  final t = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Ma proposition'), content: TextField(controller: t, decoration: const InputDecoration(labelText: 'Titre de ma proposition')), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer'))]));
  if (ok != true || !context.mounted) return;
  if (await _run(context, 'duel_enter', {'p_duel': duel, 'p_title': t.text}, 'Participation enregistrée.')) await ref.read(duelsProvider.notifier).refresh();
}

class DuelCreateForm extends ConsumerStatefulWidget {
  const DuelCreateForm({super.key, this.width = 342});
  final double width;
  @override
  ConsumerState<DuelCreateForm> createState() => _DuelCreateFormState();
}

class _DuelCreateFormState extends ConsumerState<DuelCreateForm> {
  final _need = TextEditingController(), _prize = TextEditingController(), _hours = TextEditingController(text: '48');

  @override
  Widget build(BuildContext context) {
    if (_signedOut(ref)) return _note(widget.width, 'Connectez-vous avec un compte client ou entreprise pour lancer un duel.');
    return SizedBox(
      width: widget.width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _need, decoration: const InputDecoration(labelText: 'Besoin (ex. logo pour ma marque)')),
        TextField(controller: _prize, decoration: const InputDecoration(labelText: 'Prix (facultatif)')),
        TextField(controller: _hours, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée en heures (1 à 336)')),
        const SizedBox(height: 18),
        _btn('Lancer le duel', () async {
          final h = int.tryParse(_hours.text.trim()) ?? 0;
          if (await _run(context, 'duel_create', {'p_need': _need.text, 'p_prize': _prize.text, 'p_hours': h}, 'Duel lancé.')) {
            _need.clear();
            _prize.clear();
            await ref.read(duelsProvider.notifier).refresh();
          }
        }, w: widget.width),
      ]),
    );
  }
}

// ------------------------------------------------------------------ lives

final livesAllProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('scheduled_lives', 'id,host_id,title,starts_at,product_title,status', order: 'created_at'));
final liveCommentsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('live_comments', 'live_id,body,created_at', order: 'created_at'));

/// Lives en cours avec leurs commentaires (écran 222) ou lives du compte à démarrer (écran l1).
class LiveRoom extends ConsumerWidget {
  const LiveRoom({super.key, this.mine = false, this.width = 342, this.height = 600});
  final bool mine;
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_signedOut(ref)) return _note(width, 'Connectez-vous pour voir les lives.');
    final all = ref.watch(livesAllProvider);
    final comments = ref.watch(liveCommentsProvider) ?? const <Map<String, dynamic>>[];
    if (all == null) return _note(width, 'Chargement…');
    final uid = Backend.userId;
    final rows = [for (final l in all) if (mine ? ('${l['host_id']}' == uid && ('${l['status']}' == 'scheduled' || '${l['status']}' == 'live')) : '${l['status']}' == 'live') l];
    if (rows.isEmpty) return _note(width, mine ? 'Aucun live programmé à démarrer.\nProgrammez-en un depuis votre profil.' : 'Aucun live en cours pour le moment.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, i) {
          final l = rows[i];
          final live = '${l['status']}' == 'live';
          final mineComments = [for (final c in comments) if ('${c['live_id']}' == '${l['id']}') c];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFECE8F2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${l['title']}', style: _st(15, w: FontWeight.w700))), if (live) Text('EN DIRECT', style: _st(11, w: FontWeight.w800, c: const Color(0xFFE5484D)))]),
              if ('${l['product_title'] ?? ''}'.isNotEmpty) Text('Produit : ${l['product_title']}', style: _st(12, c: _grey)),
              const SizedBox(height: 10),
              if (mine)
                Row(children: [
                  if (!live) _btn('Démarrer', () async { if (await _run(context, 'live_set_state', {'p_id': '${l['id']}', 'p_state': 'live'}, 'Live démarré.')) await ref.read(livesAllProvider.notifier).refresh(); }),
                  if (live) _btn('Terminer', () async { if (await _run(context, 'live_set_state', {'p_id': '${l['id']}', 'p_state': 'ended'}, 'Live terminé.')) await ref.read(livesAllProvider.notifier).refresh(); }),
                ])
              else ...[
                Text('Commentaires (${mineComments.length})', style: _st(12.5, w: FontWeight.w700)),
                const SizedBox(height: 6),
                if (mineComments.isEmpty) Text('Aucun commentaire pour le moment.', style: _st(12, c: _grey)),
                for (final c in mineComments.take(8)) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${c['body']}', style: _st(12.5))),
                const SizedBox(height: 8),
                _btn('Commenter', () => commentDialog(context, ref, '${l['id']}'), dark: false),
              ],
            ]),
          );
        },
      ),
    );
  }
}

Future<void> commentDialog(BuildContext context, WidgetRef ref, String live) async {
  final t = TextEditingController();
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Commenter'), content: TextField(controller: t, maxLength: 300, decoration: const InputDecoration(labelText: 'Votre message')), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Envoyer'))]));
  if (ok != true || !context.mounted) return;
  if (await _run(context, 'live_comment', {'p_live': live, 'p_body': t.text}, 'Commentaire publié.')) await ref.read(liveCommentsProvider.notifier).refresh();
}

// ------------------------------------------------------------------ retraits en borne (casiers)

final pickupsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => RpcRows('pickups_list', const {'p_limit': 100}));

class PickupsPanel extends ConsumerWidget {
  const PickupsPanel({super.key, this.width = 342, this.height = 600});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_signedOut(ref)) return _note(width, 'Connectez-vous avec un compte de gestion pour voir les retraits.');
    final rows = ref.watch(pickupsProvider);
    if (rows == null) return _note(width, 'Chargement…');
    if (ref.read(pickupsProvider.notifier).error) return _note(width, 'Accès réservé à la gestion, ou retraits indisponibles pour le moment.');
    if (rows.isEmpty) return _note(width, 'Aucune commande en casier pour le moment.');
    return SizedBox(
      width: width,
      height: height,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, _) => const Divider(height: 22, color: Color(0xFFF2EFF6)),
        itemBuilder: (_, i) {
          final p = rows[i];
          final ready = '${p['status']}' == 'ready';
          return Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('#${p['order']} · ${p['buyer']}', style: _st(13.5, w: FontWeight.w700)), const SizedBox(height: 2), Text('Casier ${p['locker']} · ${p['kiosk']} · ${dateCourte(p['ready_at'])}', style: _st(11.5, c: _grey))])),
            if (ready) _btn('Remettre', () async { if (await _run(context, 'pickup_collect', {'p_id': '${p['id']}'}, 'Remise enregistrée.')) await ref.read(pickupsProvider.notifier).refresh(); }) else Text('Remise', style: _st(11.5, w: FontWeight.w700, c: const Color(0xFF0F7A52))),
          ]);
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ dossiers de mission, jalons, journal de projet, candidatures

final threadsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('mission_messages', 'mission_id,body,created_at,missions(title)', order: 'created_at'));
final milestonesProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('mission_milestones', 'mission_id,position,title,amount,status,note,missions(title)', order: 'position', ascending: true));
final projectStepsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(() => TableRows('project_steps', 'title,happened_on,projects(title)', order: 'happened_on'));

class ApplicationsRows extends RpcRows {
  ApplicationsRows() : super('applications');
  @override
  Future<void> refresh() async {
    final rows = await Backend.myEngagements(kind: 'application');
    if (!ref.mounted) return;
    error = false;
    state = [for (final r in rows) Map<String, dynamic>.from(r)];
  }
}

final applicationsProvider = NotifierProvider<RpcRows, List<Map<String, dynamic>>?>(ApplicationsRows.new);

String milestoneStatus(Object? s) => switch ('$s') { 'submitted' => 'Livré', 'validated' => 'Validé', 'correction' => 'À corriger', _ => 'À venir' };

Widget threadsListing({double width = 342, double height = 600}) => MobileList(
      provider: threadsProvider,
      title: (r) => '${(r['missions'] as Map?)?['title'] ?? 'Mission'}',
      subtitle: (r) => '${r['body']} · ${dateCourte(r['created_at'])}',
      emptyText: 'Aucun message pour le moment.\nLe dossier de la mission s’ouvre une fois la mission attribuée.',
      width: width,
      height: height,
    );

Widget milestonesListing({double width = 342, double height = 600}) => MobileList(
      provider: milestonesProvider,
      title: (r) => 'Jalon ${r['position']} · ${r['title']}',
      subtitle: (r) => '${(r['missions'] as Map?)?['title'] ?? ''} · ${r['amount']} FCFA',
      trailing: (r) => milestoneStatus(r['status']),
      emptyText: 'Aucun jalon pour le moment.',
      width: width,
      height: height,
    );

Widget projectStepsListing({double width = 342, double height = 600}) => MobileList(
      provider: projectStepsProvider,
      title: (r) => '${r['title']}',
      subtitle: (r) => '${(r['projects'] as Map?)?['title'] ?? ''} · ${dateCourte(r['happened_on'])}',
      emptyText: 'Aucune étape enregistrée pour le moment.',
      width: width,
      height: height,
    );

Widget applicationsListing({double width = 342, double height = 600}) => MobileList(
      provider: applicationsProvider,
      title: (r) => '${r['ref'] ?? 'Candidature'}',
      subtitle: (r) => 'Envoyée le ${dateCourte(r['created_at'])}',
      trailing: (r) => '${r['status'] ?? ''}' == 'active' ? 'Envoyée' : '${r['status'] ?? ''}',
      emptyText: 'Aucune candidature pour le moment.',
      width: width,
      height: height,
    );
