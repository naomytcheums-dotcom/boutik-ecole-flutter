import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_appels.dart' show marcheLoginRequired;
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';
import 'verification.dart' show StudentVerificationCard;

/// Capacité commerciale du compte connecté (fonction serveur `my_seller_capability`). Le vendeur n'est PAS un compte distinct : c'est ce que peut
/// faire un étudiant vérifié, dont le téléphone est vérifié et dont le compte n'est pas suspendu. Les autres comptes ne vendent pas.
class SellerCapability {
  const SellerCapability({required this.canSell, required this.canPublish, required this.role, required this.conditions, this.paused = false});

  final bool canSell, canPublish;

  /// Boutique mise en pause par son titulaire (`seller_pause`) : annonces masquées, aucune nouvelle commande ni publication ; les commandes en cours continuent.
  final bool paused;
  final String? role;

  /// Conditions dans l'ordre d'affichage : (clé, libellé, remplie).
  final List<({String key, String label, bool ok})> conditions;

  List<String> get missing => [for (final c in conditions) if (!c.ok) c.key];

  factory SellerCapability.fromJson(Map<String, dynamic> j) => SellerCapability(
        canSell: j['can_sell'] == true,
        canPublish: j['can_publish'] == true,
        role: j['role'] as String?,
        paused: j['paused'] == true,
        conditions: [
          for (final c in (j['conditions'] as List? ?? const []))
            if (c is Map) (key: '${c['key']}', label: '${c['label']}', ok: c['ok'] == true),
        ],
      );
}

/// `null` : hors connexion au serveur (aperçu, démonstration) ou personne de connecté ; une erreur de lecture n'ouvre jamais l'espace vendeur.
final sellerCapabilityProvider = FutureProvider.autoDispose<SellerCapability?>((ref) async {
  final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || uid.isEmpty) return null;
  final r = await Backend.rpc('my_seller_capability', const {});
  if (r.error != null) throw MarcheException(r.error);
  return r.data is Map ? SellerCapability.fromJson(Map<String, dynamic>.from(r.data as Map)) : null;
});

/// Écrans vendeur du registre : 57 à 69.
bool isSellerScreenId(String id) {
  final n = int.tryParse(RegExp(r'^\d+').firstMatch(id)?.group(0) ?? '');
  return n != null && n >= 57 && n <= 69 && RegExp(r'^\d+$').hasMatch(id);
}

/// Enveloppe des écrans et routes vendeur : l'espace vendeur ne s'ouvre que si la capacité est réunie ; sinon l'écran explicatif des conditions
/// s'affiche (compte non connecté : invitation à se connecter). Hors connexion au serveur (aperçu, tests), l'écran reste ouvert.
class SellerGate extends ConsumerWidget {
  const SellerGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Backend.ready) return child;
    if (ref.watch(authProvider.select((a) => a.current == null))) {
      return marcheLoginRequired(context, ref, title: 'Espace vendeur', pour: 'accéder à l’espace vendeur');
    }
    return ref.watch(sellerCapabilityProvider).when(
          loading: () => const MarchePage(title: 'Espace vendeur', child: Center(child: CircularProgressIndicator())),
          error: (e, _) => MarchePage(
            title: 'Espace vendeur',
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(e is MarcheException ? e.toString() : marcheErrorText('$e'), textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5)),
                  const SizedBox(height: 16),
                  mButton('Réessayer', () => ref.invalidate(sellerCapabilityProvider)),
                ]),
              ),
            ),
          ),
          data: (c) => c != null && c.canSell ? child : const SellerConditionsScreen(),
        );
  }
}

/// Pause / reprise de la boutique (fonctions serveur `seller_pause` et `seller_resume`). Aucun message de succès sans réponse du serveur.
class SellerPauseCard extends ConsumerStatefulWidget {
  const SellerPauseCard({super.key, required this.paused});
  final bool paused;

  @override
  ConsumerState<SellerPauseCard> createState() => _SellerPauseCardState();
}

class _SellerPauseCardState extends ConsumerState<SellerPauseCard> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (!widget.paused) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Mettre la boutique en pause ?'),
          content: Text('Vos annonces publiées seront masquées et personne ne pourra vous passer de nouvelle commande. Vos commandes en cours, vos retraits et vos messages continuent normalement. Vous les rétablissez quand vous voulez, sans nouvelle validation.'),
          actions: [
            TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(c, false), child: Text('Annuler')),
            TextButton(style: TextButton.styleFrom(minimumSize: const Size(48, 48)), onPressed: () => Navigator.pop(c, true), child: Text('Mettre en pause')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _busy = true);
    final r = await Backend.rpc(widget.paused ? 'seller_resume' : 'seller_pause', widget.paused ? const {} : const {'p_reason': null});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) {
      gToast(context, Backend.userMessage('${r.error}'));
      return;
    }
    ref.invalidate(sellerCapabilityProvider);
    gToast(context, widget.paused ? 'Boutique reprise : vos annonces sont de nouveau visibles.' : 'Boutique en pause : vos annonces sont masquées.');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.paused ? kRed : kLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.paused ? 'Votre boutique est en pause' : 'Boutique ouverte', style: mst(14.5, w: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          widget.paused
              ? 'Vos annonces sont masquées et vous ne recevez pas de nouvelle commande. Vos commandes en cours se poursuivent.'
              : 'Besoin de souffler ? La pause masque vos annonces et suspend les nouvelles commandes, sans toucher à vos commandes en cours.',
          style: mst(13, c: kGrey).copyWith(height: 1.45),
        ),
        const SizedBox(height: 10),
        mButton(widget.paused ? 'Reprendre mes ventes' : 'Mettre ma boutique en pause', _busy ? null : _toggle, dark: widget.paused),
      ]),
    );
  }
}

/// « Devenir vendeur » : explique les conditions et l'état de chacune pour le compte connecté, avec la démarche qui permet de la remplir.
class SellerConditionsScreen extends ConsumerWidget {
  const SellerConditionsScreen({super.key});

  static const _help = {
    'student': 'Les produits et services sont proposés par des étudiants. Votre compte actuel n’est pas un compte étudiant : il n’y a pas de second compte à créer, la capacité de vendre s’ajoute au compte étudiant.',
    'student_verified': 'Déposez votre carte d’étudiant ou votre certificat de scolarité : l’équipe de votre département la valide.',
    'phone_verified': 'Enregistrez votre numéro dans « Informations personnelles » puis saisissez le code reçu.',
    'not_suspended': 'Votre compte est suspendu : contactez le support pour connaître le motif et les suites possibles.',
    'profile': 'Terminez d’abord la création de votre profil.',
  };

  void _act(BuildContext context, String key) {
    switch (key) {
      case 'student_verified':
        gOpen(context, '18c');
      case 'phone_verified':
        GoRouter.of(context).push('/parametres/informations');
      case 'not_suspended':
        GoRouter.of(context).push('/aide/contact');
      case 'profile':
        gOpen(context, '18b');
    }
  }

  static const _actionLabel = {
    'student_verified': 'Vérifier mon statut d’étudiant',
    'phone_verified': 'Vérifier mon téléphone',
    'not_suspended': 'Contacter le support',
    'profile': 'Compléter mon profil',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (Backend.ready && ref.watch(authProvider.select((a) => a.current == null))) {
      return marcheLoginRequired(context, ref, title: 'Devenir vendeur', pour: 'voir les conditions pour vendre');
    }
    return MarchePage(
      title: 'Devenir vendeur',
      child: ref.watch(sellerCapabilityProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(e is MarcheException ? e.toString() : marcheErrorText('$e'), textAlign: TextAlign.center, style: mst(14, c: kGrey).copyWith(height: 1.5)),
                  const SizedBox(height: 16),
                  mButton('Réessayer', () => ref.invalidate(sellerCapabilityProvider)),
                ]),
              ),
            ),
            data: (c) {
              if (c == null) return mNote('Les conditions pour vendre s’affichent une fois l’application connectée au serveur.');
              return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
                Text(c.canSell ? 'Vous pouvez vendre' : 'Vendre sur Boutik-École', style: mst(22, w: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  c.canSell
                      ? 'Toutes les conditions sont réunies : votre espace vendeur est ouvert. Publier une annonce demande en plus un compte certifié${c.canPublish ? ' (c’est le cas)' : ''}.'
                      : 'Vendre n’est pas un compte à part : c’est une capacité de votre compte étudiant, ouverte quand les conditions ci-dessous sont toutes réunies. Vous gardez le même compte pour acheter et pour vendre.',
                  style: mst(14, c: kGrey).copyWith(height: 1.5),
                ),
                const SizedBox(height: 16),
                for (final x in c.conditions)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: x.ok ? kGreen : kLine)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(x.ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 22, color: x.ok ? kGreen : kGrey),
                        const SizedBox(width: 10),
                        Expanded(child: Text(x.label, style: mst(14.5, w: FontWeight.w700))),
                      ]),
                      if (!x.ok) ...[
                        const SizedBox(height: 6),
                        Text(_help[x.key] ?? '', style: mst(13, c: kGrey).copyWith(height: 1.45)),
                        if (_actionLabel.containsKey(x.key) && (c.role == 'student' || x.key == 'not_suspended' || x.key == 'profile')) ...[
                          const SizedBox(height: 10),
                          mButton(_actionLabel[x.key]!, () => _act(context, x.key), dark: false),
                        ],
                      ],
                    ]),
                  ),
                if (c.canSell) SellerPauseCard(paused: c.paused),
                if (c.role == 'student') const Padding(padding: EdgeInsets.only(top: 6), child: StudentVerificationCard(width: double.infinity)),
                const SizedBox(height: 14),
                if (c.canSell) mButton('Ouvrir mon espace vendeur', () => gOpen(context, '57')) else mButton('Actualiser', () => ref.invalidate(sellerCapabilityProvider), dark: false),
              ]);
            },
          ),
    );
  }
}
