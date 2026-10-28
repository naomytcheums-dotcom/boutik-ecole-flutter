import 'package:boutik_ecole/core/router/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';

/// Textes clés attendus par écran (titre de la maquette + un contenu caractéristique).
const keyTexts = <String, List<String>>{
  '255': ['Suivi de publication', 'Contrôles réglementaires'],
  '256': ['Contrôles automatiques', '12 / 12 réussis'],
  '257': ['En attente de confirmation', '330 000 FCFA'],
  '258': ['Le paiement a échoué', 'Solde insuffisant'],
  '259': ['Paiement reçu', 'RC-2026-00842'],
  '260': ['Facture', '98 000 FCFA', '68 600 FCFA'],
  '261': ['Mon espace client', '2 commandes en cours'],
  '270': ['Showroom national', 'Kit solaire portable'],
  '271': ['Mes liens et réseaux', 'LinkedIn'],
  '272': ['Saisissez le code reçu', 'Vérifier'],
  '273': ['Vous gardez le contrôle', 'Supprimer mon compte'],
  '274': ['Conditions générales', 'J’ai lu et j’accepte les CGU'],
  '275': ['Déposer un produit', 'Le titre est obligatoire (3 à 80 caractères).'],
  '276': ['Connexion momentanément indisponible', 'Parcourir le catalogue hors ligne'],
  '277': ['Supervision des bornes', 'Borne 2 · Bibliothèque'],
  '278': ['Liens du projet', 'CC BY-NC 4.0'],
  '279': ['Règles de dépôt', 'script.exe'],
  '280': ['API publique', 'Webhooks'],
  '281': ['Rôles et périmètres', 'Isolation des institutions'],
  '282': ['QR de transfert', 'HMAC-SHA256 vérifiée'],
  '283': ['Registre des certificats', 'Révoqué'],
  '284': ['Registre financier', '271 770 FCFA', '190 239 FCFA'],
  '285': ['Contrat de mission', 'Valider le jalon 3'],
  '286': ['Soumissions en attente (3)', 'Équipe et permissions'],
  '74': ['Talent Passport', 'Compétences vérifiées'],
  '287': ['Catalogue du département MMI', '+ Nouvelle fiche'],
  '262': ['Accueil B2B', 'Talents recommandés'],
  '263': ['Médiathèque', 'Téléverser un média'],
  '264': ['Pages éditoriales', 'Historique des versions conservé'],
  '265': ['Modèles de notifications', 'Paiement échoué'],
  '266': ['État technique', 'Lancer la restauration'],
  '267': ['Boutik-École Network', 'IUT de Bandjoun'],
  '268': ['Analytics de la borne', 'Sessions par jour'],
  '269': ['Innovation Radar', 'Besoins du marché'],
  '288': ['Catalogue du département MMI', 'Lampe de bureau LED'],
  '250b': ['Nouvelle publication', 'Comptes suggérés'],
  '01': ['Des talents étudiants', 'Commencer'],
  '02': ['Des talents étudiants', 'Se connecter'],
  '03': ['Bienvenue', 'Produits en vedette', '25 000 FCFA'],
  '04': ['Explorer', 'Développement web sur mesure'],
  '05': ['Lampe en bois recyclé', 'Ajouter au panier'],
  '06': ['Mon panier', '330 000 FCFA'],
  '07': ['Livraison', 'Retrait sur campus'],
  '08': ['Moyen de paiement', 'Payer maintenant'],
  '09': ['#BE-2025-0018', 'En préparation'],
  '10': ['Mariam Essono', 'Talent Passport · Confirmé · 3 badges'],
  '11': ['Bon retour !', 'Se connecter'],
  '12': ['Créer un compte', 'Créer mon compte'],
  '13': ['Quel est votre profil ?', 'Étudiant vendeur'],
  '14': ['Vérification du compte', 'Renvoyer dans 00:45'],
  '15': ['Réinitialiser votre mot de passe', 'Envoyer le code'],
  '16': ['Créez un nouveau mot de passe', 'Un caractère spécial'],
  '17': ['Conditions et confidentialité', 'Statistiques anonymes'],
  '18': ['Demande en cours d’examen', 'Résultats possibles'],
  '18b': ['Compléter mon profil', 'Établissement'],
  '18c': ['Vérification étudiant', 'Certificat de scolarité'],
  '19': ['inspire', 'Recherche avancée'],
  '20': ['128 résultats', 'Sac à dos design'],
};

void main() {
  setUpAll(loadAppFonts);

  test('chaque écran enregistré a ses textes clés déclarés', () {
    final missing = screensById.keys.where((id) => !keyTexts.containsKey(id)).toList();
    expect(missing, isEmpty, reason: 'Ajouter les textes clés de : $missing');
  });

  for (final s in screensById.values) {
    testWidgets('${s.id} · ${s.title} s’affiche sans erreur', (tester) async {
      await pumpScreen(tester, s.id, size: designSize(s.format));
      expect(tester.takeException(), isNull);
      for (final t in keyTexts[s.id] ?? const <String>[]) {
        final finder = find.byWidgetPredicate((w) {
          final text = switch (w) {
            Text(:final data?) => data,
            RichText(:final text) => text.toPlainText(),
            _ => null,
          };
          return text != null && text.replaceAll('\u00A0', ' ').contains(t);
        });
        expect(finder, findsWidgets, reason: 'Texte « $t » absent de l’écran ${s.id}');
      }
    });
  }
}

