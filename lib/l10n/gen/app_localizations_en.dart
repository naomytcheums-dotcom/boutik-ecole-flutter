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

  @override
  String get languageFrench => 'Français';

  @override
  String get languageDefault => 'Default language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishRegion => 'English (Cameroon)';

  @override
  String get languageActive => 'Active';

  @override
  String get languagePreview => 'Preview';

  @override
  String get previewLampTitle => 'Recycled wooden lamp';

  @override
  String previewLampDetail(String price) {
    return '$price · Civil Engineering';
  }

  @override
  String get previewInStock => 'In stock';

  @override
  String get previewChallengeTitle => 'Orange Digital Challenge';

  @override
  String get previewChallengeDetail => 'Registration open · Douala';

  @override
  String get previewOpen => 'Open';

  @override
  String get languageHint =>
      'Switch language anytime in Settings. Short, clear texts in both French and English.';
}
