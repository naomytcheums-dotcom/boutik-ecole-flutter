import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/screens.dart';
import '../../features/design_lab/design_lab_screen.dart';
import '../../figma/gsound.dart' show GAnim;
import '../../figma/live/access.dart';
import '../../figma/live/backend.dart' show Backend;
import '../../figma/live/produit_fiche.dart' show listingIdByTitle;
import '../../figma/live/start_gate.dart' show SignedInRedirect;
import '../../figma/g/g_280.dart';
import '../../figma/live/espace.dart';
import '../../figma/live/payment_methods_page.dart' show PaymentMethodsPage;
import '../../figma/live/personal_info.dart';
import '../../figma/live/shared_cv.dart';
import '../../figma/live/notifs.dart' show NotificationLauncher;
import '../../figma/live/moderation_reseau.dart' show SocialModerationScreen;
import '../../figma/live/support_screens.dart';
import '../../figma/live/support_staff.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/primary_button.dart';
import 'paths.dart';
import 'screen_entry.dart';
import '../../figma/live/paiement_messagerie.dart';
import '../../figma/live/premium_pub.dart';
import '../../figma/live/direction.dart' show DirectionPartnershipsScreen, DirectionValidationsScreen;
import '../../figma/live/dept_space.dart';
import '../../figma/live/communities.dart' show CommunityScreen;
import '../../figma/live/community_explore.dart';
import '../../figma/live/concours_screens.dart';
import '../../figma/live/company_home.dart';
import '../../figma/live/company_screens.dart';
import '../../figma/live/company_team.dart';
import '../../figma/live/company_public_page.dart' show CompanyPublicPage;
import '../../figma/live/verify_public.dart' show VerifyKind, VerifyPublicScreen;
import '../../figma/live/company_purchases.dart' show CompanyPurchasesScreen;
import '../../figma/live/org_partnerships.dart' show OrgPartnershipsScreen;
import '../../figma/live/student_profile.dart';
import '../../figma/live/evaluations.dart';
import '../../figma/live/evaluations_org.dart' show AssessmentCampaignsOrgScreen;
import '../../figma/live/evaluations_validateur.dart' show AssessmentReviewScreen;
import '../../figma/live/litiges_screens.dart';
import '../../figma/live/money_admin.dart';
import '../../figma/live/staff_portal.dart';
import '../../figma/live/test_accounts.dart';
import '../../figma/live/innovations_screens.dart';
import '../../figma/live/marche/marche_appels.dart';
import '../../figma/live/opportunites_screens.dart';
import '../../figma/live/menu_global.dart' show MenuModalObserver;
import '../../figma/live/dept_invite.dart' show DeptInviteScreen;
import '../../figma/live/mentors_screens.dart';
import '../../figma/live/marche/marche_compare.dart';
import '../../figma/live/marche/marche_livraison.dart';
import '../../figma/live/marche/marche_promotions.dart';
import '../../figma/live/marche/marche_screens.dart';
import '../../figma/live/marche/marche_vendeur.dart';
import '../../figma/live/marche/marche_boutiques.dart';
import '../../figma/live/downloads.dart' show DownloadsScreen;
import '../../figma/live/order_tracking.dart' show OrderTrackingListScreen, OrderTrackingScreen;
import '../../figma/live/creator_analytics.dart' show CreatorAnalyticsScreen;
import '../../figma/live/social_h13.dart' show CreatorProfileScreen;
import '../../figma/live/social_listes.dart' show FollowListKind, FollowListScreen, SuggestedCreatorsScreen;
import '../../figma/live/replays.dart' show MyReplaysScreen, ReplayPlayerScreen, ReplaysScreen;
import '../../figma/live/replay_quiz_editor.dart' show ReplayQuizEditorScreen;
import '../../figma/live/atelier.dart' show AtelierScreen;
import '../../figma/live/atelier_form.dart' show LivePrepareScreen;
import '../../figma/live/top100_public.dart';
import '../../figma/live/top100_admin.dart' show Top100AdminScreen;
import '../../figma/live/top100_admin_common.dart' show kRankingPerms;
import '../../figma/live/top100_discovery.dart' show TalentDiscoveryScreen, TalentFavoritesScreen;
import '../../figma/live/top100_student.dart';
import '../../figma/live/ranking_h13.dart' show RankingExplainScreen, MyTalentConsistencyScreen;
import '../../figma/live/passport_360.dart' show Passport360Screen;
import '../../figma/live/talent_pool_org.dart' show TalentPoolOrgScreen;
import '../../figma/live/org_contacts.dart' show OrgContactRequestsScreen;
import '../../figma/live/org_suivi.dart' show OrgMissionsTrackingScreen;
import '../../figma/live/evenements_gestion.dart';
import '../../figma/live/accompagnement.dart';
import '../../figma/live/client_space.dart' show MyReviewsScreen;
import '../../figma/live/seller_capability.dart' show SellerConditionsScreen, SellerGate;

final Map<String, ScreenEntry> screensById = {for (final s in allScreens) s.id: s};

/// Écran du manifeste pour un identifiant, sans tenir compte de la casse (`p3` et `P3` désignent le même écran du studio)
/// ni du séparateur des variantes (`148_1`, nom des fichiers générés, et `148-1`, identifiant du manifeste).
ScreenEntry? screenById(String? id) {
  if (id == null) return null;
  for (final k in {id, id.toUpperCase(), id.toLowerCase(), id.replaceAll('_', '-')}) {
    final e = screensById[k];
    if (e != null) return e;
  }
  return null;
}

GoRouter buildRouter({String initial = '/s/01'}) => GoRouter(
  initialLocation: initial,
  observers: [MenuModalObserver()],
  routes: [
    GoRoute(path: '/', redirect: (_, _) => screenPath('01')),
    // Outils internes : administrateur, ou mode debug (revue de maquette) ; jamais publics.
    GoRoute(path: '/catalogue', builder: (_, _) => const RouteGuard(name: '/catalogue', roles: {'admin'}, debugOpen: true, child: ScreenCatalogue())),
    GoRoute(path: '/espace', builder: (_, _) => const EspaceScreen()),
    GoRoute(path: '/parametres/informations', builder: (_, _) => const LoginGuard(child: PersonalInfoPage())),
    GoRoute(path: '/parametres/paiement', builder: (_, _) => const LoginGuard(child: PaymentMethodsPage())),
    GoRoute(path: '/mes-avis', builder: (_, _) => const LoginGuard(child: MyReviewsScreen())),
    GoRoute(path: '/vendeur/conditions', builder: (_, _) => const SellerConditionsScreen()),
    GoRoute(path: '/offres', builder: (_, _) => const PlansScreen()),
    GoRoute(path: '/campagnes', builder: (_, _) => const AdsScreen()),
    GoRoute(path: '/campagnes/validation', builder: (_, _) => const RouteGuard(name: '/campagnes/validation', roles: {'admin'}, child: AdReviewScreen())),
    GoRoute(path: '/direction/partenariats', builder: (_, _) => const RouteGuard(name: '/direction/partenariats', roles: {'direction', 'dept', 'admin'}, child: DirectionPartnershipsScreen())),
    GoRoute(path: '/direction/validations', builder: (_, _) => const RouteGuard(name: '/direction/validations', roles: {'direction', 'dept', 'admin'}, child: DirectionValidationsScreen())),
    GoRoute(path: '/communaute', builder: (_, _) => const CommunityScreen()),
    GoRoute(path: '/departement', builder: (_, _) => const RouteGuard(name: '/departement', roles: {'dept', 'direction', 'admin'}, child: DepartmentHubScreen())),
    GoRoute(path: '/departement/identite', builder: (_, _) => const RouteGuard(name: '/departement/identite', roles: {'dept', 'direction', 'admin'}, child: DepartmentIdentityScreen())),
    GoRoute(path: '/departement/etudiants', builder: (_, _) => const RouteGuard(name: '/departement/etudiants', roles: {'dept', 'direction', 'admin'}, child: DepartmentStudentsScreen())),
    GoRoute(path: '/departement/projets', builder: (_, _) => const RouteGuard(name: '/departement/projets', roles: {'dept', 'direction', 'admin'}, child: DepartmentProjectsScreen())),
    GoRoute(path: '/departement/competences', builder: (_, _) => const RouteGuard(name: '/departement/competences', roles: {'dept', 'direction', 'admin'}, child: DepartmentSkillsScreen())),
    GoRoute(path: '/departement/certificats', builder: (_, _) => const RouteGuard(name: '/departement/certificats', roles: {'dept', 'direction', 'admin'}, child: DepartmentCertificatesScreen())),
    GoRoute(path: '/departement/opportunites', builder: (_, _) => const RouteGuard(name: '/departement/opportunites', roles: {'dept', 'direction', 'admin'}, child: DepartmentOpportunitiesScreen())),
    GoRoute(path: '/departement/partenariats', builder: (_, _) => const RouteGuard(name: '/departement/partenariats', roles: {'dept', 'direction', 'admin'}, child: DepartmentPartnershipsScreen())),
    GoRoute(path: '/departement/validations', builder: (_, _) => const RouteGuard(name: '/departement/validations', roles: {'dept', 'direction', 'admin'}, child: DepartmentValidationsScreen())),
    GoRoute(path: '/departement/rapports', builder: (_, _) => const RouteGuard(name: '/departement/rapports', roles: {'dept', 'direction', 'admin'}, child: DepartmentReportsScreen())),
    GoRoute(path: '/departement/rattachements', builder: (_, _) => const RouteGuard(name: '/departement/rattachements', roles: {'admin'}, child: DepartmentAttachScreen())),
    GoRoute(path: '/departement/statistiques', builder: (_, _) => const RouteGuard(name: '/departement/statistiques', roles: {'dept', 'direction', 'admin'}, child: DepartmentStatsScreen())),
    GoRoute(path: '/departement/annonces', builder: (_, _) => const RouteGuard(name: '/departement/annonces', roles: {'dept', 'admin'}, child: DepartmentListingsScreen())),
    GoRoute(path: '/departement/productions', builder: (_, _) => const RouteGuard(name: '/departement/productions', roles: {'dept', 'direction', 'admin'}, child: DepartmentProductionsScreen())),
    GoRoute(path: '/departement/mentors', builder: (_, _) => const RouteGuard(name: '/departement/mentors', roles: {'dept', 'direction', 'admin'}, child: DepartmentMentorsScreen())),
    GoRoute(path: '/communaute/:id', builder: (_, s) => CommunityScreen(id: s.pathParameters['id'] ?? '')),
    GoRoute(path: '/marche', builder: (_, _) => const MarketplaceScreen()),
    GoRoute(path: '/marche/livraison', builder: (_, state) {
      final platform = state.uri.queryParameters['plateforme'] == '1';
      final screen = LivraisonTarifsScreen(platform: platform);
      return platform ? RouteGuard(name: '/marche/livraison?plateforme=1', roles: const {'admin'}, child: screen) : LoginGuard(child: SellerGate(child: RouteGuard(name: '/marche/livraison', roles: const {'student', 'dept', 'admin'}, child: screen)));
    }),
    GoRoute(path: '/marche/promotions', builder: (_, _) => const RouteGuard(name: '/marche/promotions', roles: {'admin'}, child: PromotionsAdminScreen())),
    GoRoute(path: '/concours', builder: (_, _) => const ContestAnnouncementsScreen()),
    GoRoute(path: '/litiges', builder: (_, _) => const DisputesScreen()),
    GoRoute(path: '/entreprise/profil', builder: (_, _) => const CompanyGuard(useContext: true, child: CompanyProfileScreen())),
    GoRoute(path: '/admin/entreprises', builder: (_, _) => const RouteGuard(name: '/admin/entreprises', roles: {'admin'}, child: CompanyReviewScreen())),
    GoRoute(path: '/admin/forfaits', builder: (_, _) => const RouteGuard(name: '/admin/forfaits', roles: {'admin'}, child: CompanyPlansAdminScreen())),
    GoRoute(path: '/admin/sequestre', builder: (_, _) => const RouteGuard(name: '/admin/sequestre', roles: {'admin', 'finance', 'support'}, perms: {'finance.read'}, child: MoneyAdminScreen())),
    GoRoute(path: '/admin/classement', builder: (_, _) => const RouteGuard(name: '/admin/classement', roles: {'admin', 'finance', 'support', 'direction', 'dept'}, perms: kRankingPerms, child: Top100AdminScreen())),
    GoRoute(path: '/etudiant/:id', builder: (_, s) => StudentProfileScreen(userId: s.pathParameters['id'] ?? '')),
    GoRoute(path: '/entreprise/equipe', builder: (_, _) => const CompanyGuard(useContext: true, child: CompanyMembersScreen())),
    GoRoute(path: '/entreprise/vivier', builder: (_, _) => const CompanyGuard(useContext: true, child: TalentPoolOrgScreen())),
  GoRoute(path: '/entreprise/contacts', builder: (_, _) => const CompanyGuard(useContext: true, child: OrgContactRequestsScreen())),
  GoRoute(path: '/entreprise/suivi-missions', builder: (_, _) => const CompanyGuard(useContext: true, child: OrgMissionsTrackingScreen())),
    GoRoute(path: '/discovery', builder: (_, _) => const CompanyGuard(useContext: true, child: TalentDiscoveryScreen())),
    GoRoute(path: '/discovery/favoris', builder: (_, _) => const CompanyGuard(useContext: true, child: TalentFavoritesScreen())),
    GoRoute(path: '/passeport', builder: (_, _) => const LoginGuard(child: Passport360Screen())),
    GoRoute(path: '/passeport/:id', builder: (_, s) => LoginGuard(child: Passport360Screen(userId: s.pathParameters['id'] ?? ''))),
    GoRoute(path: '/mes-entreprises', builder: (_, _) => const LoginGuard(child: MyCompaniesScreen())),
    GoRoute(path: '/entreprise/espace/:owner', builder: (_, s) => CompanyGuard(owner: s.pathParameters['owner'] ?? '', child: CompanySpaceScreen(owner: s.pathParameters['owner'] ?? ''))),
    GoRoute(path: '/verifier', builder: (_, s) => VerifyPublicScreen(code: s.uri.queryParameters['qr'] ?? s.uri.queryParameters['code'] ?? '')),
    GoRoute(path: '/verifier/passeport/:token', builder: (_, s) => VerifyPublicScreen(kind: VerifyKind.passeport, code: s.pathParameters['token'] ?? '')),
    GoRoute(path: '/verifier/projet/:id', builder: (_, s) => VerifyPublicScreen(kind: VerifyKind.projet, code: s.pathParameters['id'] ?? '')),
    GoRoute(path: '/verifier/:code', builder: (_, s) => VerifyPublicScreen(code: s.pathParameters['code'] ?? '')),
    GoRoute(path: '/entreprise/fiche/:owner', builder: (_, s) => CompanyPublicPage(ownerId: s.pathParameters['owner'] ?? '')),
    GoRoute(path: '/entreprise/achats', builder: (_, _) => const CompanyGuard(useContext: true, child: CompanyPurchasesScreen())),
    GoRoute(path: '/entreprise/partenariats', builder: (_, _) => const CompanyGuard(useContext: true, child: OrgPartnershipsScreen())),
    GoRoute(path: '/comptes-test', builder: (_, _) => const RouteGuard(name: '/comptes-test', roles: {'admin'}, child: TestAccountsScreen())),
    GoRoute(path: '/equipe/:key', builder: (_, s) => StaffPortalScreen(portalKey: s.pathParameters['key'] ?? '')),
    GoRoute(path: '/concours/publier', builder: (_, _) => const AnnouncementEditScreen()),
    GoRoute(path: '/concours/mes', builder: (_, _) => const LoginGuard(child: MyAnnouncementsScreen())),
    GoRoute(path: '/concours/:id', builder: (_, state) => AnnouncementDetailScreen(id: state.pathParameters['id'] ?? '')),
    GoRoute(path: '/opportunites', builder: (_, _) => const OpportunitiesScreen()),
    GoRoute(path: '/opportunites/publier', builder: (_, _) => const OpportunityEditScreen()),
    GoRoute(path: '/opportunites/mes', builder: (_, _) => const LoginGuard(child: MyOpportunitiesScreen())),
    GoRoute(path: '/opportunites/:id', builder: (_, state) => OpportunityDetailScreen(id: state.pathParameters['id'] ?? '')),
    GoRoute(path: '/opportunites/:id/candidatures', builder: (_, state) => OpportunityApplicationsScreen(id: state.pathParameters['id'] ?? '')),
    GoRoute(path: '/innovations', builder: (_, _) => const InnovationsScreen()),
    GoRoute(path: '/innovations/points', builder: (_, _) => const PointsScreen()),
    GoRoute(path: '/innovations/sos', builder: (_, _) => const SosScreen()),
    GoRoute(path: '/innovations/defis', builder: (_, _) => const ChallengesScreen()),
    GoRoute(path: '/innovations/competences', builder: (_, _) => const SkillsScreen()),
    GoRoute(path: '/innovations/victoires', builder: (_, _) => const VictoriesScreen()),
    GoRoute(path: '/mentors', builder: (_, _) => const MentorsScreen()),
    GoRoute(path: '/mentors/profil', builder: (_, _) => const LoginGuard(child: MentorProfileScreen())),
    GoRoute(path: '/mentors/demandes', builder: (_, _) => const LoginGuard(child: MentorRequestsScreen())),
    GoRoute(path: '/mentors/:id', builder: (_, state) => MentorDetailScreen(id: state.pathParameters['id'] ?? '')),
    GoRoute(path: '/communautes', builder: (_, _) => const CommunityExploreScreen()),
    GoRoute(path: '/accompagnement', builder: (_, _) => const RouteGuard(name: '/accompagnement', roles: {'student', 'dept', 'admin'}, child: SupportRequestsScreen())),
    GoRoute(path: '/evaluations', builder: (_, _) => const RouteGuard(name: '/evaluations', roles: {'student', 'client'}, child: AssessmentsScreen())),
    GoRoute(path: '/admin/evaluations', builder: (_, _) => const RouteGuard(name: '/admin/evaluations', roles: {'admin', 'support', 'finance'}, perms: {'tech.integrations'}, child: AssessmentProvidersAdminScreen())),
    GoRoute(path: '/admin/evaluations/validation', builder: (_, _) => const RouteGuard(name: '/admin/evaluations/validation', roles: {'admin', 'support', 'finance'}, perms: {'tech.assessments'}, child: AssessmentReviewScreen())),
    GoRoute(path: '/entreprise/evaluations', builder: (_, _) => const CompanyGuard(useContext: true, child: AssessmentCampaignsOrgScreen())),
    GoRoute(path: '/evenements/mes', builder: (_, _) => const LoginGuard(child: MyEventsScreen())),
    GoRoute(path: '/evenements/gerer', builder: (_, _) => const RouteGuard(name: '/evenements/gerer', roles: {'dept', 'direction', 'finance', 'admin'}, perms: {'finance.read'}, child: EventsManageScreen())),
    GoRoute(path: '/marche/appels', builder: (_, _) => const AppelsScreen()),
    GoRoute(path: '/marche/projets', builder: (_, _) => const ProjetsIutScreen()),
    GoRoute(path: '/marche/boutique/:slug', builder: (_, state) => ShopPageScreen(slug: state.pathParameters['slug'] ?? '')),
    GoRoute(path: '/marche/ventes-flash', builder: (_, _) => const FlashSalesScreen()),
    GoRoute(path: '/marche/produit/:id', builder: (_, state) => ProductPageScreen(id: state.pathParameters['id'] ?? '')),
    GoRoute(path: '/marche/comparer', builder: (_, _) => const CompareScreen()),
    GoRoute(path: '/marche/suivies', builder: (_, _) => const LoginGuard(child: FollowedShopsScreen())),
    GoRoute(path: '/marche/panier', builder: (_, _) => const CartByShopScreen()),
    GoRoute(path: '/marche/ma-boutique', builder: (_, state) {
      final id = state.uri.queryParameters['id'];
      final editor = ShopEditorScreen(shopId: id, create: state.uri.queryParameters['nouvelle'] == '1');
      // une boutique précise (propriétaire ou gestionnaire d'équipe) : les droits sont vérifiés par le serveur ; sinon, parcours vendeur habituel
      if (id != null) return LoginGuard(child: RouteGuard(name: '/marche/ma-boutique', roles: const {'student', 'client', 'dept', 'admin'}, child: editor));
      return LoginGuard(child: SellerGate(child: RouteGuard(name: '/marche/ma-boutique', roles: const {'student', 'dept', 'admin'}, child: editor)));
    }),
    GoRoute(path: '/marche/mes-boutiques', builder: (_, _) => const LoginGuard(child: MyShopsScreen())),
    GoRoute(path: '/marche/mes-boutiques/:id/equipe', builder: (_, state) => LoginGuard(child: ShopMembersScreen(shopId: state.pathParameters['id'] ?? ''))),
    GoRoute(path: '/marche/mes-boutiques/:id/espace', builder: (_, state) => LoginGuard(child: ShopMemberSpaceScreen(shopId: state.pathParameters['id'] ?? ''))),
    GoRoute(path: '/marche/vendeur', builder: (_, _) => const LoginGuard(child: SellerGate(child: RouteGuard(name: '/marche/vendeur', roles: {'student', 'dept', 'admin'}, child: SellerHubScreen())))),
    GoRoute(path: '/marche/moderation', builder: (_, _) => const RouteGuard(name: '/marche/moderation', roles: {'admin', 'dept', 'support', 'finance'}, perms: {'security.moderation', 'security.reports'}, child: ModerationScreen())),
    GoRoute(path: '/moderation/reseau', builder: (_, _) => const RouteGuard(name: '/moderation/reseau', roles: {'admin', 'dept', 'support', 'finance'}, perms: {'security.moderation', 'security.reports'}, child: SocialModerationScreen())),
    GoRoute(path: '/paiement', builder: (_, _) => const LoginGuard(child: PaymentChatScreen())),
    GoRoute(path: '/paiements', builder: (_, _) => const LoginGuard(child: MyPaymentsScreen())),
    GoRoute(path: '/marche/telechargements', builder: (_, _) => const LoginGuard(child: DownloadsScreen())),
  GoRoute(path: '/commandes/suivi', builder: (_, _) => const LoginGuard(child: OrderTrackingListScreen())),
  GoRoute(path: '/commandes/suivi/:number', builder: (_, s) => LoginGuard(child: OrderTrackingScreen(number: s.pathParameters['number'] ?? ''))),
    GoRoute(path: '/createur/statistiques', builder: (_, _) => const LoginGuard(child: CreatorAnalyticsScreen())),
    GoRoute(path: '/profil-createur/:id', builder: (_, s) => CreatorProfileScreen(userId: s.pathParameters['id'] ?? '')),
    GoRoute(path: '/abonnes/:id', builder: (_, s) => FollowListScreen(userId: s.pathParameters['id'] ?? '', kind: FollowListKind.followers)),
    GoRoute(path: '/abonnements/:id', builder: (_, s) => FollowListScreen(userId: s.pathParameters['id'] ?? '', kind: FollowListKind.following)),
    GoRoute(path: '/createurs-a-suivre', builder: (_, _) => const SuggestedCreatorsScreen()),
    GoRoute(path: '/replays', builder: (_, _) => const ReplaysScreen()),
    GoRoute(path: '/atelier', builder: (_, state) => AtelierScreen(initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0)),
    GoRoute(path: '/atelier/preparer', builder: (_, state) => LoginGuard(child: LivePrepareScreen(liveId: state.uri.queryParameters['live'], startNow: state.uri.queryParameters['mode'] == 'now'))),
    GoRoute(path: '/replay/:id/quiz', builder: (_, state) => LoginGuard(child: ReplayQuizEditorScreen(recordingId: state.pathParameters['id'] ?? ''))),
    GoRoute(path: '/replay/:id', builder: (_, state) => ReplayPlayerScreen(id: state.pathParameters['id'] ?? '', startAt: double.tryParse(state.uri.queryParameters['t'] ?? '') ?? 0)),
    GoRoute(path: '/mes-replays', builder: (_, _) => const LoginGuard(child: MyReplaysScreen())),
    GoRoute(path: '/top100', builder: (_, _) => const Top100HubScreen()),
    GoRoute(path: '/top100/national', builder: (_, state) => Top100ListScreen(kind: 'national', initialPeriod: state.uri.queryParameters['periode'] ?? '')),
    GoRoute(path: '/top100/etablissement', builder: (_, _) => const Top100ListScreen(kind: 'institution')),
    GoRoute(path: '/top100/filiere', builder: (_, _) => const Top100ListScreen(kind: 'program')),
    GoRoute(path: '/top100/progression', builder: (_, _) => const Top100ListScreen(kind: 'rising')),
    GoRoute(path: '/top100/nouveaux', builder: (_, _) => const Top100ListScreen(kind: 'new')),
    GoRoute(path: '/top100/etablissements', builder: (_, _) => const Top100InstitutionsScreen()),
    GoRoute(path: '/top100/plus-consultes', builder: (_, _) => const Top100MostViewedScreen()),
    GoRoute(path: '/top100/historique', builder: (_, _) => const Top100HistoryScreen()),
    GoRoute(path: '/top100/regles', builder: (_, _) => const Top100RulesScreen()),
  GoRoute(path: '/top100/calcul', builder: (_, state) => RankingExplainScreen(period: state.uri.queryParameters['periode'] ?? '')),
    GoRoute(path: '/top100/verification', builder: (_, state) => Top100VerifyScreen(initialPeriod: state.uri.queryParameters['periode'] ?? '')),
    GoRoute(path: '/top100/talent/:id', builder: (_, state) => TalentPublicProfileScreen(userId: state.pathParameters['id'] ?? '')),
    GoRoute(path: '/top100/mon-score', builder: (_, _) => const LoginGuard(child: MyTalentScreen())),
    GoRoute(path: '/top100/mon-score/coherence', builder: (_, _) => const LoginGuard(child: MyTalentConsistencyScreen())),
  GoRoute(path: '/top100/mon-score/points', builder: (_, _) => const LoginGuard(child: MyTalentExplainScreen())),
    GoRoute(path: '/top100/mon-score/positions', builder: (_, _) => const LoginGuard(child: MyRankingPositionsScreen())),
    GoRoute(path: '/top100/mon-score/visibilite', builder: (_, _) => const LoginGuard(child: MyTop100VisibilityScreen())),
    GoRoute(path: '/top100/mon-score/rattachement', builder: (_, _) => const LoginGuard(child: MyAffiliationScreen())),
    GoRoute(path: '/top100/mon-score/activites', builder: (_, _) => const LoginGuard(child: MyTalentEventsScreen())),
    GoRoute(path: '/top100/mon-score/contacts', builder: (_, _) => const LoginGuard(child: MyTalentContactsScreen())),
    GoRoute(path: '/aide/contact', builder: (_, _) => const LoginGuard(child: SupportContactScreen())),
    GoRoute(path: '/aide/demandes', builder: (_, _) => const LoginGuard(child: MyTicketsScreen())),
    GoRoute(path: '/support/boite', builder: (_, _) => const RouteGuard(name: '/support/boite', roles: {'admin', 'support', 'finance'}, perms: {'support.tickets'}, child: SupportInboxScreen())),
    GoRoute(path: '/notif', builder: (_, state) => NotificationLauncher(id: state.uri.queryParameters['n'] ?? '')),
    GoRoute(path: '/integrations/api', builder: (_, _) => const RouteGuard(name: '/integrations/api', roles: {'admin', 'support', 'finance'}, perms: {'tech.integrations'}, child: G_280())),
    GoRoute(path: '/design', builder: (_, _) => const RouteGuard(name: '/design', roles: {'admin'}, debugOpen: true, child: DesignLabScreen())),
    GoRoute(path: '/invitation/:token', builder: (_, state) => DeptInviteScreen(token: state.pathParameters['token'] ?? '')),
    GoRoute(path: '/cv/:token', builder: (_, state) => SharedCvScreen(token: state.pathParameters['token'] ?? '')),
    GoRoute(
      path: '/s/:id',
      redirect: (context, state) async {
        // Ancien lien de partage de profil (« /s/10?user=<id> ») : il ouvre le profil de cette personne, pas celui du visiteur.
        final shared = (state.uri.queryParameters['user'] ?? '').trim();
        if (state.pathParameters['id'] == '10' && shared.isNotEmpty) return '/etudiant/${Uri.encodeComponent(shared)}';
        // Lien partagé d'un produit (« /s/05?product=Titre ») : le routeur ouvre la fiche réelle de l'annonce.
        final product = (state.uri.queryParameters['product'] ?? '').trim();
        if (product.isEmpty || !Backend.ready || !const {'05', '32', '33', '34', '35'}.contains(state.pathParameters['id'])) return null;
        final id = await listingIdByTitle(product);
        return id == null ? null : '/marche/produit/$id';
      },
      pageBuilder: (context, state) {
        final entry = screenById(state.pathParameters['id']);
        final sid = entry?.id ?? state.pathParameters['id'] ?? '?';
        final guarded = entry == null ? MissingScreen(id: sid) : AccessGuard(id: sid, child: deptLiveScreen(sid, entry.builder(context)));
        final child = (sid == '11' || sid == '12') ? SignedInRedirect(child: guarded) : guarded;
        // S1 « Démarrage animé » : écran de lancement, puis passage automatique à l'accueil (01).
        final page = sid == 'S1' ? SplashAdvance(child: child) : child;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: page,
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          transitionsBuilder: (context, animation, secondary, child) {
            final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: a,
              child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child),
            );
          },
        );
      },
    ),
  ],
  errorBuilder: (_, state) => MissingScreen(id: state.uri.toString()),
);

/// Écran de démarrage (S1) : laisse voir le logo, puis remplace l'écran par l'accueil (01). Sans animation (tests, rendus de
/// référence), aucun minuteur n'est lancé ; avec « réduire les animations », le passage est plus rapide.
class SplashAdvance extends StatefulWidget {
  const SplashAdvance({super.key, required this.child, this.next = '01'});
  final Widget child;
  final String next;

  static const delay = Duration(milliseconds: 2200);

  @override
  State<SplashAdvance> createState() => _SplashAdvanceState();
}

class _SplashAdvanceState extends State<SplashAdvance> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (!GAnim.enabled) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final quick = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      _t = Timer(quick ? const Duration(milliseconds: 300) : SplashAdvance.delay, () {
        if (mounted) GoRouter.of(context).go(screenPath(widget.next));
      });
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Affiché pour un numéro d'écran absent du registre.
class MissingScreen extends StatelessWidget {
  const MissingScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      header: const ScreenHeader(title: 'Écran introuvable'),
      children: [
        const SizedBox(height: 40),
        Text('L’écran « $id » n’existe pas.', style: AppText.h2, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Retour à l’accueil', onPressed: () => context.go(screenPath(NavTargets.home))),
      ],
    );
  }
}

/// Catalogue de tous les écrans codés (revue de maquette).
class ScreenCatalogue extends StatelessWidget {
  const ScreenCatalogue({super.key});

  @override
  Widget build(BuildContext context) {
    final bySection = <String, List<ScreenEntry>>{};
    for (final s in allScreens) {
      bySection.putIfAbsent(s.section, () => []).add(s);
    }
    return AppScaffold(
      showNav: false,
      header: const ScreenHeader(title: 'Catalogue des écrans', showBack: false),
      children: [
        for (final e in bySection.entries) ...[
          const SizedBox(height: 16),
          Text('Section ${e.key}', style: AppText.h3),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                for (final s in e.value)
                  ListRow(
                    title: '${s.id} · ${s.title}',
                    subtitle: '${s.format.name} · Figma ${s.node}',
                    onTap: () => context.push(screenPath(s.id)),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text('Données de démonstration', style: AppText.small.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
