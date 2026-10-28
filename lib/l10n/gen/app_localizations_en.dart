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

  @override
  String get kioskHeroTitle => 'IUT de Douala talents,\nwithin reach';

  @override
  String get kioskHeroSubtitle => 'Buy, order a service or launch a mission.';

  @override
  String get kioskStart => 'Touch to start';

  @override
  String get kioskReady => 'Kiosk ready · network OK';

  @override
  String get kioskSearchHint => 'What are you looking for?';

  @override
  String get kioskTabAll => 'All';

  @override
  String get kioskTabProducts => 'Products';

  @override
  String get kioskTabServices => 'Services';

  @override
  String get kioskTabMissions => 'Missions';

  @override
  String get kioskEmpty => 'No results for now.';

  @override
  String get kioskBoosted => 'Boosted';

  @override
  String get kioskNavHome => 'Home';

  @override
  String get kioskNavExplore => 'Explore';

  @override
  String get kioskNavMyQr => 'My QR';

  @override
  String get kioskNavHelp => 'Help';

  @override
  String get kioskHelpMessage => 'A team member is coming to help you.';

  @override
  String kioskReviews(String rating, int count) {
    return '$rating · $count reviews';
  }

  @override
  String kioskVerified(String field) {
    return '$field · Verified talent';
  }

  @override
  String get kioskOnPhone => 'On my phone';

  @override
  String get kioskOrder => 'Order';

  @override
  String get kioskQrTitle => 'Continue on your phone';

  @override
  String get kioskQrSubtitle => 'Scan the code to find this product and order.';

  @override
  String get kioskQrValid => 'Code valid';

  @override
  String get kioskQrExpired => 'Code expired';

  @override
  String get kioskQrRenew => 'New code';

  @override
  String get kioskQrSemantics => 'Product QR code. Touch to simulate the scan.';

  @override
  String get kioskStepScan => 'Scan';

  @override
  String get kioskStepOpen => 'Open the page';

  @override
  String get kioskStepOrder => 'Order';

  @override
  String get kioskCancel => 'Cancel';

  @override
  String get kioskSentTitle => 'Sent!';

  @override
  String get kioskSentSubtitle => 'The product link is on your phone.';

  @override
  String get kioskDate => 'Date';

  @override
  String get kioskTime => 'Time';

  @override
  String get kioskPickup => 'Pickup';

  @override
  String get kioskTrackingCode => 'Tracking code';

  @override
  String get kioskPrint => 'Print';

  @override
  String get kioskPrinting => 'Printing the ticket…';

  @override
  String get kioskFinish => 'Finish';

  @override
  String kioskBackHome(int seconds) {
    return 'Back to home in $seconds s';
  }
}
