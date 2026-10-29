import 'package:boutik_ecole/core/utils/money.dart';
import 'package:boutik_ecole/core/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/render.dart';
import '../helpers/screen_texts.dart';

void main() {
  expectScreenTexts(const {
    '182': ['Explorer', 'Produits', 'Chargement en cours… les contenus apparaissent progressivement.'],
    '183': ['Mes commandes', '#BE-2026-0142', 'Livrée · 32 500 FCFA', 'Réessayer la connexion'],
    '184': ['Économie de données', 'Synchronisation en arrière-plan', '182 Mo', '64 Mo'],
    '185': ['Language', 'English (Cameroon)', 'Recycled wooden lamp', '25,000 FCFA · Civil Engineering'],
    '186': ['Accessibilité', 'Très grand', 'Normes appliquées', '44 × 44 px'],
  });

  test('fcfaLocalized : séparateur selon la langue', () {
    expect(fcfaLocalized(25000, 'fr'), fcfa(25000));
    expect(fcfaLocalized(1250000, 'en'), '1,250,000\u00A0FCFA');
  });

  testWidgets('185 : choisir Français traduit l’écran', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '185');
    expect(find.text('Preview'), findsOneWidget);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(find.text('Aperçu'), findsOneWidget);
    expect(find.text('Lampe en bois recyclé'), findsOneWidget);
    expect(find.textContaining('25\u00A0000\u00A0FCFA'), findsOneWidget);
  });

  testWidgets('186 : la taille « Grand » active le texte agrandi', (tester) async {
    await loadAppFonts();
    await pumpScreen(tester, '186');
    bool largeOn() => tester.widget<ToggleRow>(find.widgetWithText(ToggleRow, 'Texte agrandi')).value;
    expect(largeOn(), isFalse);
    await tester.tap(find.text('Grand'));
    await tester.pumpAndSettle();
    expect(largeOn(), isTrue);
  });
}
