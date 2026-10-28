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
}
