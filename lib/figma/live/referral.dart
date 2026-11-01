import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'auth.dart';
import 'backend.dart';
import 'lots.dart' show copyText;
import 'store.dart' show fcfa;
import 'talents.dart' show askText;

/// Parrainage et gains (écrans 240, 243 ; migration 20261101000400, règles § 3). Les montants viennent du serveur ;
/// rien n'est « versé » : le retrait vers Mobile Money reste indisponible tant que les paiements ne sont pas activés.

typedef Referee = ({String name, String status, int earned});

class ReferralSummary {
  const ReferralSummary({this.tier = 'Aucun', this.active = 0, this.pending = 0, this.available = 0, this.waiting = 0, this.month = 0, this.referees = const []});
  final String tier;
  final int active, pending, available, waiting, month;
  final List<Referee> referees;

  int get total => available + waiting;

  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        tier: '${j['tier'] ?? 'Aucun'}',
        active: (j['active'] as num?)?.toInt() ?? 0,
        pending: (j['pending_referrals'] as num?)?.toInt() ?? 0,
        available: (j['available'] as num?)?.toInt() ?? 0,
        waiting: (j['waiting'] as num?)?.toInt() ?? 0,
        month: (j['this_month'] as num?)?.toInt() ?? 0,
        referees: [
          for (final r in (j['referees'] as List? ?? const []))
            (name: '${(r as Map)['name']}', status: '${r['status']}', earned: (r['earned'] as num?)?.toInt() ?? 0),
        ],
      );

  /// « Niveau Argent », « Plus que 13 filleuls pour passer Or ».
  String get tierLabel => tier == 'Aucun' ? 'Aucun filleul actif' : 'Niveau $tier';
  String get nextLabel => switch (tier) {
        'Or' => 'Niveau maximal atteint',
        'Argent' => 'Plus que ${20 - active} filleul${20 - active > 1 ? 's' : ''} pour passer Or',
        'Bronze' => 'Plus que ${5 - active} filleul${5 - active > 1 ? 's' : ''} pour passer Argent',
        _ => 'Un filleul actif pour passer Bronze',
      };
}

String refereeStatus(String s) => switch (s) { 'active' => 'Actif', 'expired' => 'Expiré', _ => 'En attente' };

/// Synthèse lue sur le serveur ; null tant qu'elle n'est pas lue (ou sans compte).
class ReferralNotifier extends Notifier<ReferralSummary?> {
  @override
  ReferralSummary? build() {
    if (!Backend.ready) return null;
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) Future.microtask(refresh);
    return null;
  }

  Future<void> refresh() async {
    final r = await Backend.rpc('my_referral_summary', const {});
    if (r.error == null && r.data is Map && ref.mounted) state = ReferralSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
  }
}

final referralProvider = NotifierProvider<ReferralNotifier, ReferralSummary?>(ReferralNotifier.new);

/// Code personnel (créé par le serveur à la première demande).
class ReferralCode extends Notifier<String> {
  @override
  String build() {
    if (!Backend.ready) return '';
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) {
      Future.microtask(() async {
        final r = await Backend.rpc('my_referral_code', const {});
        if (r.error == null && ref.mounted) state = '${r.data}';
      });
    }
    return '';
  }
}

final referralCodeProvider = NotifierProvider<ReferralCode, String>(ReferralCode.new);

/// Texte du lien d'invitation : le code à saisir à l'inscription (Mon compte → « J'ai un code de parrainage »).
String invitationText(String code) => code.isEmpty ? 'Connectez-vous pour obtenir votre code' : 'Code de parrainage : $code';

/// 240 « Copier » : copie réellement le message d'invitation ; le message dit si la copie a réussi.
Future<void> copyInvitation(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gToast(context, 'Lien copié');
  final code = ref.read(referralCodeProvider);
  if (code.isEmpty) return gAlert(context, 'Parrainage', 'Connectez-vous pour obtenir votre code de parrainage.');
  final ok = await copyText('Rejoins Boutik-École : ${Uri.base.origin} — à l’inscription, saisis mon code de parrainage $code.');
  if (context.mounted) gToast(context, ok ? 'Invitation copiée' : 'Copie impossible : autorisez l’accès au presse-papiers.');
}

/// Mon compte : le filleul saisit le code reçu (30 jours après l'inscription au plus ; vérifié par le serveur).
Future<void> claimReferralDialog(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'saisir un code de parrainage') || !context.mounted) return;
  final code = await askText(context, title: 'Code de parrainage', body: 'Saisissez le code reçu (8 caractères), dans les 30 jours suivant votre inscription.', hint: 'ABCD2345', ok: 'Valider', min: 8);
  if (code == null || !context.mounted) return;
  final r = await Backend.rpc('claim_referral', {'p_code': code});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Code refusé', r.error!);
  gToast(context, 'Parrain enregistré : la prime lui sera due à votre première commande payée.');
}

/// Liste des filleuls réels (243), à la place des exemples de la maquette.
Widget refereeList(ReferralSummary s) => s.referees.isEmpty
    ? Text('Aucun filleul pour le moment. Partagez votre code depuis « Parrainer et gagner ».',
        style: const TextStyle(fontSize: 12.5, color: Color(0xFF66636E), height: 1.4))
    : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final r in s.referees.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              Expanded(child: Text(r.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111015)))),
              Text(refereeStatus(r.status), style: const TextStyle(fontSize: 11, color: Color(0xFF5A3FE0))),
              const SizedBox(width: 16),
              Text(r.earned > 0 ? '+ ${fcfa(r.earned)}' : '—', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111015))),
            ]),
          ),
      ]);
