// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Boutik-École';

  @override
  String get demoData => 'Données de démonstration';

  @override
  String get demoDataHint =>
      'Les chiffres affichés sont fictifs et servent à la démonstration.';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSubtitle => 'Choisissez la langue de l’application';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get back => 'Retour';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageDefault => 'Langue par défaut';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishRegion => 'Anglais (Cameroun)';

  @override
  String get languageActive => 'Active';

  @override
  String get languagePreview => 'Aperçu';

  @override
  String get previewLampTitle => 'Lampe en bois recyclé';

  @override
  String previewLampDetail(String price) {
    return '$price · Génie civil';
  }

  @override
  String get previewInStock => 'En stock';

  @override
  String get previewChallengeTitle => 'Orange Digital Challenge';

  @override
  String get previewChallengeDetail => 'Inscriptions ouvertes · Douala';

  @override
  String get previewOpen => 'Ouvert';

  @override
  String get languageHint =>
      'Changez de langue à tout moment dans les paramètres. Des textes courts et clairs, en français comme en anglais.';

  @override
  String get kioskHeroTitle =>
      'Les talents de l’IUT de Douala,\nà portée de main';

  @override
  String get kioskHeroSubtitle =>
      'Achetez, commandez un service ou lancez une mission.';

  @override
  String get kioskStart => 'Touchez pour commencer';

  @override
  String get kioskReady => 'Borne prête · réseau OK';

  @override
  String get kioskSearchHint => 'Que cherchez-vous ?';

  @override
  String get kioskTabAll => 'Tout';

  @override
  String get kioskTabProducts => 'Produits';

  @override
  String get kioskTabServices => 'Services';

  @override
  String get kioskTabMissions => 'Missions';

  @override
  String get kioskEmpty => 'Aucun résultat pour le moment.';

  @override
  String get kioskBoosted => 'Boosté';

  @override
  String get kioskNavHome => 'Accueil';

  @override
  String get kioskNavExplore => 'Explorer';

  @override
  String get kioskNavMyQr => 'Mon QR';

  @override
  String get kioskNavHelp => 'Aide';

  @override
  String get kioskHelpMessage =>
      'Un membre de l’équipe arrive pour vous aider.';

  @override
  String kioskReviews(String rating, int count) {
    return '$rating · $count avis';
  }

  @override
  String kioskVerified(String field) {
    return '$field · Talent vérifié';
  }

  @override
  String get kioskOnPhone => 'Sur mon téléphone';

  @override
  String get kioskOrder => 'Commander';

  @override
  String get kioskQrTitle => 'Continuez sur votre téléphone';

  @override
  String get kioskQrSubtitle =>
      'Scannez le code pour retrouver ce produit et commander.';

  @override
  String get kioskQrValid => 'Code valable';

  @override
  String get kioskQrExpired => 'Code expiré';

  @override
  String get kioskQrRenew => 'Nouveau code';

  @override
  String get kioskQrSemantics =>
      'QR code du produit. Touchez pour simuler le scan.';

  @override
  String get kioskStepScan => 'Scannez';

  @override
  String get kioskStepOpen => 'Ouvrez la fiche';

  @override
  String get kioskStepOrder => 'Commandez';

  @override
  String get kioskCancel => 'Annuler';

  @override
  String get kioskSentTitle => 'C’est envoyé !';

  @override
  String get kioskSentSubtitle => 'Le lien du produit est sur votre téléphone.';

  @override
  String get kioskDate => 'Date';

  @override
  String get kioskTime => 'Heure';

  @override
  String get kioskPickup => 'Retrait';

  @override
  String get kioskTrackingCode => 'Code de suivi';

  @override
  String get kioskPrint => 'Imprimer';

  @override
  String get kioskPrinting => 'Impression du ticket…';

  @override
  String get kioskFinish => 'Terminer';

  @override
  String kioskBackHome(int seconds) {
    return 'Retour à l’accueil dans $seconds s';
  }
}
