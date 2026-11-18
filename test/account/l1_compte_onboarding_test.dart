import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:boutik_ecole/figma/live/auth.dart';
import 'package:boutik_ecole/figma/live/backend.dart';

void main() {
  const client = Account(name: 'Awa Client', phone: '', email: 'a@b.cm', password: '', role: 0);
  const student = Account(name: 'Eto Étudiant', phone: '', email: 'e@b.cm', password: '', role: 1);
  const company = Account(name: 'Ent', phone: '', email: 'c@b.cm', password: '', role: 2);
  const admin = Account(name: 'Adm', phone: '', email: 'ad@b.cm', password: '', role: 1, staff: 'Admin global');

  group('routage par rôle après connexion', () {
    test('un étudiant-vendeur arrive sur son profil, les autres comptes sur l’accueil', () {
      expect(homeScreenFor(student), '10');
      expect(homeScreenFor(client), '03');
      expect(homeScreenFor(company), '03');
      expect(homeScreenFor(admin), '03');
      expect(homeScreenFor(null), '03');
    });
  });

  group('inscription', () {
    test('les trois profils restent proposés au choix (Client, Étudiant, Organisation : plus de rôle « Autre »)', () {
      expect(selfServiceRoles, 3);
    });

    test('la version des conditions enregistrée a un format valide pour le serveur', () {
      expect(kTermsVersion, matches(RegExp(r'^cgu-\d{4}-\d{2}$')));
    });
  });

  group('lien de réinitialisation du mot de passe', () {
    test('sur Android, le lien revient dans l’application', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(Backend.recoveryRedirect(), 'cm.iutdouala.boutik_ecole://reset-callback/');
    });

    test('sur les autres plateformes natives, il renvoie vers le site de production', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(Backend.recoveryRedirect(), 'https://boutik-ecole.vercel.app/');
    });
  });
}
