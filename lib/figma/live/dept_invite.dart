import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gAlert, gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'dept_space.dart' show DeptCall, deptCallProvider, deptList;
import 'lots.dart' show copyText, formDialog;
import 'marche/marche_widgets.dart';
import 'marche/marche_data.dart' show kGrey, kInk, mst;
import 'share.dart' show siteUrl;
import 'tp_ui.dart' show tpPick;

/// Lien d'invitation d'un responsable de département : `…/#/invitation/<jeton>`.
String deptInviteLink(String token) => '$siteUrl/#/invitation/$token';

/// Administrateur : choisir un département (et, si souhaité, l'adresse e-mail réservée), créer le lien privé à usage unique, le copier.
Future<void> inviteDepartmentLeader(BuildContext context, WidgetRef ref) async {
  final deps = deptList(await ref.read(deptCallProvider(const DeptCall('admin_departments')).future));
  if (!context.mounted) return;
  String label(Map<String, dynamic> x) => '${x['name']} · ${x['institution']}';
  final choices = [for (final x in deps) if (x['id'] != null && '${x['status']}' != 'proposed') label(x)];
  if (choices.isEmpty) return gAlert(context, 'Aucun département vérifié', 'Vérifiez d’abord un département dans le référentiel : une invitation ne peut viser qu’un département vérifié.');
  final v = await tpPick(context, 'Département à confier', choices, allowCustom: false, current: '');
  if (v == null || !context.mounted) return;
  final hit = deps.where((x) => label(x) == v).firstOrNull;
  if (hit == null) return;
  final f = await formDialog(
    context,
    'Invitation : ${hit['name']}',
    [('Adresse e-mail réservée (facultatif)', ''), ('Fonction', 'Responsable'), ('Validité en jours (1 à 30)', '7')],
    submit: 'Créer le lien',
    intro: 'Le lien ne sert qu’une fois. Avec une adresse e-mail, seul ce compte pourra l’accepter.',
  );
  if (f == null || !context.mounted) return;
  final days = int.tryParse(f[2].trim()) ?? 7;
  final r = await Backend.rpc('dept_invite_create', {'p_department': hit['id'], 'p_email': f[0].trim().isEmpty ? null : f[0].trim(), 'p_title': f[1].trim().isEmpty ? 'Responsable' : f[1].trim(), 'p_days': days});
  if (!context.mounted) return;
  if (r.error != null || r.data is! Map) return gAlert(context, 'Invitation impossible', Backend.userMessage(r.error ?? 'Invitation impossible'));
  final link = deptInviteLink('${(r.data as Map)['token']}');
  final copied = await copyText(link);
  if (!context.mounted) return;
  await gAlert(context, 'Lien créé', '${copied ? 'Lien copié. ' : ''}Envoyez-le uniquement à la personne concernée. Il n’est affiché qu’une fois :\n\n$link');
}

/// Page ouverte par le lien : présente le département, demande de se connecter puis d'accepter.
class DeptInviteScreen extends ConsumerStatefulWidget {
  const DeptInviteScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<DeptInviteScreen> createState() => _DeptInviteScreenState();
}

class _DeptInviteScreenState extends ConsumerState<DeptInviteScreen> {
  Map<String, dynamic>? _info;
  bool _busy = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = Backend.ready ? await Backend.rpc('dept_invite_info', {'p_token': widget.token}) : null;
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _info = r != null && r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
    });
  }

  Future<void> _accept() async {
    if (!await requireLogin(context, ref, 'accepter cette invitation') || !mounted) return;
    setState(() => _busy = true);
    final r = await Backend.rpc('dept_invite_accept', {'p_token': widget.token});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gAlert(context, 'Invitation non acceptée', Backend.userMessage(r.error!));
    gToast(context, 'Vous gérez maintenant ce département.');
    context.go('/departement');
  }

  static const _reasons = {
    'used': 'Cette invitation a déjà été utilisée.',
    'expired': 'Cette invitation a expiré. Demandez-en une nouvelle à l’administrateur.',
    'revoked': 'Cette invitation a été annulée.',
    'unknown': 'Ce lien d’invitation n’existe pas. Vérifiez qu’il est complet.',
  };

  @override
  Widget build(BuildContext context) {
    final i = _info;
    final valid = i?['valid'] == true;
    return MarchePage(
      title: 'Invitation',
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
        if (!_loaded) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        if (_loaded && i == null) mNote(Backend.ready ? 'Cette invitation ne peut pas être lue pour le moment. Réessayez dans un instant.' : 'L’invitation nécessite la connexion au serveur.'),
        if (_loaded && i != null && !valid) mNote(_reasons['${i['state']}'] ?? _reasons['unknown']!),
        if (valid) ...[
          Text('Vous êtes invité(e) à gérer un département', style: mst(20, w: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('${i!['department']}', style: mst(18, w: FontWeight.w700)),
          if ('${i['institution'] ?? ''}'.isNotEmpty) Text('${i['institution']}', style: mst(14, c: kGrey)),
          const SizedBox(height: 6),
          Text('Fonction : ${i['title']}', style: mst(13, c: kInk)),
          if (i['email_hint'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Réservée à l’adresse ${i['email_hint']}', style: mst(12.5, c: kGrey))),
          const SizedBox(height: 16),
          Text('En acceptant, votre compte devient un compte Département, rattaché à ce seul département. Si vous n’avez pas de compte, créez-en un (compte Client) puis revenez sur ce lien.', style: mst(13, c: kGrey).copyWith(height: 1.45)),
          const SizedBox(height: 20),
          mButton(_busy ? 'Un instant…' : 'Accepter l’invitation', _busy ? () {} : _accept, width: double.infinity),
        ],
      ]),
    );
  }
}
