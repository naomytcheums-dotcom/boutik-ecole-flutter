import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import 'audit.dart';
import 'auth.dart';
import 'backend.dart';
import 'admin_access.dart';
import 'seller_capability.dart' show SellerGate, isSellerScreenId;
/// Contrôle d'accès par rôle : chaque écran réservé n'est visible que pour les rôles autorisés.
///
/// Rôles : visitor (non connecté), client, student, company (Organisation, ex-Entreprise ; le rôle serveur « other » y est fusionné), dept, direction, finance, support, admin.
String roleKey(Account? a) {
  if (a == null) return 'visitor';
  switch (a.staff) {
    case 'Resp. département':
      return 'dept';
    case 'Direction':
      return 'direction';
    case 'Finance':
      return 'finance';
    case 'Support':
      return 'support';
    case 'Admin global':
      return 'admin';
  }
  return const ['client', 'student', 'company', 'client'][a.role.clamp(0, 3)];
}

/// Compte Organisation (hors personnel de la plateforme) : écrans et menus des organisations (décision 2).
bool isCompanyAccount(Account? a) => a != null && a.staff.isEmpty && a.role == 2;

/// Rôle serveur d'une organisation : « company », ou l'ancien « other » encore lu sur des profils hérités (fusionné dans Organisation).
bool isOrgRole(String? r) => r == 'company' || r == 'other';

const roleNames = {
  'visitor': 'Non connecté',
  'client': 'Client',
  'student': 'Étudiant-vendeur',
  'company': 'Organisation',
  'other': 'Organisation',
  'dept': 'Responsable de département',
  'direction': 'Direction',
  'finance': 'Équipe Finance',
  'support': 'Équipe Support',
  'admin': 'Administrateur global',
};

/// Rôles autorisés pour un écran ; null = ouvert à tous.
Set<String>? allowedRoles(String id) {
  const admin = 'admin';
  // Tableau de bord du studio : étudiants-vendeurs ; département et administration peuvent le consulter.
  if (id == 'D1') return {'student', 'dept', admin};
  final n = int.tryParse(RegExp(r'^\d+').firstMatch(id)?.group(0) ?? '');
  if (n == null) return null;
  // Demande de devis : tout compte connecté peut en adresser une à un prestataire (pas seulement les organisations).
  if (id == '95b') return {'client', 'student', 'company', 'dept', admin};
  if (n >= 57 && n <= 69) return {'student', admin}; // espace vendeur : étudiants-vendeurs ; l'administrateur peut le consulter (la création de boutique reste refusée aux autres rôles par le serveur)
  if ((n >= 88 && n <= 99) || (n >= 187 && n <= 190)) return {'company', admin}; // décision 2 : l'organisation (ex-entreprise, rôle other fusionné) a ces écrans ; le serveur applique la même porte de vérification
  // Écrans du département : la direction n'en garde que la lecture (suivi) ; les validations (110, 111) et les encadreurs (114) restent au département (le serveur les refuse à la direction).
  if (n == 110 || n == 111 || n == 114) return {'dept', admin};
  if (n >= 108 && n <= 116) return {'dept', 'direction', admin};
  if (n >= 117 && n <= 126) return {'direction', admin};
  if (n >= 127 && n <= 138) {
    // 127 à 129 : administrateur seul. 130 à 138 : outils des équipes internes, ouverts aux agents (rôles finance et support) selon leurs permissions (kScreenPermissions).
    if (n >= 130) return {'finance', 'support', admin};
    return {admin};
  }
  // Finance : la direction ne garde que la lecture consolidée (tableau de bord 139 et rapports par département 142) ; paiements, journal, versements et moyens de paiement sont à la finance.
  if (n == 139 || n == 142) return {'finance', 'support', 'direction', admin};
  if (n >= 139 && n <= 144) return {'finance', 'support', admin};
  if (n >= 145 && n <= 147) return {'support', 'finance', admin};
  if (n == 167 || n == 168 || n == 169) return {'dept', admin};
  if (n >= 198 && n <= 200) return {'dept', admin};
  // Formulaire de projet : le serveur (project_save_full) refuse tout autre rôle ; mieux vaut ne pas l'ouvrir que le refuser à l'envoi.
  if (n == 205) return {'student', 'dept', admin};
  if (n == 213) return {'dept', admin};
  if (n == 239) return {'direction', 'dept', admin};
  switch (n) {
    case 262:
    case 285:
      return {'company', admin};
    case 263:
    case 286:
    case 287:
    case 288:
    case 283:
      return {'dept', admin};
    case 264:
    case 265:
    case 266:
    case 267:
    case 280: // configuration, état technique et intégrations : équipe Technique (selon permissions) et administrateur
      return {'support', 'finance', admin};
    case 269:
    case 281:
    case 180:
    case 181:
      return {admin};
    case 268:
    case 277:
    case 282: // QR de transfert / programmation des événements de borne : équipes Support et Technique (la page se garde aussi elle-même)
      return {'support', 'finance', admin};
    case 284:
      return {'finance', 'support', 'direction', admin};
    case 300: // centre d'administration et tableaux de bord des équipes (301 à 304), gestion des équipes (305), comptes suspects (306)
    case 301:
    case 302:
    case 303:
    case 304:
    case 306:
      return {'finance', 'support', admin};
    case 305:
      return {admin};
  }
  return null;
}

bool canOpen(Account? a, String id) {
  final r = allowedRoles(id);
  return r == null || r.contains(roleKey(a));
}

/// Concours dont le compte connecté est juré (désigné par le département, quel que soit son rôle) : c'est ce qui ouvre l'écran de notation 167
/// à un juré qui n'est ni département ni administrateur (le serveur reste l'autorité : score_contest_submission exige is_contest_juror).
final jurorContestsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
  if (!Backend.ready || uid.isEmpty) return const [];
  final r = await Backend.rpc('my_juror_contests', const {});
  if (r.error != null) return const [];
  return [for (final x in (r.data is List ? r.data as List : const []) ) if (x is Map) Map<String, dynamic>.from(x)];
});

/// Écrans qu'un Client peut atteindre par une adresse directe (le serveur reste l'autorité) mais que « Mes rubriques » ne lui propose pas :
/// outils d'étudiant-vendeur, de prestataire, de jury et d'équipe, bornes, discussions de mission et maquettes de référence.
const _hiddenInEspaceForClient = {
  '73', '75', '82', '84', '87', '164', '178', '197', '218', '224', '227', '233', '234', '235',
  '206', '207', '208', '209', '210', '276',
  'A1', 'A2', 'A3', 'P1', 'P2', 'P4', 'P5', 'V1', 'L1', '250b', 'S1',
};

/// Écrans qu'une organisation peut atteindre par une adresse directe mais que « Mes rubriques » ne lui propose pas (E6-9) :
/// ceux du Client, plus les outils d'étudiant (compte étudiant, matricule, candidatures et profil vendeur).
const _hiddenInEspaceForCompany = {
  ..._hiddenInEspaceForClient,
  '154', '18c', '72', '74', '76',
};

/// Écrans pas encore disponibles en production (jumeau 3D, réalité augmentée) : ils restent joignables par leur adresse, qui affiche l'état réel,
/// mais « Mes rubriques » ne les propose pas comme s'ils fonctionnaient.
const _notYetAvailable = {'225', '226'};

/// Écran proposé dans « Mes rubriques » : ouvert au rôle, et pertinent pour lui. [juror] : le compte est juré d'un concours (écran de notation 167).
bool listedInEspace(Account? a, String id, {bool juror = false, AdminAccess? access}) =>
    !(Backend.ready && _notYetAvailable.contains(id)) &&
    (canOpen(a, id) || (juror && a != null && id == '167')) &&
    screenAllowedByAccess(a, id, access) &&
    !((roleKey(a) == 'client' && _hiddenInEspaceForClient.contains(id) || isCompanyAccount(a) && _hiddenInEspaceForCompany.contains(id)) && !(juror && id == '167'));

/// Écrans du parcours personnel (commandes, suivi, adresses, favoris, avis, messages, notifications, paramètres du compte) : réservés aux comptes connectés.
/// Une personne non connectée y voit « Connexion requise » avec « Se connecter » (le retour à l'écran d'origine est automatique) ; le serveur refuse de toute façon
/// ces lectures et écritures à l'anonyme. Hors connexion au serveur (aperçu, tests), les écrans restent ouverts.
const loginRequiredScreens = {
  '07', '08', '09', '18b', '18c', '25', '25b', '27', '28', '29', '30', '41', '42', '43', '44', '45', '46', '47', '48', '50', '51', '52', '53', '54',
  '148-1', '148-2', '155', '156', '236', '241', '243', '257', '258', '259', '260', '261', '272', '273',
};

/// Écrans du personnel de la plateforme (département, direction, équipes internes, administrateur) : ceux dont la maquette, hors connexion au serveur, montre des données
/// et des droits FICTIFS. Les écrans partagés avec les étudiants, clients ou organisations (espace vendeur, D1, 205…) n'en font pas partie.
bool isStaffScreenId(String id) {
  final r = allowedRoles(id);
  return r != null && r.every(const {'dept', 'direction', 'finance', 'support', 'admin'}.contains);
}

/// Clé du bandeau « Aperçu de démonstration » (tests).
const demoPreviewBannerKey = ValueKey('demo-preview-banner');

/// Hors connexion au serveur, un écran du personnel est un APERÇU : données, compteurs et permissions affichés sont ceux de la maquette, jamais ceux du compte.
/// Le bandeau le dit en toutes lettres au-dessus de l'écran (connecté, il n'apparaît jamais).
///
/// Superposé (comme [TestAccountBanner]), jamais inséré dans une colonne : un écran du personnel se dessine à partir de coordonnées de maquette exactes (console
/// web 1272 px) et réduire sa hauteur disponible le ferait réduire à l'échelle entière par `GScreen` (texte, zones tactiles et boutons décalés de leur place
/// réelle — « Actualiser », « Exporter »… devenaient injoignables). Le bandeau reste fin et placé tout en haut, au-dessus du logo (jamais d'un bouton).
class DemoPreview extends StatelessWidget {
  const DemoPreview({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(children: [
        child,
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: IgnorePointer(
              child: Material(
            key: demoPreviewBannerKey,
            color: const Color(0xFFFFF3C4),
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 28),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: const Text(
                  'Aperçu de démonstration : données et droits fictifs, sans lien avec votre compte',
                  textAlign: TextAlign.center,
                  style: TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF7A4B00), textBaseline: TextBaseline.alphabetic),
                ),
              ),
            ),
          )),
        ),
      ]);
}

/// Enveloppe d'un écran : affiche l'écran si le rôle l'autorise, sinon « Accès réservé ». Les écrans vendeur (57 à 69) exigent en plus la capacité vendeur
/// (sinon : écran des conditions) et ceux du parcours personnel ([loginRequiredScreens]) un compte connecté.
class AccessGuard extends ConsumerWidget {
  const AccessGuard({super.key, required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider).current;
    if (Backend.ready && isSellerScreenId(id)) return SellerGate(child: child);
    if (loginRequiredScreens.contains(id)) return LoginGuard(child: _roleChecked(ref, account));
    return _roleChecked(ref, account);
  }

  Widget _roleChecked(WidgetRef ref, Account? account) {
    if (canOpen(account, id)) {
      final need = kScreenPermissions[id.replaceAll('_', '-')];
      final shown = need == null ? child : PermissionGate(name: id, perms: need, child: child);
      return !Backend.ready && isStaffScreenId(id) ? DemoPreview(child: shown) : shown;
    }
    if (id == '167' && account != null && Backend.ready) {
      return ref.watch(jurorContestsProvider).when(
            loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
            error: (_, _) => AccessDenied(id: id),
            data: (l) => l.isEmpty ? AccessDenied(id: id) : child,
          );
    }
    return AccessDenied(id: id);
  }
}

/// Garde d'une route qui n'est pas dans le registre des écrans (outils internes, consoles de gestion) : seuls les [roles] voient
/// l'écran ; les autres reçoivent la même page neutre que [AccessGuard]. [debugOpen] l'ouvre aussi en mode debug (outils de revue).
/// La vraie protection reste côté serveur : cette garde évite seulement d'exposer une interface qui ne peut rien faire.
class RouteGuard extends ConsumerWidget {
  const RouteGuard({super.key, required this.name, required this.roles, required this.child, this.debugOpen = false, this.perms});
  final String name;
  final Set<String> roles;
  final bool debugOpen;

  /// Permissions d'équipe : un agent finance ou support n'ouvre l'écran que s'il détient l'une d'elles (null = pas de condition).
  final Set<String>? perms;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (debugOpen && kDebugMode) return child;
    final account = ref.watch(authProvider.select((s) => s.current));
    if (roles.contains(roleKey(account))) return perms == null ? child : PermissionGate(name: name, perms: perms!, child: child);
    return AccessDenied(id: name);
  }
}

/// Réserve un écran aux agents finance et support qui détiennent l'une des permissions [perms] (lues sur le serveur par `my_admin_access`) ;
/// l'administrateur et les autres rôles ne sont pas concernés. Pendant la lecture, un indicateur ; en cas d'échec, un message avec « Réessayer ».
class PermissionGate extends ConsumerWidget {
  const PermissionGate({super.key, required this.name, required this.perms, required this.child});
  final String name;
  final Set<String> perms;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authProvider.select((s) => s.current));
    if (!isTeamAgent(account)) return child;
    return ref.watch(adminAccessProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (_, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Vos droits d’équipe n’ont pas pu être vérifiés.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => ref.invalidate(adminAccessProvider), child: const Text('Réessayer')),
                ]),
              ),
            ),
          ),
          data: (a) => a.hasAny(perms) ? child : AccessDenied(id: name),
        );
  }
}

/// Garde d'une route réservée aux comptes connectés : un visiteur voit « Connexion requise » avec un bouton « Se connecter ».
/// Hors connexion au serveur (aperçu, tests), l'écran reste ouvert comme pour [requireLogin].
class LoginGuard extends ConsumerWidget {
  const LoginGuard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authProvider.select((s) => s.current != null));
    if (!Backend.ready || signedIn) return child;
    const f = 'PlusJakartaSans';
    TextStyle st(double s, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: f, fontSize: s, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_outline_rounded, size: 52, color: Color(0xFF111015)),
                const SizedBox(height: 14),
                Text('Connexion requise', style: st(22, FontWeight.w700, const Color(0xFF111015))),
                const SizedBox(height: 10),
                Text('Connectez-vous avec votre compte pour accéder à cette page.', textAlign: TextAlign.center, style: st(13.5, FontWeight.w400, const Color(0xFF4A4854)).copyWith(height: 1.55)),
                const SizedBox(height: 26),
                GestureDetector(
                  onTap: () => requireLogin(context, ref, 'accéder à cette page'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF111015), borderRadius: BorderRadius.circular(28)),
                    child: Text('Se connecter', style: st(13.5, FontWeight.w600, Colors.white)),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => context.go(screenPath('03')),
                  child: Padding(padding: const EdgeInsets.all(8), child: Text('Retour à l’accueil', style: st(13, FontWeight.w600, const Color(0xFF4A4854)))),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class AccessDenied extends ConsumerStatefulWidget {
  const AccessDenied({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AccessDenied> createState() => _AccessDeniedState();
}

class _AccessDeniedState extends ConsumerState<AccessDenied> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final a = ref.read(authProvider).current;
      ref.read(auditProvider.notifier).log(a?.name ?? 'Non connecté', 'Accès refusé', 'Écran ${widget.id}', 'Connexions', level: 'Sensible');
    });
  }

  @override
  Widget build(BuildContext context) => const NotFoundView();
}

/// Page 404 neutre, sans journalisation : ne révèle ni l'existence de l'écran ni les rôles qui y ont accès.
class NotFoundView extends StatelessWidget {
  const NotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    const f = 'PlusJakartaSans';
    TextStyle st(double s, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: f, fontSize: s, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('404', style: st(76, FontWeight.w800, const Color(0xFF111015))),
                const SizedBox(height: 6),
                Text('Page introuvable', style: st(22, FontWeight.w700, const Color(0xFF111015))),
                const SizedBox(height: 10),
                Text('Cette page n’existe pas ou n’est plus disponible.', textAlign: TextAlign.center, style: st(13.5, FontWeight.w400, const Color(0xFF4A4854)).copyWith(height: 1.55)),
                const SizedBox(height: 26),
                GestureDetector(
                  onTap: () => context.go(screenPath('03')),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    decoration: BoxDecoration(color: const Color(0xFF111015), borderRadius: BorderRadius.circular(28)),
                    child: Text('Retour à l’accueil', style: st(13.5, FontWeight.w600, Colors.white)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
