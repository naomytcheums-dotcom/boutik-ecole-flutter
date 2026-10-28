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
}
