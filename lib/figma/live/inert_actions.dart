import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import 'admin.dart' show serverAccountsProvider;
import 'backend.dart';
import 'contests.dart' show serverContestsProvider;
import 'entreprise.dart' show refreshCompanyData;
import 'lots.dart' show copyText;
import 'notifs.dart' show notifsProvider;
import 'ops.dart' show serverReportsProvider;
import 'reels.dart' show followingIdsProvider;
import 'review.dart' show reviewQueueProvider;
import 'seller.dart' show platformListingsProvider, serverSellerOrdersProvider;
import 'auth.dart' show authProvider, requireLogin;
import 'social_profile.dart' show publicProfileProvider;
import 'share.dart' show shareText, siteUrl;
import 'store.dart' show ordersProvider;

/// Actions des libellés qui ressemblaient à des boutons sans rien faire (audit du 01/11).
/// Règle : une vraie action quand elle existe ; sinon un message explicite, jamais un faux succès.

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// « Actualiser » des tableaux de bord : relit réellement les données du serveur ; sinon le dit.
Future<void> uiRefresh(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) {
    gToast(context, 'Données d’exemple : aucun serveur à relire.');
    return;
  }
  if (ref.read(authProvider).current == null) {
    // Sans compte, le serveur refuse la lecture : on propose de se connecter plutôt que d'accuser le réseau.
    await requireLogin(context, ref, 'actualiser vos données');
    return;
  }
  final container = ProviderScope.containerOf(context, listen: false);
  if (!await Backend.probe('messages')) {
    if (context.mounted) gToast(context, 'Actualisation impossible : connexion au serveur indisponible.');
    return;
  }
  try {
    final results = await Future.wait<Object?>([
      ref.read(serverAccountsProvider.notifier).refresh(),
      ref.read(serverReportsProvider.notifier).refresh(),
      ref.read(reviewQueueProvider.notifier).refresh(),
      ref.read(serverContestsProvider.notifier).refresh(),
      ref.read(ordersProvider.notifier).refresh(),
      ref.read(serverSellerOrdersProvider.notifier).refresh(),
      ref.read(platformListingsProvider.notifier).refresh(),
      ref.read(notifsProvider.notifier).refresh(),
      refreshCompanyData(container),
    ]);
    if (!context.mounted) return;
    // « Données relues » seulement si les besoins, propositions, devis et défis de l'entreprise ont réellement été relus.
    if (results.last == true) {
      gToast(context, 'Données relues sur le serveur à ${_hm(DateTime.now())}');
    } else {
      gToast(context, 'Actualisation incomplète : certaines listes n’ont pas pu être relues. Réessayez dans un instant.');
    }
  } catch (_) {
    if (context.mounted) gToast(context, 'Actualisation incomplète : réessayez dans un instant.');
  }
}

/// Fonction pas encore disponible : on le dit clairement et on indique ce qui est possible aujourd'hui.
Future<void> uiSoon(BuildContext context, String what, String meanwhile) =>
    gAlert(context, what, '$what n’est pas encore disponible dans cette version.\n\n$meanwhile');

Future<void> uiCustomizeView(BuildContext context) =>
    uiSoon(context, 'Personnaliser la vue', 'L’affichage par défaut présente toutes les colonnes ; la recherche en haut de page permet de retrouver un élément.');

Future<void> uiFilters(BuildContext context) =>
    uiSoon(context, 'Filtrer ce tableau', 'Utilisez la recherche en haut de page ou les rubriques du menu de gauche pour afficher une catégorie précise.');

Future<void> uiExport(BuildContext context) =>
    uiSoon(context, 'L’export de fichiers', 'Les chiffres affichés sont consultables à l’écran ; l’export PDF, Excel et CSV sera ajouté dans une prochaine version.');

/// « S'abonner » : avec l'identifiant d'un auteur (profil public ?user=), le suivi est réellement enregistré (engagement ollow, comme sur les reels) ;
/// sans identifiant (maquette), le message dit que le suivi viendra avec le profil complet.
Future<void> uiFollow(BuildContext context, [WidgetRef? ref, String authorId = '']) async {
  if (ref == null || authorId.trim().isEmpty) {
    return gAlert(context, 'S’abonner à un créateur', 'Le suivi sera disponible avec le profil complet.\n\nEn attendant, ajoutez ses créations à vos favoris pour les retrouver facilement.');
  }
  if (!await requireLogin(context, ref, 'suivre un créateur') || !context.mounted) return;
  if (!Backend.ready) return gAlert(context, 'S’abonner à un créateur', 'Le suivi nécessite la connexion au serveur.');
  final id = authorId.trim();
  if (id == ref.read(authProvider).current?.serverId) return gToast(context, 'C’est votre profil.');
  var name = '';
  try {
    name = (await ref.read(publicProfileProvider(id).future)).name;
  } catch (_) {}
  final who = name.isEmpty ? 'ce créateur' : name;
  final err = await Backend.engage('follow', id, const {});
  if (!context.mounted) return;
  if (err == null) {
    ref.invalidate(followingIdsProvider);
    return gToast(context, 'Vous suivez $who');
  }
  if (err.contains('Déjà')) {
    final e2 = await Backend.cancelEngagement('follow', id);
    if (!context.mounted) return;
    if (e2 == null) ref.invalidate(followingIdsProvider);
    return e2 == null ? gToast(context, 'Vous ne suivez plus $who') : gAlert(context, 'Action impossible', Backend.userMessage(e2));
  }
  await gAlert(context, 'Action impossible', Backend.userMessage(err));
}

void uiAllShown(BuildContext context) => gToast(context, 'Tous les éléments sont déjà affichés sur cet écran.');

/// Copie réelle dans le presse-papiers ; le message dit si la copie a réussi.
Future<void> uiCopy(BuildContext context, String text, String what) async {
  final ok = await copyText(text);
  if (context.mounted) gToast(context, ok ? '$what copié' : 'Copie impossible : autorisez l’accès au presse-papiers.');
}

/// Lien public d'un profil : ouvre la page de CETTE personne (route /etudiant/:id), jamais le profil de celui qui l'ouvre.
String profileLink(String id) => id.trim().isEmpty ? siteUrl : '$siteUrl/#/etudiant/${Uri.encodeComponent(id.trim())}';

/// Partage d'un profil : message prêt à envoyer (WhatsApp, SMS…) avec le vrai lien public ; copie du lien si le partage est indisponible.
Future<void> shareProfile(BuildContext context, {required String id, String name = '', String department = '', String institution = '', bool mine = false}) async {
  final who = name.trim();
  final spec = [if (department.isNotEmpty) department, if (institution.isNotEmpty) institution].join(' · ');
  final intro = who.isEmpty ? (mine ? 'Découvre mon profil' : 'Découvre ce profil') : 'Découvre le profil de $who';
  final msg = '$intro sur Boutik-École${spec.isEmpty ? '' : ' ($spec)'} : ${profileLink(id)}';
  await shareText(context, msg, subject: mine ? 'Mon profil Boutik-École' : 'Profil Boutik-École');
}

/// Partage de son profil.
Future<void> shareMyProfile(BuildContext context, WidgetRef ref) async {
  final me = ref.read(authProvider).current;
  await shareProfile(context, id: me?.serverId ?? '', name: me?.name ?? '', department: me?.department ?? '', institution: me?.institution ?? '', mine: true);
}

/// Lien public d'un écran de l'application ; [product] : titre du produit concerné, ajouté au lien.
String uiLink(String id, {String product = ''}) => product.trim().isEmpty ? '$siteUrl/#/s/$id' : '$siteUrl/#/s/$id?product=${Uri.encodeQueryComponent(product.trim())}';
