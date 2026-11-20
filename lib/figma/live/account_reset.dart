import 'backend.dart';
import 'hackathons.dart' show contestTeamsReadable;
import 'seller.dart' show Listing;
import 'store.dart' as store;

/// Remet à zéro les états qui vivent HORS de l'arbre de providers (statiques et globaux) et qui, sans cela, survivraient à la déconnexion :
/// code promo et packs du panier du compte précédent, annonces vendeur en mémoire, seuil de stock du vendeur précédent, état du profil.
/// Les providers eux-mêmes sont jetés avec le `ProviderScope` (AppRoot.appReset) ; les brouillons et la session sont effacés par `AuthNotifier.logout`.
void resetAccountScopedState() {
  Backend.promoCode = '';
  Backend.packLines.clear();
  Backend.profileMissing = false;
  store.extraProducts = const [];
  store.platformProducts = store.liveCatalog;
  Listing.lowStock = 30;
  contestTeamsReadable = true;
}
