import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Boutik-École'**
  String get appTitle;

  /// No description provided for @demoData.
  ///
  /// In fr, this message translates to:
  /// **'Données de démonstration'**
  String get demoData;

  /// No description provided for @demoDataHint.
  ///
  /// In fr, this message translates to:
  /// **'Les chiffres affichés sont fictifs et servent à la démonstration.'**
  String get demoDataHint;

  /// No description provided for @languageTitle.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageTitle;

  /// No description provided for @languageSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la langue de l’application'**
  String get languageSubtitle;

  /// No description provided for @continueLabel.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get continueLabel;

  /// No description provided for @back.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get back;

  /// No description provided for @languageFrench.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageDefault.
  ///
  /// In fr, this message translates to:
  /// **'Langue par défaut'**
  String get languageDefault;

  /// No description provided for @languageEnglish.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageEnglishRegion.
  ///
  /// In fr, this message translates to:
  /// **'Anglais (Cameroun)'**
  String get languageEnglishRegion;

  /// No description provided for @languageActive.
  ///
  /// In fr, this message translates to:
  /// **'Active'**
  String get languageActive;

  /// No description provided for @languagePreview.
  ///
  /// In fr, this message translates to:
  /// **'Aperçu'**
  String get languagePreview;

  /// No description provided for @previewLampTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lampe en bois recyclé'**
  String get previewLampTitle;

  /// No description provided for @previewLampDetail.
  ///
  /// In fr, this message translates to:
  /// **'{price} · Génie civil'**
  String previewLampDetail(String price);

  /// No description provided for @previewInStock.
  ///
  /// In fr, this message translates to:
  /// **'En stock'**
  String get previewInStock;

  /// No description provided for @previewChallengeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Orange Digital Challenge'**
  String get previewChallengeTitle;

  /// No description provided for @previewChallengeDetail.
  ///
  /// In fr, this message translates to:
  /// **'Inscriptions ouvertes · Douala'**
  String get previewChallengeDetail;

  /// No description provided for @previewOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvert'**
  String get previewOpen;

  /// No description provided for @languageHint.
  ///
  /// In fr, this message translates to:
  /// **'Changez de langue à tout moment dans les paramètres. Des textes courts et clairs, en français comme en anglais.'**
  String get languageHint;

  /// No description provided for @kioskHeroTitle.
  ///
  /// In fr, this message translates to:
  /// **'Les talents de l’IUT de Douala,\nà portée de main'**
  String get kioskHeroTitle;

  /// No description provided for @kioskHeroSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Achetez, commandez un service ou lancez une mission.'**
  String get kioskHeroSubtitle;

  /// No description provided for @kioskStart.
  ///
  /// In fr, this message translates to:
  /// **'Touchez pour commencer'**
  String get kioskStart;

  /// No description provided for @kioskReady.
  ///
  /// In fr, this message translates to:
  /// **'Borne prête · réseau OK'**
  String get kioskReady;

  /// No description provided for @kioskSearchHint.
  ///
  /// In fr, this message translates to:
  /// **'Que cherchez-vous ?'**
  String get kioskSearchHint;

  /// No description provided for @kioskTabAll.
  ///
  /// In fr, this message translates to:
  /// **'Tout'**
  String get kioskTabAll;

  /// No description provided for @kioskTabProducts.
  ///
  /// In fr, this message translates to:
  /// **'Produits'**
  String get kioskTabProducts;

  /// No description provided for @kioskTabServices.
  ///
  /// In fr, this message translates to:
  /// **'Services'**
  String get kioskTabServices;

  /// No description provided for @kioskTabMissions.
  ///
  /// In fr, this message translates to:
  /// **'Missions'**
  String get kioskTabMissions;

  /// No description provided for @kioskEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour le moment.'**
  String get kioskEmpty;

  /// No description provided for @kioskBoosted.
  ///
  /// In fr, this message translates to:
  /// **'Boosté'**
  String get kioskBoosted;

  /// No description provided for @kioskNavHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get kioskNavHome;

  /// No description provided for @kioskNavExplore.
  ///
  /// In fr, this message translates to:
  /// **'Explorer'**
  String get kioskNavExplore;

  /// No description provided for @kioskNavMyQr.
  ///
  /// In fr, this message translates to:
  /// **'Mon QR'**
  String get kioskNavMyQr;

  /// No description provided for @kioskNavHelp.
  ///
  /// In fr, this message translates to:
  /// **'Aide'**
  String get kioskNavHelp;

  /// No description provided for @kioskHelpMessage.
  ///
  /// In fr, this message translates to:
  /// **'Un membre de l’équipe arrive pour vous aider.'**
  String get kioskHelpMessage;

  /// No description provided for @kioskReviews.
  ///
  /// In fr, this message translates to:
  /// **'{rating} · {count} avis'**
  String kioskReviews(String rating, int count);

  /// No description provided for @kioskVerified.
  ///
  /// In fr, this message translates to:
  /// **'{field} · Talent vérifié'**
  String kioskVerified(String field);

  /// No description provided for @kioskOnPhone.
  ///
  /// In fr, this message translates to:
  /// **'Sur mon téléphone'**
  String get kioskOnPhone;

  /// No description provided for @kioskOrder.
  ///
  /// In fr, this message translates to:
  /// **'Commander'**
  String get kioskOrder;

  /// No description provided for @kioskQrTitle.
  ///
  /// In fr, this message translates to:
  /// **'Continuez sur votre téléphone'**
  String get kioskQrTitle;

  /// No description provided for @kioskQrSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Scannez le code pour retrouver ce produit et commander.'**
  String get kioskQrSubtitle;

  /// No description provided for @kioskQrValid.
  ///
  /// In fr, this message translates to:
  /// **'Code valable'**
  String get kioskQrValid;

  /// No description provided for @kioskQrExpired.
  ///
  /// In fr, this message translates to:
  /// **'Code expiré'**
  String get kioskQrExpired;

  /// No description provided for @kioskQrRenew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau code'**
  String get kioskQrRenew;

  /// No description provided for @kioskQrSemantics.
  ///
  /// In fr, this message translates to:
  /// **'QR code du produit. Touchez pour simuler le scan.'**
  String get kioskQrSemantics;

  /// No description provided for @kioskStepScan.
  ///
  /// In fr, this message translates to:
  /// **'Scannez'**
  String get kioskStepScan;

  /// No description provided for @kioskStepOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrez la fiche'**
  String get kioskStepOpen;

  /// No description provided for @kioskStepOrder.
  ///
  /// In fr, this message translates to:
  /// **'Commandez'**
  String get kioskStepOrder;

  /// No description provided for @kioskCancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get kioskCancel;

  /// No description provided for @kioskSentTitle.
  ///
  /// In fr, this message translates to:
  /// **'C’est envoyé !'**
  String get kioskSentTitle;

  /// No description provided for @kioskSentSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Le lien du produit est sur votre téléphone.'**
  String get kioskSentSubtitle;

  /// No description provided for @kioskDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get kioskDate;

  /// No description provided for @kioskTime.
  ///
  /// In fr, this message translates to:
  /// **'Heure'**
  String get kioskTime;

  /// No description provided for @kioskPickup.
  ///
  /// In fr, this message translates to:
  /// **'Retrait'**
  String get kioskPickup;

  /// No description provided for @kioskTrackingCode.
  ///
  /// In fr, this message translates to:
  /// **'Code de suivi'**
  String get kioskTrackingCode;

  /// No description provided for @kioskPrint.
  ///
  /// In fr, this message translates to:
  /// **'Imprimer'**
  String get kioskPrint;

  /// No description provided for @kioskPrinting.
  ///
  /// In fr, this message translates to:
  /// **'Impression du ticket…'**
  String get kioskPrinting;

  /// No description provided for @kioskFinish.
  ///
  /// In fr, this message translates to:
  /// **'Terminer'**
  String get kioskFinish;

  /// No description provided for @kioskBackHome.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l’accueil dans {seconds} s'**
  String kioskBackHome(int seconds);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
