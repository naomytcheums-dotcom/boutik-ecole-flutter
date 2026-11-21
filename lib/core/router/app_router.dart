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
import '../../figma/live/company_purchases.dart' show CompanyPurchasesScreen;
import '../../figma/live/org_partnerships.dart' show OrgPartnershipsScreen;
import '../../figma/live/student_profile.dart';
import '../../figma/live/litiges_screens.dart';
import '../../figma/live/money_admin.dart';
import '../../figma/live/staff_portal.dart';
import '../../figma/live/test_accounts.dart';
import '../../figma/live/innovations_screens.dart';
import '../../figma/live/marche/marche_appels.dart';
import '../../figma/live/opportunites_screens.dart';
import '../../figma/live/menu_global.dart' show MenuModalObserver;
import '../../figma/live/mentors_screens.dart';
import '../../figma/live/marche/marche_compare.dart';
import '../../figma/live/marche/marche_livraison.dart';
import '../../figma/live/marche/marche_promotions.dart';
import '../../figma/live/marche/marche_screens.dart';
import '../../figma/live/marche/marche_vendeur.dart';
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
    GoRoute(path: '/communaute', builder: (_, _) => const CommunityScreen()),
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
    GoRoute(path: '/etudiant/:id', builder: (_, s) => StudentProfileScreen(userId: s.pathParameters['id'] ?? '')),
    GoRoute(path: '/entreprise/equipe', builder: (_, _) => const CompanyGuard(useContext: true, child: CompanyMembersScreen())),
    GoRoute(path: '/mes-entreprises', builder: (_, _) => const LoginGuard(child: MyCompaniesScreen())),
    GoRoute(path: '/entreprise/espace/:owner', builder: (_, s) => CompanyGuard(owner: s.pathParameters['owner'] ?? '', child: CompanySpaceScreen(owner: s.pathParameters['owner'] ?? ''))),
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
    GoRoute(path: '/marche/ma-boutique', builder: (_, _) => const LoginGuard(child: SellerGate(child: RouteGuard(name: '/marche/ma-boutique', roles: {'student', 'dept', 'admin'}, child: ShopEditorScreen())))),
    GoRoute(path: '/marche/vendeur', builder: (_, _) => const LoginGuard(child: SellerGate(child: RouteGuard(name: '/marche/vendeur', roles: {'student', 'dept', 'admin'}, child: SellerHubScreen())))),
    GoRoute(path: '/marche/moderation', builder: (_, _) => const RouteGuard(name: '/marche/moderation', roles: {'admin', 'dept', 'support', 'finance'}, perms: {'security.moderation', 'security.reports'}, child: ModerationScreen())),
    GoRoute(path: '/moderation/reseau', builder: (_, _) => const RouteGuard(name: '/moderation/reseau', roles: {'admin', 'dept', 'support', 'finance'}, perms: {'security.moderation', 'security.reports'}, child: SocialModerationScreen())),
    GoRoute(path: '/paiement', builder: (_, _) => const LoginGuard(child: PaymentChatScreen())),
    GoRoute(path: '/paiements', builder: (_, _) => const LoginGuard(child: MyPaymentsScreen())),
    GoRoute(path: '/aide/contact', builder: (_, _) => const LoginGuard(child: SupportContactScreen())),
    GoRoute(path: '/aide/demandes', builder: (_, _) => const LoginGuard(child: MyTicketsScreen())),
    GoRoute(path: '/support/boite', builder: (_, _) => const RouteGuard(name: '/support/boite', roles: {'admin', 'support', 'finance'}, perms: {'support.tickets'}, child: SupportInboxScreen())),
    GoRoute(path: '/notif', builder: (_, state) => NotificationLauncher(id: state.uri.queryParameters['n'] ?? '')),
    GoRoute(path: '/integrations/api', builder: (_, _) => const RouteGuard(name: '/integrations/api', roles: {'admin', 'support', 'finance'}, perms: {'tech.integrations'}, child: G_280())),
    GoRoute(path: '/design', builder: (_, _) => const RouteGuard(name: '/design', roles: {'admin'}, debugOpen: true, child: DesignLabScreen())),
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
