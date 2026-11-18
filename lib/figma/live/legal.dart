import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n.dart' show Text;
import '../nav.dart';
import 'auth.dart' show IntState, FlagOff;
import 'backend.dart' show Backend;

/// Texte des conditions (écran 17) : trois onglets réels, du contenu lisible hors démonstration.
/// Le texte décrit ce que l'application fait réellement ; toute évolution du service doit s'accompagner d'une nouvelle version (kTermsVersion).
const _ink = Color(0xFF111015);
const _grey = Color(0xFF4A4854);

TextStyle _st(double size, {FontWeight w = FontWeight.w400, Color c = _grey, double h = 1.5}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, height: h, textBaseline: TextBaseline.alphabetic);

final termsTabProvider = NotifierProvider<IntState, int>(IntState.new);

/// Règle de répartition en vigueur, lue en base (money_split_get) : jamais écrite en dur dans le texte. Null hors connexion ou si la lecture échoue.
final splitRuleLineProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (!Backend.ready || Backend.currentUserId == null) return null;
  final r = await Backend.rpc('money_split_get', const {});
  final cur = r.error == null && r.data is Map ? (r.data as Map)['current'] : null;
  if (cur is! Map) return null;
  final b = cur['beneficiary_pct'], i = cur['institution_pct'], p = cur['platform_pct'];
  if (b == null || i == null || p == null) return null;
  return 'Règle en vigueur aujourd’hui : $b % pour l’étudiant-vendeur, $i % pour le fonds d’innovation de l’établissement, $p % pour la plateforme, sur le prix des articles hors livraison.';
}, retry: (_, _) => null);

/// Cases « J'ai lu et j'accepte » de l'écran 274 : « Accepter et continuer » ne vaut acceptation que si les deux sont cochées.
final termsCguProvider = NotifierProvider<FlagOff, bool>(FlagOff.new);
final termsCgvProvider = NotifierProvider<FlagOff, bool>(FlagOff.new);

const _tabs = ['Conditions', 'Ventes', 'Confidentialité', 'Consentements'];

const termsSections = <List<(String, String)>>[
  [
    ('1. Objet', 'Boutik-École est la marketplace de l’expertise et des productions de l’IUT de Douala : elle met en relation des étudiants-vendeurs, des clients, des organisations et l’équipe de l’établissement.'),
    ('2. Compte', 'Vous vous engagez à fournir des informations exactes et à garder votre mot de passe confidentiel. Votre profil (client ou étudiant-vendeur) est fixé à la création du compte : seule l’administration peut le modifier. Un compte peut être suspendu en cas de manquement à ces conditions.'),
    ('3. Contenus publiés', 'Vous restez responsable de ce que vous publiez (annonces, photos, vidéos, messages). Les contenus illégaux, trompeurs ou contrefaits sont interdits ; l’équipe de modération peut les refuser ou les retirer. Les étudiants conservent la propriété intellectuelle de leurs productions et autorisent leur affichage sur la plateforme.'),
    ('4. Commandes et paiements', 'Les prix sont en FCFA. Le paiement se fait selon les moyens proposés par l’annonce (Mobile Money, paiement à la livraison…). En cas de problème, une réclamation peut être ouverte depuis la commande. Le détail des ventes figure dans les Conditions générales de vente.'),
    ('5. Responsabilité', 'Boutik-École met les personnes en relation : le vendeur reste responsable de la conformité de ce qu’il propose. La plateforme peut être interrompue pour maintenance.'),
    ('6. Évolution', 'Ces conditions peuvent changer. La version que vous acceptez est enregistrée avec la date de votre acceptation ; une nouvelle version vous sera proposée si elle modifie vos droits.'),
    ('7. Organisations (texte de travail, à valider par le propriétaire de la plateforme)', 'Un compte Organisation (entreprise commerciale, association, ONG, coopérative, fondation, institution, structure partenaire ou autre organisation reconnue) peut parcourir et acheter librement. Le type d’organisation est choisi à l’inscription et fixe les informations et les pièces justificatives demandées (par exemple RCCM ou NIU pour une entreprise commerciale, récépissé de déclaration et statuts pour une association). Pour publier un besoin, une offre, un concours ou rechercher des talents, la fiche (nom, type, secteur ou domaine d’action, interlocuteur, téléphone, pièces justificatives) doit être vérifiée par l’administrateur ; modifier le nom, le type, le numéro d’immatriculation ou le NIU d’une fiche vérifiée la soumet à une nouvelle vérification. Le forfait choisi fixe le nombre de besoins, d’offres et de concours actifs ; il est payé par Mobile Money ou activé par l’administration après paiement, et s’arrête à son échéance. Les données des étudiants (profil, CV) ne sont communiquées que selon leur consentement et ne servent qu’à l’objet de la prise de contact. Le propriétaire de la fiche répond des personnes qu’il invite dans son équipe.'),
  ],
  [
    ('Objet (version cgv-2026-11)', 'Ces conditions de vente s’appliquent aux achats de produits et de services publiés par des étudiants-vendeurs sur Boutik-École. Elles complètent les conditions d’utilisation. Votre acceptation est enregistrée séparément, à la confirmation d’une commande.'),
    ('Prix et paiement', 'Les prix sont affichés en FCFA. Le paiement se fait par Mobile Money (Orange Money, MTN MoMo) ou selon les moyens proposés par l’annonce. Une commande non payée dans le délai prévu (2 heures, 48 heures si un paiement manuel est en cours de vérification) est annulée automatiquement ; votre panier n’est alors pas débité.'),
    ('Retrait et livraison', 'Le retrait sur le campus est gratuit. La livraison à domicile, lorsqu’elle est proposée, est facturée au tarif affiché avant la confirmation de la commande ; aucun frais n’est ajouté après coup.'),
    ('Répartition du prix (texte de travail à valider par le propriétaire de la plateforme)', 'Sur chaque vente payée, le prix des articles (hors frais de livraison) est réparti entre l’étudiant-vendeur, le fonds d’innovation de l’établissement et la plateforme : selon la règle en vigueur, affichée sous ce texte une fois connecté et dans la rubrique « Mes revenus » du vendeur, calculée sur le prix des articles hors livraison. Le reliquat d’arrondi revient à la plateforme. La règle peut être modifiée par l’administration, avec historique ; elle ne s’applique qu’aux paiements futurs et ne modifie pas le prix que vous payez.'),
    ('Somme gardée jusqu’à la réception', 'Le montant d’une commande payée reste gardé par la plateforme jusqu’à la confirmation de la remise (par vous ou par le kiosque), ou jusqu’à la fin d’un délai de garde sans réclamation. Il n’est jamais reversé au vendeur pendant une réclamation, un litige ou une demande de remboursement en cours.'),
    ('Annulation et remboursement', 'Tant que la commande n’est pas payée, vous pouvez l’annuler depuis « Mes commandes ». Une fois payée, elle ne s’annule plus seule : vous demandez l’annulation ou le remboursement depuis la commande ; la demande est examinée par l’équipe et, si elle est acceptée, le remboursement se fait par le moyen de paiement utilisé.'),
    ('Réclamations et litiges', 'Si le produit n’est pas conforme ou n’est pas remis, ouvrez une réclamation depuis la commande : le vendeur répond. Sans accord, vous pouvez ouvrir un litige, tranché par l’équipe de la plateforme sur la base des échanges et des justificatifs de chacun.'),
    ('Responsabilité du vendeur', 'Le vendeur est responsable de la conformité, de la description et de la remise de ce qu’il propose. Boutik-École met les personnes en relation, garde les fonds jusqu’à la réception et arbitre les litiges.'),
  ],
  [
    ('Données collectées', 'Identité (nom, e-mail, téléphone), profil (ville, établissement, département, photo), pièces justificatives déposées dans un espace privé, commandes, adresses de livraison, messages, notifications et journaux de sécurité.'),
    ('À quoi elles servent', 'Au fonctionnement du service : commandes et livraison, vérification du compte, messagerie, notifications de service, sécurité et lutte contre la fraude.'),
    ('Qui les voit', 'Le vendeur reçoit ce qui est nécessaire à votre commande ; l’équipe de modération et d’administration accède aux informations utiles à sa mission ; les prestataires de paiement traitent les paiements. Vos données ne sont pas vendues.'),
    ('Fiche et pièces d’une organisation', 'Les pièces justificatives d’une organisation (immatriculation, récépissé, statuts, agrément, acte de création, numéro fiscal…) restent dans un espace privé : seuls le propriétaire de la fiche, ses administrateurs d’équipe, l’administration de la plateforme et l’équipe d’assistance (support) peuvent les consulter. Le numéro d’immatriculation, le NIU, le téléphone et l’interlocuteur sont réservés au propriétaire, aux administrateurs de l’organisation et à l’administration ; la fiche publique n’en montre rien.'),
    ('Position', 'Votre position n’est utilisée que si vous demandez vous-même la détection de votre ville.'),
    ('Conservation', 'Vos données sont conservées tant que le compte est actif. Après une demande de suppression, un délai de 30 jours permet de changer d’avis ; ensuite le compte est désactivé et vos données personnelles (nom, e-mail, téléphone, adresses, pièces, profil) sont anonymisées. Les commandes, paiements, factures et certificats émis sont conservés (obligation légale), sans votre identité. Vos annonces sont retirées, votre boutique est fermée et vos devis ouverts sont clos. La suppression est refusée, puis reste en attente, tant que des commandes sont en cours, que de l’argent est gardé en séquestre, qu’un solde ou un retrait n’est pas réglé, ou qu’une réclamation ou un litige est ouvert : terminez-les, puis la suppression est exécutée.'),
    ('Vos droits', 'Écran « Mes données » : exporter vos données ou demander la suppression du compte. Vous corrigez votre profil à tout moment. Pour toute question, contactez le support depuis l’aide.'),
  ],
  [
    ('Notifications de service', 'Le suivi des commandes, la livraison et la réception sont des messages nécessaires au service : ils ne se désactivent pas.'),
    ('Autres notifications', 'Les autres notifications se règlent dans « Notifications et confidentialité » (bouton ci-dessous).'),
    ('Statistiques', 'Aucune mesure d’audience n’est réalisée : il n’y a donc rien à accepter ni à refuser.'),
    ('Position', 'Demandée uniquement lorsque vous touchez « Détecter ma ville », après information.'),
  ],
];

class TermsReader extends ConsumerWidget {
  const TermsReader({super.key, this.width = 342, this.height = 560});
  final double width, height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(termsTabProvider);
    return SizedBox(
      width: width,
      height: height,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < _tabs.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == i,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(termsTabProvider.notifier).set(i),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: tab == i ? const Color(0xFF6A4DFF) : const Color(0xFFECE8F2), width: tab == i ? 3 : 1))),
                    child: Text(_tabs[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: _st(12, w: tab == i ? FontWeight.w700 : FontWeight.w500, c: tab == i ? _ink : const Color(0xFF57545F))),
                  ),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final (title, body) in termsSections[tab]) ...[
                Text(title, style: _st(15, w: FontWeight.w700, c: _ink)),
                const SizedBox(height: 4),
                Text(body, style: _st(13, h: 1.55)),
                if (title.startsWith('Répartition du prix') && ref.watch(splitRuleLineProvider).asData?.value != null) ...[
                  const SizedBox(height: 6),
                  Text(ref.watch(splitRuleLineProvider).asData!.value!, style: _st(13, w: FontWeight.w600, c: _ink, h: 1.55)),
                ],
                const SizedBox(height: 16),
              ],
              if (tab == 3)
                GestureDetector(
                  onTap: () => gOpen(context, '56'),
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(24)),
                    child: Text('Régler mes notifications', style: _st(13.5, w: FontWeight.w600, c: Colors.white)),
                  ),
                ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ]),
    );
  }
}
