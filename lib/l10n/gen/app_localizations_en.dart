// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Boutik-École';

  @override
  String get demoData => 'Demo data';

  @override
  String get demoDataHint =>
      'Figures shown are fictitious and for demonstration only.';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSubtitle => 'Choose the app language';

  @override
  String get continueLabel => 'Continue';

  @override
  String get back => 'Back';
}
