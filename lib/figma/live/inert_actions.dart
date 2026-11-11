import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import 'admin.dart' show serverAccountsProvider;
import 'backend.dart';
import 'contests.dart' show serverContestsProvider;
import 'lots.dart' show copyText;
import 'notifs.dart' show notifsProvider;
import 'ops.dart' show serverReportsProvider;
import 'review.dart' show reviewQueueProvider;
import 'seller.dart' show platformListingsProvider, serverSellerOrdersProvider;
import 'auth.dart' show authProvider;
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
  if (!await Backend.probe('messages')) {
    if (context.mounted) gToast(context, 'Actualisation impossible : connexion au serveur indisponible.');
    return;
  }
  try {
    await Future.wait([
      ref.read(serverAccountsProvider.notifier).refresh(),
      ref.read(serverReportsProvider.notifier).refresh(),
      ref.read(reviewQueueProvider.notifier).refresh(),
      ref.read(serverContestsProvider.notifier).refresh(),
      ref.read(ordersProvider.notifier).refresh(),
      ref.read(serverSellerOrdersProvider.notifier).refresh(),
      ref.read(platformListingsProvider.notifier).refresh(),
      ref.read(notifsProvider.notifier).refresh(),
    ]);
    if (context.mounted) gToast(context, 'Données relues sur le serveur à ${_hm(DateTime.now())}');
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

Future<void> uiFollow(BuildContext context) =>
    uiSoon(context, 'S’abonner à un créateur', 'Ajoutez ses créations à vos favoris pour les retrouver facilement.');

void uiAllShown(BuildContext context) => gToast(context, 'Tous les éléments sont déjà affichés sur cet écran.');

/// Copie réelle dans le presse-papiers ; le message dit si la copie a réussi.
Future<void> uiCopy(BuildContext context, String text, String what) async {
  final ok = await copyText(text);
  if (context.mounted) gToast(context, ok ? '$what copié' : 'Copie impossible : autorisez l’accès au presse-papiers.');
}

/// Partage de son profil : message prêt à envoyer (WhatsApp, SMS…) avec le vrai lien public ; copie du lien si le partage est indisponible.
Future<void> shareMyProfile(BuildContext context, WidgetRef ref) async {
  final me = ref.read(authProvider).current;
  final id = me?.serverId ?? '';
  final link = id.isEmpty ? siteUrl : '$siteUrl/#/s/247?user=${Uri.encodeQueryComponent(id)}';
  final who = (me?.name ?? '').trim();
  final spec = [if (me != null && me.department.isNotEmpty) me.department, if (me != null && me.institution.isNotEmpty) me.institution].join(' · ');
  final msg = '${who.isEmpty ? 'Découvre mon profil' : 'Découvre le profil de $who'} sur Boutik-École${spec.isEmpty ? '' : ' ($spec)'} : $link';
  await shareText(context, msg, subject: 'Mon profil Boutik-École');
}

/// Lien public d'un écran de l'application.
String uiLink(String id) => '$siteUrl/#/s/$id';
