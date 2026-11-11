import 'package:boutik_ecole/figma/i18n.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => I18n.setLang('fr', save: false));

  test('le fichier de traduction anglaise est présent et rempli', () async {
    expect(await I18n.available(), isTrue);
  });

  test('textes fixes : français par défaut, anglais sur demande, retour au français', () async {
    expect(I18n.tr('Mes commandes'), 'Mes commandes');
    await I18n.setLang('en', save: false);
    expect(I18n.tr('Mes commandes'), 'My orders');
    expect(I18n.tr('Se connecter'), 'Log in');
    expect(I18n.tr('Parrainer et gagner'), 'Refer and earn');
    await I18n.setLang('fr', save: false);
    expect(I18n.tr('Mes commandes'), 'Mes commandes');
  });

  test('textes avec valeurs : le modèle est traduit et la valeur conservée', () async {
    await I18n.setLang('en', save: false);
    expect(I18n.tr('Bonjour Marie'), 'Hello Marie');
  });

  test('un texte inconnu reste en français plutôt que d’être inventé', () async {
    await I18n.setLang('en', save: false);
    expect(I18n.tr('Phrase absente du fichier de traduction xyz'), 'Phrase absente du fichier de traduction xyz');
  });

  test('les noms propres de l’application ne sont jamais traduits', () async {
    await I18n.setLang('en', save: false);
    expect(I18n.tr('Boutik-École'), contains('Boutik-École'));
  });
}
