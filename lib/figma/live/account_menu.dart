import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../nav.dart';
import 'access.dart';
import 'admin_access.dart';
import 'auth.dart';
import 'backend.dart';
import 'seller_capability.dart' show SellerCapability, sellerCapabilityProvider;
import 'delivery.dart' show homeDeliverySettingsDialog;
import 'docs_prestataire.dart' show downloadSellerStatement;
import 'feedback.dart';
import 'certificates_page.dart';
import 'company_home.dart' show showCompanyPlans;
import 'lots.dart';
import 'qr.dart' show myQrDialog;
import 'verification_equipe.dart';
import 'referral.dart';
import 'social_posts.dart' show blockedPeopleDialog;
import 'services.dart';

Future<void> _livraisonVendeur(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/marche/livraison');
Future<void> _livraisonPlateforme(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/marche/livraison?plateforme=1');
Future<void> _accueilCommun(BuildContext context, WidgetRef ref) async => GoRouter.of(context).go('/s/03?vue=standard');
Future<void> _marketplace(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/marche');
Future<void> _innovations(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/innovations');
Future<void> _concours(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/concours');
Future<void> _mentors(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/mentors');
Future<void> _litiges(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/litiges');
Future<void> _evaluations(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/evaluations');
Future<void> _fournisseursEvaluation(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/admin/evaluations');
Future<void> _ficheEntreprise(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/entreprise/profil');
Future<void> _equipeEntreprise(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/entreprise/equipe');
Future<void> _partenariatsOrganisation(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/entreprise/partenariats');
Future<void> _forfaitsDeLEntreprise(BuildContext context, WidgetRef ref) => showCompanyPlans(context, ref);
Future<void> _publierOffre(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/opportunites/publier');
Future<void> _mesOffres(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/opportunites/mes');
Future<void> _publierConcours(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/concours/publier');
Future<void> _mesConcours(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/concours/mes');
Future<void> _achatsEntreprise(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/entreprise/achats');
Future<void> _entreprisesAVerifier(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/admin/entreprises');
Future<void> _forfaitsEntreprises(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/admin/forfaits');
Future<void> _sequestre(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/admin/sequestre');
Future<void> _mesEntreprises(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/mes-entreprises');
Future<void> _comptesTest(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/comptes-test');
Future<void> _promotions(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/marche/promotions');
Future<void> _moderationReseau(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/moderation/reseau');
Future<void> _accompagnement(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/accompagnement');
Future<void> _mesEvenements(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/evenements/mes');
Future<void> _gererEvenements(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/evenements/gerer');
Future<void> _partenariatsInstitutionnels(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/direction/partenariats');
Future<void> _validationsInstitutionnelles(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/direction/validations');
Future<void> _espaceDepartement(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/departement');
Future<void> _rattachementsDepartement(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/departement/rattachements');
Future<void> _mesAvis(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/mes-avis');
Future<void> _mesInformations(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/parametres/informations');
Future<void> _devenirVendeur(BuildContext context, WidgetRef ref) async => GoRouter.of(context).push('/vendeur/conditions');
Future<void> _seConnecter(BuildContext context, WidgetRef ref) => requireLogin(context, ref, 'ouvrir votre espace personnel');
Future<void> _creerCompte(BuildContext context, WidgetRef ref) async => openAuthFromHere(context, ref, signup: true);

const _st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF111015));

/// Une entrée du menu du compte : un écran (ouvert si le rôle l'autorise) ou une action.
/// [seller] : outil de l'espace vendeur (masqué tant que la capacité vendeur n'est pas réunie) ; [becomeSeller] : « Devenir vendeur », proposé tant qu'elle ne l'est pas ;
/// [connected] : action réservée aux comptes connectés (non proposée à une personne non connectée, comme les écrans de [loginRequiredScreens]).
class _Entry {
  const _Entry(this.label, {this.screen, this.action, this.roles, this.seller = false, this.becomeSeller = false, this.connected = false, this.perms});
  final String label;
  final String? screen;
  final Future<void> Function(BuildContext, WidgetRef)? action;
  final Set<String>? roles; // null = tous les rôles connectés
  final bool seller, becomeSeller, connected;

  /// Permissions d'équipe : un agent finance ou support ne voit l'entrée que s'il détient l'une d'elles (l'administrateur et les autres rôles ne sont pas concernés).
  final Set<String>? perms;

  bool get needsAccount => connected || (screen != null && loginRequiredScreens.contains(screen!.replaceAll('_', '-')));
}

class _Group {
  const _Group(this.title, this.entries);
  final String title;
  final List<_Entry> entries;
}

Future<void> _devis(BuildContext c, WidgetRef r) => quotesDialog(c, r);
Future<void> _releveVendeur(BuildContext c, WidgetRef r) => downloadSellerStatement(c, r);
Future<void> _certificats(BuildContext c, WidgetRef r) => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const CertificatesPage()));
Future<void> _parrain(BuildContext c, WidgetRef r) => claimReferralDialog(c, r);
Future<void> _reclamations(BuildContext c, WidgetRef r) => claimsDialog(c, r);
Future<void> _assign(BuildContext c, WidgetRef r) => assignNeedDialog(c, r);
Future<void> _suppressionsCompte(BuildContext c, WidgetRef r) => accountDeletionsDialog(c, r, canExecute: roleKey(r.read(authProvider).current) == 'admin');

final _groups = <_Group>[
  const _Group('Pages de base', [
    _Entry('Accueil Boutik-École', action: _accueilCommun),
    _Entry('Marketplace', action: _marketplace),
  ]),
  const _Group('Mes achats', [
    _Entry('Mes commandes', screen: '45'),
    _Entry('Mes favoris', screen: '25'),
    _Entry('Mes collections', screen: '25b'),
    _Entry('Mes adresses', screen: '27'),
    _Entry('Mes avis', action: _mesAvis, connected: true),
    _Entry('Mes devis', action: _devis, connected: true),
    _Entry('Mes réclamations', action: _reclamations, connected: true),
    _Entry('Comparer des offres', screen: '26'),
    _Entry('Mentors', action: _mentors),
    _Entry('Mes litiges', action: _litiges, connected: true),
    _Entry('Mes organisations (équipes)', action: _mesEntreprises, connected: true),
    _Entry('Comptes de test (administrateur)', action: _comptesTest, roles: {'admin'}),
    _Entry('Concours, bourses et hackathons', action: _concours),
    _Entry('Innovations (SOS, défis, victoires)', action: _innovations),
  ]),
  const _Group('Découvrir et participer', [
    _Entry('Événements', screen: '100'),
    _Entry('Mes événements (inscriptions et reçus)', action: _mesEvenements, connected: true),
    _Entry('Hackathons et concours', screen: '160'),
    _Entry('Opportunités pour moi', screen: '151'),
    _Entry('Communauté et vitrine', screen: '103'),
    _Entry('Départements', screen: '214'),
    _Entry('Marché des vœux', screen: '216'),
    _Entry('Duels de talents', screen: '220'),
    _Entry('Résultats des duels', screen: '221'),
    _Entry('Lancer un duel', screen: '219', roles: {'client', 'company', 'dept', 'direction', 'admin'}),
    _Entry('Ateliers en direct', screen: '223'),
    _Entry('Reels et lives', screen: '245'),
    _Entry('Défis et récompenses', screen: '253'),
    _Entry('Parrainer et gagner', screen: '240'),
    _Entry('J’ai un code de parrainage', action: _parrain, roles: {'client', 'student', 'company'}),
    _Entry('Évaluations de compétences', action: _evaluations, roles: {'student', 'client'}, connected: true),
    _Entry('Missions sur mesure', screen: '191'),
    _Entry('Impact de Boutik-École', screen: '238'),
  ]),
  const _Group('Communication', [
    _Entry('Messages', screen: '52'),
    _Entry('Notifications', screen: '50'),
    _Entry('Alertes et opportunités', screen: '155'),
  ]),
  const _Group('Espace vendeur', [
    _Entry('Devenir vendeur (conditions)', action: _devenirVendeur, roles: {'client', 'student'}, becomeSeller: true),
    _Entry('Tableau de bord', screen: '57', roles: {'student'}, seller: true),
    _Entry('Mes annonces', screen: '58', roles: {'student'}, seller: true),
    _Entry('Commandes reçues', screen: '63', roles: {'student'}, seller: true),
    _Entry('Mes tarifs de livraison', action: _livraisonVendeur, roles: {'student'}, seller: true),
    _Entry('Devis reçus', action: _devis, roles: {'student'}, seller: true),
    _Entry('Relevé de ventes et de missions (PDF)', action: _releveVendeur, roles: {'student'}, seller: true),
    _Entry('Stocks', screen: '62', roles: {'student'}, seller: true),
    _Entry('Revenus', screen: '66', roles: {'student'}, seller: true),
    _Entry('Statistiques', screen: '67', roles: {'student'}, seller: true),
    _Entry('Mes documents', screen: '73', roles: {'student', 'dept', 'admin'}),
    _Entry('Publier un service', screen: '59', roles: {'student'}, seller: true),
    _Entry('Conformité du compte', screen: '69', roles: {'student'}, seller: true),
    _Entry('Offres classées pour vous', screen: '152', roles: {'student'}),
    _Entry('Mon dossier', screen: '154', roles: {'student'}),
    _Entry('Opportunités', screen: '75', roles: {'dept', 'admin'}),
    _Entry('Mon CV vivant', screen: '227', roles: {'student', 'dept', 'admin'}),
    _Entry('Tableau de bord du studio', screen: 'D1', roles: {'student', 'dept', 'admin'}),
    _Entry('Connecter mes outils', screen: 'P5', roles: {'student', 'dept', 'admin'}),
    _Entry('Aller en direct', screen: 'L1', roles: {'student', 'dept', 'admin'}),
    _Entry('Programmer un live', screen: '224', roles: {'student', 'dept', 'admin'}),
    _Entry('Lancer une campagne de financement', screen: '84', roles: {'student', 'dept', 'admin'}),
    _Entry('Publier un vœu', screen: '218', roles: {'client', 'student', 'dept', 'admin'}),
    _Entry('Registre des innovations', screen: '87', roles: {'student', 'dept', 'admin'}),
    _Entry('Kit à partager', screen: '242', roles: {'student', 'dept', 'admin'}),
    _Entry('Besoins à pourvoir', action: openNeedsDialog, roles: {'student'}),
    _Entry('Mes missions et jalons', action: myMissionsDialog, roles: {'student', 'dept', 'admin'}),
    _Entry('Mes vœux', action: myWishesDialog, roles: {'client', 'student', 'dept', 'admin'}),
    _Entry('Soumettre mon projet', screen: '205', roles: {'student', 'dept', 'admin'}),
    _Entry('Accompagnement de mes projets', action: _accompagnement, roles: {'student', 'dept', 'admin'}),
    _Entry('Journal du projet', screen: '82', roles: {'student', 'dept', 'admin'}),
  ]),
  const _Group('Espace organisation', [
    _Entry('Fiche de l’organisation et vérification', action: _ficheEntreprise, roles: {'company', 'admin'}),
    _Entry('Équipe de l’organisation', action: _equipeEntreprise, roles: {'company', 'admin'}),
    _Entry('Partenariats avec l’établissement', action: _partenariatsOrganisation, roles: {'company', 'admin'}),
    _Entry('Forfaits de l’organisation', action: _forfaitsDeLEntreprise, roles: {'company', 'admin'}),
    _Entry('Mes organisations (invitations et espaces partagés)', action: _mesEntreprises, roles: {'company', 'admin'}),
    _Entry('Tableau de bord de l’organisation', screen: '187', roles: {'company', 'admin'}),
    _Entry('Publier un besoin', screen: '90', roles: {'company', 'admin'}),
    _Entry('Historique des besoins', screen: '99', roles: {'company', 'admin'}),
    _Entry('Propositions reçues', screen: '93', roles: {'company', 'admin'}),
    _Entry('Publier une offre (stage, emploi, mission)', action: _publierOffre, roles: {'company', 'admin'}),
    _Entry('Mes offres et candidatures', action: _mesOffres, roles: {'company', 'admin'}),
    _Entry('Publier un concours ou un hackathon', action: _publierConcours, roles: {'company', 'admin'}),
    _Entry('Mes concours', action: _mesConcours, roles: {'company', 'admin'}),
    _Entry('Rechercher des talents', screen: '91', roles: {'company', 'admin'}),
    _Entry('Défis d’innovation', screen: '96', roles: {'company', 'admin'}),
    _Entry('Espace projet', screen: '285', roles: {'company', 'admin'}),
    _Entry('Accueil B2B', screen: '262', roles: {'company', 'admin'}),
    _Entry('Achats de l’organisation', action: _achatsEntreprise, roles: {'company', 'admin'}),
  ]),
  const _Group('Administration', [
    _Entry('Centre d’administration', screen: '300', roles: {'finance', 'support', 'admin'}),
    _Entry('Espace du département', action: _espaceDepartement, roles: {'dept', 'direction', 'admin'}),
    _Entry('Rattachement des comptes Département', action: _rattachementsDepartement, roles: {'admin'}),
    _Entry('Console du département', screen: '108', roles: {'dept', 'admin'}),
    _Entry('Modération du réseau social', action: _moderationReseau, roles: {'dept', 'admin', 'support', 'finance'}, perms: {'security.moderation', 'security.reports'}),
    _Entry('Registre des certificats', screen: '283', roles: {'dept', 'admin'}),
    _Entry('Catalogue du département', screen: '288', roles: {'dept', 'admin'}),
    _Entry('Espace jury', screen: '178', roles: {'dept', 'admin'}),
    _Entry('Vœux à valider', action: reviewWishesDialog, roles: {'dept', 'admin'}),
    _Entry('Campagnes à valider', action: reviewCampaignsDialog, roles: {'dept', 'admin'}),
    _Entry('Jalons de campagne à valider', action: reviewMilestonesDialog, roles: {'dept', 'admin'}),
    _Entry('Projets à examiner', action: reviewProjectsDialog, roles: {'dept', 'admin'}),
    _Entry('Attribuer un besoin', action: _assign, roles: {'dept', 'admin'}),
    _Entry('Émettre un certificat', action: issueCertificateDialog, roles: {'dept', 'admin'}),
    _Entry('Révoquer un certificat', action: revokeCertificateDialog, roles: {'dept', 'admin'}),
    _Entry('Demandes de certification (badge)', action: certificationRequestsDialog, roles: {'admin', 'dept'}),
    _Entry('Pièces justificatives à examiner', action: documentReviewDialog, roles: {'admin', 'support', 'finance', 'dept'}, perms: {'support.requests'}),
    _Entry('Établissements et départements proposés', action: referenceReviewDialog, roles: {'admin', 'support', 'finance'}, perms: {'support.requests'}),
    _Entry('Suppressions de compte', action: _suppressionsCompte, roles: {'admin', 'support', 'finance'}, perms: {'support.requests'}),
    _Entry('Réinitialiser une double authentification', action: mfaResetDialog, roles: {'admin', 'support', 'finance'}, perms: {'security.accounts'}),
    _Entry('Organisations à vérifier', action: _entreprisesAVerifier, roles: {'admin'}),
    _Entry('Forfaits des organisations', action: _forfaitsEntreprises, roles: {'admin'}),
    _Entry('Séquestre et règle de répartition', action: _sequestre, roles: {'admin', 'finance', 'support'}, perms: {'finance.read'}),
    _Entry('Journal des incidents des bornes', action: kioskIncidentsDialog, roles: {'support', 'finance', 'admin'}, perms: {'support.orders', 'tech.maintenance'}),
    _Entry('Remettre une commande (code de retrait)', action: confirmPickupDialog, roles: {'support', 'finance', 'admin'}, perms: {'support.orders'}),
    _Entry('Établissement et identité visuelle', screen: '118', roles: {'direction', 'admin'}),
    _Entry('Modèles de notifications', screen: '265', roles: {'admin', 'support', 'finance'}, perms: {'tech.config'}),
    _Entry('Inviter un membre du département', action: inviteMemberDialog, roles: {'dept', 'admin'}),
    _Entry('Gérer les événements officiels', action: _gererEvenements, roles: {'dept', 'direction', 'finance', 'admin'}, perms: {'finance.read'}),
    _Entry('Rapport sponsors', screen: '239', roles: {'direction', 'dept', 'admin'}),
    _Entry('Administration institutionnelle', screen: '117', roles: {'direction', 'admin'}),
    _Entry('Départements et filières', screen: '119', roles: {'direction', 'admin'}),
    _Entry('Partenariats institutionnels', action: _partenariatsInstitutionnels, roles: {'direction', 'dept', 'admin'}),
    _Entry('Validations institutionnelles', action: _validationsInstitutionnelles, roles: {'direction', 'dept', 'admin'}),
    _Entry('Rapports consolidés', screen: '125', roles: {'direction', 'admin'}),
    _Entry('Administration globale', screen: '127', roles: {'admin'}),
    _Entry('Rôles et permissions', screen: '180', roles: {'admin'}),
    _Entry('Équipes et permissions', screen: '305', roles: {'admin'}),
    _Entry('Rôles et périmètres', screen: '281', roles: {'admin'}),
    _Entry('Intégrations', screen: '280', roles: {'admin', 'support', 'finance'}, perms: {'tech.integrations'}),
    _Entry('Fournisseurs d’évaluation', action: _fournisseursEvaluation, roles: {'admin', 'support', 'finance'}, perms: {'tech.integrations'}),
    _Entry('Pages éditoriales', screen: '264', roles: {'admin', 'support', 'finance'}, perms: {'tech.config'}),
    _Entry('Innovation Radar', screen: '269', roles: {'admin'}),
    _Entry('Finance', screen: '139', roles: {'finance', 'support', 'direction', 'admin'}, perms: {'finance.read'}),
    _Entry('Registre financier', screen: '284', roles: {'finance', 'support', 'direction', 'admin'}, perms: {'finance.read'}),
    _Entry('Kiosques et support', screen: '145', roles: {'support', 'finance', 'admin'}, perms: {'support.orders', 'tech.maintenance'}),
    _Entry('Livraison à domicile (réglage)', action: homeDeliverySettingsDialog, roles: {'admin'}),
    _Entry('Promotions de la plateforme', action: _promotions, roles: {'admin'}),
    _Entry('Tarifs de livraison de la plateforme', action: _livraisonPlateforme, roles: {'admin'}),
    _Entry('Supervision des bornes', screen: '277', roles: {'support', 'finance', 'admin'}, perms: {'support.orders', 'tech.maintenance'}),
  ]),
  const _Group('Mon compte', [
    _Entry('Paramètres', screen: '148_1'),
    _Entry('Centre de confiance', screen: '174'),
    _Entry('Aide et support', screen: '49'),
    _Entry('Guide d’utilisation', screen: '179'),
    _Entry('Premiers pas', screen: '176', roles: {'client'}),
    _Entry('Canaux et notifications', screen: '236'),
    _Entry('Préférences d’alertes', screen: '156'),
    _Entry('Mes besoins publiés', action: myNeedsDialog),
    _Entry('Dossiers de mission', action: missionDossierDialog),
    _Entry('Mes certificats', action: _certificats),
    _Entry('Mon QR personnel', action: myQrDialog),
    _Entry('Personnes bloquées', action: blockedPeopleDialog),
    _Entry('Mon espace', screen: '261'),
    _Entry('Informations personnelles', action: _mesInformations, connected: true),
    _Entry('Mes données et confidentialité', screen: '273'),
    _Entry('Vérification en 2 étapes', screen: '272'),
    _Entry('Centre de sécurité', screen: '148_2'),
    _Entry('Économie de données', screen: '184'),
    _Entry('Conditions générales', screen: '274'),
  ]),
];

/// Entrées du menu visibles pour un rôle : (libellé, écran ou null pour une action).
List<(String, String?)> accountMenuEntries(String role) => [
      for (final g in _groups)
        for (final e in g.entries)
          if (e.roles == null || e.roles!.contains(role)) (e.label, e.screen),
    ];

/// Groupes du menu pour un rôle et une capacité vendeur connue ([cap] nul : inconnue ou hors connexion).
List<_Group> _visibleGroups(String role, SellerCapability? cap, {AdminAccess? access}) {
  final signedOut = role == 'visitor';
  final notCapable = cap != null && !cap.canSell;
  return [
    if (signedOut)
      const _Group('Mon compte', [
        _Entry('Se connecter', action: _seConnecter),
        _Entry('Créer un compte', action: _creerCompte),
      ]),
    for (final g in _groups)
      _Group(g.title, [
        for (final e in g.entries)
          if ((e.roles == null ? true : e.roles!.contains(role)) &&
              !(signedOut && e.needsAccount) &&
              (e.perms == null || access == null || (role != 'finance' && role != 'support') || access.hasAny(e.perms!)) &&
              !(e.seller && notCapable) &&
              !(e.becomeSeller && !(notCapable || (cap == null && role == 'client'))))
            e,
      ]),
  ].where((g) => g.entries.isNotEmpty).toList();
}

/// Libellés du menu du compte pour un rôle et une capacité vendeur donnés (voir [accountMenu]).
List<String> accountMenuLabels(String role, {SellerCapability? cap}) => [for (final g in _visibleGroups(role, cap)) for (final e in g.entries) e.label];

/// Menu du compte (écran 10) : les accès réels de la personne, selon son rôle ; rien n'est affiché si le rôle n'y a pas droit.
/// Une personne non connectée n'y voit que l'invitation à se connecter ou à créer un compte et les pages publiques (un seul parcours : le même compte sert
/// à consulter, acheter et, pour un étudiant vérifié, vendre). Les outils vendeur ne sont proposés qu'avec la capacité vendeur ; sinon « Devenir vendeur ».
Future<void> accountMenu(BuildContext context, WidgetRef ref) async {
  final role = roleKey(ref.read(authProvider).current);
  SellerCapability? cap;
  if (Backend.ready && role != 'visitor') {
    try {
      cap = await ref.read(sellerCapabilityProvider.future).timeout(const Duration(seconds: 3));
    } catch (_) {
      cap = null;
    }
  }
  if (!context.mounted) return;
  AdminAccess? access;
  if (role == 'finance' || role == 'support') {
    try {
      access = await ref.read(adminAccessProvider.future).timeout(const Duration(seconds: 3));
    } catch (_) {
      access = null;
    }
  }
  if (!context.mounted) return;
  final visible = _visibleGroups(role, cap, access: access);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 420),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.82),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), children: [
          Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFDAD5E4), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('Mon compte · ${roleNames[role] ?? ''}', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
          for (final g in visible) ...[
            const SizedBox(height: 14),
            Text(g.title, style: _st.copyWith(fontSize: 12, color: const Color(0xFF57545F), fontWeight: FontWeight.w600)),
            for (final e in g.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.label, style: _st.copyWith(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF57545F)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (e.screen != null) {
                    gOpen(context, e.screen!);
                  } else {
                    e.action?.call(context, ref);
                  }
                },
              ),
          ],
          const Divider(height: 26),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Toutes les rubriques', style: _st.copyWith(color: const Color(0xFF5A3FE0), fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              gEspace(context);
            },
          ),
        ]),
      ),
    ),
  );
}
