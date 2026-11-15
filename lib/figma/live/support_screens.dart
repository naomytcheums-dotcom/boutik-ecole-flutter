import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../nav.dart';
import 'access.dart' show canOpen;
import 'auth.dart';
import 'backend.dart';
import 'tp_ui.dart';

/// Aide et support : articles d'aide rédigés (contenu éditorial de l'application), demande d'aide enregistrée sur le serveur
/// (table support_tickets) et liste « Mes demandes » avec la réponse du support.

class HelpArticle {
  const HelpArticle(this.title, this.intro, this.steps, {this.actions = const []});
  final String title, intro;
  final List<(String, String)> steps;

  /// Boutons de fin d'article : libellé et destination (numéro d'écran du manifeste, ou chemin commençant par « / »).
  final List<(String, String)> actions;
}

const helpTopics = <String, HelpArticle>{
  'commandes': HelpArticle(
    'Commandes et livraisons',
    'Tout ce qui concerne le suivi et la réception de vos achats.',
    [
      ('Suivre une commande', 'Ouvrez « Mes commandes », touchez la commande : sa frise indique l’étape (confirmée, en préparation, expédiée, livrée).'),
      ('Retrait ou livraison à domicile', 'Au paiement, choisissez le retrait sur le campus ou la livraison à domicile dans les villes proposées. Les frais de livraison sont affichés avant de payer.'),
      ('Être prévenu(e)', 'Une notification vous prévient quand la commande est prête au retrait ou en livraison. Pour le retrait, présentez le code de la commande.'),
      ('Un problème avec une commande', 'Depuis la commande, ouvrez une réclamation (colis non reçu, article abîmé, annulation, remboursement) : le vendeur et l’équipe peuvent vous répondre.'),
    ],
    actions: [('Mes commandes', '28')],
  ),
  'paiements': HelpArticle(
    'Paiements et remboursements',
    'Comment payer et que faire si un paiement pose problème.',
    [
      ('Moyens de paiement', 'Selon la commande : Mobile Money (Orange Money, MTN MoMo), paiement à la livraison pour certaines commandes, ou paiement déclaré par messagerie et vérifié par l’équipe.'),
      ('Vérifier un paiement', 'Un paiement déclaré par messagerie reste « en attente de vérification » jusqu’à sa confirmation ; vous êtes notifié(e) dès qu’il est confirmé.'),
      ('Ne payez qu’ici', 'Ne payez jamais un vendeur en dehors de l’application : un paiement direct n’est ni suivi ni remboursable.'),
      ('Demander un remboursement', 'Ouvrez une réclamation depuis la commande en choisissant « Remboursement ». Le délai dépend de la réponse du vendeur et de l’examen de l’équipe.'),
    ],
    actions: [('Mes paiements', '/paiements'), ('Mes commandes', '28')],
  ),
  'compte': HelpArticle(
    'Compte et sécurité',
    'Garder votre compte et vos informations en sécurité.',
    [
      ('Mot de passe', 'Choisissez un mot de passe d’au moins 8 caractères, différent de vos autres comptes. Vous pouvez le changer depuis « Mon compte ».'),
      ('Vérification en 2 étapes', 'Activez-la dans « Mon compte » : un code personnel est demandé à chaque connexion.'),
      ('Ne partagez jamais vos codes', 'Les codes reçus par SMS, WhatsApp ou e-mail ne doivent être donnés à personne.'),
      ('Appareils', 'Sur un appareil partagé, déconnectez-vous toujours. « Se déconnecter partout » ferme toutes vos sessions.'),
    ],
    actions: [('Mon compte', '10'), ('Centre de confiance', '174')],
  ),
  'suivre': HelpArticle(
    'Comment suivre ma commande ?',
    'Le suivi se trouve dans « Mes commandes ».',
    [
      ('Ouvrir la commande', 'Dans « Mes commandes », touchez la commande souhaitée.'),
      ('Lire la frise', 'La frise indique l’étape en cours. Une commande « en attente de paiement » n’est pas encore préparée.'),
      ('Écrire au vendeur', 'Depuis la commande, « Contacter le vendeur » ouvre une conversation liée à cette commande.'),
    ],
    actions: [('Mes commandes', '28')],
  ),
  'vendeur': HelpArticle(
    'Comment devenir vendeur ?',
    'La vente est réservée aux étudiants-vendeurs.',
    [
      ('Un compte Client ne vend pas', 'Avec un compte Client, vous achetez, discutez avec les vendeurs et suivez vos commandes ; la publication d’annonces n’est pas disponible.'),
      ('Créer un compte étudiant-vendeur', 'Pour vendre vos créations, créez un compte avec le profil Étudiant-vendeur : l’espace vendeur (annonces, stock, commandes) y est réservé.'),
      ('Besoin d’un produit sur mesure ?', 'Vous pouvez aussi déposer un besoin de mission : des étudiants vous répondent avec une proposition.'),
    ],
    actions: [('Déposer un besoin', '191')],
  ),
  'retrait': HelpArticle(
    'Quels sont les délais de retrait ?',
    'Le délai dépend du vendeur et de la préparation de la commande.',
    [
      ('Pas de délai fixe', 'Le vendeur prépare la commande après le paiement ; l’application ne garantit pas de délai précis.'),
      ('Quand retirer ?', 'Vous recevez la notification « Commande prête au retrait ». Présentez alors le code de la commande au point de retrait.'),
      ('Sans nouvelle ?', 'Écrivez au vendeur depuis la commande, ou ouvrez une réclamation si la commande n’avance pas.'),
    ],
    actions: [('Mes commandes', '28'), ('Contacter le support', '/aide/contact')],
  ),
};

/// Ouvre la destination d'un article ou d'un bouton d'aide : chemin (« /… »), écran du manifeste ou article. Un écran refusé au rôle du compte
/// est remplacé par l'article d'aide [fallback], jamais par une page « introuvable ».
void openHelpTarget(BuildContext context, String target, {String fallback = ''}) {
  if (target.startsWith('/')) {
    GoRouter.of(context).push(target);
    return;
  }
  if (target.startsWith('faq:')) {
    showHelpArticle(context, target.substring(4));
    return;
  }
  final account = ProviderScope.containerOf(context).read(authProvider).current;
  if (!canOpen(account, target)) {
    if (fallback.isNotEmpty) {
      showHelpArticle(context, fallback);
    } else {
      gToast(context, 'Cette page n’est pas disponible pour votre compte.');
    }
    return;
  }
  gOpen(context, target);
}

Future<void> showHelpArticle(BuildContext context, String id) {
  final a = helpTopics[id];
  if (a == null) return Future.value();
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (ctx) => TpPage(
      title: a.title,
      children: [
        Text(a.intro, style: tpSt(14, c: tpGrey, h: 1.5)),
        const SizedBox(height: 14),
        for (var i = 0; i < a.steps.length; i++)
          TpCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 28, height: 28, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFEEE9FF), shape: BoxShape.circle), child: Text('${i + 1}', style: tpSt(13, w: FontWeight.w800, c: tpViolet))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.steps[i].$1, style: tpSt(14, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(a.steps[i].$2, style: tpSt(13, c: tpGrey, h: 1.5)),
              ])),
            ]),
          ),
        const SizedBox(height: 8),
        for (final b in a.actions) ...[
          TpButton(b.$1, () {
            Navigator.of(ctx).pop();
            openHelpTarget(context, b.$2);
          }, dark: b == a.actions.first),
          const SizedBox(height: 10),
        ],
        tpNote('Votre question n’est pas traitée ici ? Écrivez au support depuis « Contacter le support ».'),
      ],
    ),
  ));
}

String ticketStatusLabel(Object? s) => switch ('$s') { 'answered' => 'Réponse reçue', 'closed' => 'Clôturée', _ => 'Transmise à l’équipe' };

/// « Contacter le support » : demande un compte au besoin, puis ouvre la saisie d'une demande d'aide.
Future<void> openSupportContact(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'écrire au support') || !context.mounted) return;
  GoRouter.of(context).push('/aide/contact');
}

Future<void> openMyTickets(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'voir vos demandes d’aide') || !context.mounted) return;
  GoRouter.of(context).push('/aide/demandes');
}

/// Demandes d'aide du compte connecté, de la plus récente à la plus ancienne.
final myTicketsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>?>((ref) async {
  ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  final uid = Backend.userId;
  if (!Backend.ready || uid == null) return null;
  final r = await Backend.rows('support_tickets', 'id,subject,message,status,reply,replied_at,created_at', eq: {'user_id': uid}, order: 'created_at', limit: 50);
  return r.error != null ? null : r.rows;
}, retry: (_, _) => null);

/// Écran de saisie d'une demande d'aide : enregistrée sur le serveur, limitée à 5 par jour, transmise aux comptes support et administrateur.
class SupportContactScreen extends ConsumerStatefulWidget {
  const SupportContactScreen({super.key});
  @override
  ConsumerState<SupportContactScreen> createState() => _SupportContactScreenState();
}

class _SupportContactScreenState extends ConsumerState<SupportContactScreen> {
  final subject = TextEditingController();
  final message = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = subject.text.trim(), m = message.text.trim();
    if (s.length < 3) return setState(() => error = 'Indiquez un sujet (3 caractères au moins).');
    if (m.length < 10) return setState(() => error = 'Décrivez votre demande en au moins 10 caractères.');
    if (!await requireLogin(context, ref, 'écrire au support') || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    final r = await Backend.rpc('support_ticket_create', {'p_subject': s, 'p_message': m});
    if (!mounted) return;
    if (r.error != null) return setState(() {
          busy = false;
          error = Backend.userMessage(r.error!);
        });
    ref.invalidate(myTicketsProvider);
    gToast(context, 'Votre demande est transmise à l’équipe.');
    GoRouter.of(context).pushReplacement('/aide/demandes');
  }

  @override
  Widget build(BuildContext context) => TpPage(
        title: 'Contacter le support',
        children: [
          Text('Décrivez votre problème : votre demande est enregistrée et transmise à l’équipe. Suivez-la, et lisez la réponse, dans « Mes demandes ».', style: tpSt(13, c: tpGrey, h: 1.5)),
          const SizedBox(height: 16),
          TpField('Sujet', subject, required: true, maxLength: 120),
          TpField('Votre message', message, required: true, lines: 6, maxLength: 2000),
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: tpSt(12.5, c: tpRed, w: FontWeight.w600))),
          TpButton('Envoyer ma demande', busy ? null : _send, busy: busy),
          const SizedBox(height: 10),
          TpButton('Mes demandes', () => GoRouter.of(context).pushReplacement('/aide/demandes'), dark: false),
          tpNote('Limite : 5 demandes par jour. Pour un problème sur une commande, utilisez plutôt « Réclamation » depuis la commande.'),
        ],
      );
}

/// « Mes demandes » : demandes envoyées au support, avec leur état et la réponse.
class MyTicketsScreen extends ConsumerWidget {
  const MyTicketsScreen({super.key});

  String _date(Object? iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(myTicketsProvider);
    return TpPage(
      title: 'Mes demandes',
      actions: [TpRound(icon: Icons.add_rounded, label: 'Nouvelle demande', onTap: () => GoRouter.of(context).pushReplacement('/aide/contact'))],
      children: [
        t.when(
          loading: () => tpNote('Chargement de vos demandes…'),
          error: (_, _) => tpNote('Vos demandes ne peuvent pas être chargées pour le moment.'),
          data: (rows) {
            if (rows == null) return tpNote('Vos demandes ne peuvent pas être chargées pour le moment. Vérifiez votre connexion puis réessayez.');
            if (rows.isEmpty) {
              return TpEmpty(title: 'Aucune demande', text: 'Vous n’avez encore écrit à aucun conseiller.', icon: Icons.support_agent_rounded, action: 'Contacter le support', onAction: () => GoRouter.of(context).pushReplacement('/aide/contact'));
            }
            return Column(children: [
              for (final r in rows)
                TpCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${r['subject']}', style: tpSt(14, w: FontWeight.w700))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: r['status'] == 'answered' ? const Color(0xFFDDF5EC) : const Color(0xFFEEE9FF), borderRadius: BorderRadius.circular(11)),
                        child: Text(ticketStatusLabel(r['status']), style: tpSt(11, w: FontWeight.w600, c: r['status'] == 'answered' ? tpGreen : tpViolet)),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(_date(r['created_at']), style: tpSt(11.5, c: tpGrey)),
                    const SizedBox(height: 8),
                    Text('${r['message']}', style: tpSt(13, c: tpGrey, h: 1.5)),
                    if ('${r['reply'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF4F1FB), borderRadius: BorderRadius.circular(14)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Réponse du support · ${_date(r['replied_at'])}', style: tpSt(11.5, w: FontWeight.w700, c: tpViolet)),
                          const SizedBox(height: 4),
                          Text('${r['reply']}', style: tpSt(13, h: 1.5)),
                        ]),
                      ),
                    ],
                    if (r['status'] != 'closed') ...[
                      const SizedBox(height: 10),
                      TpButton('Clôturer', () async {
                        final e = await Backend.rpc('support_ticket_close', {'p_id': r['id']});
                        if (!context.mounted) return;
                        if (e.error != null) return gToast(context, Backend.userMessage(e.error!));
                        ref.invalidate(myTicketsProvider);
                      }, dark: false, compact: true),
                    ],
                  ]),
                ),
            ]);
          },
        ),
      ],
    );
  }
}
