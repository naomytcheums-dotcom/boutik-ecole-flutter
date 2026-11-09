import 'package:boutik_ecole/figma/live/integrations_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catalogue des fournisseurs', () {
    test('quatre familles, 21 fournisseurs aux identifiants uniques', () {
      expect(kProviders.length, 21);
      expect({for (final p in kProviders) p.id}.length, 21);
      for (final f in IntFamily.values) {
        expect(kProviders.where((p) => p.family == f), isNotEmpty, reason: f.label);
      }
    });

    test('familles demandées : réseaux, productivité, collaboration, télécoms', () {
      List<String> ids(IntFamily f) => [for (final p in kProviders) if (p.family == f) p.id];
      expect(ids(IntFamily.reseaux), ['facebook', 'instagram', 'linkedin', 'tiktok', 'youtube', 'behance']);
      expect(ids(IntFamily.productivite), ['google_drive', 'google_docs', 'google_sheets', 'gmail', 'google_calendar', 'onedrive', 'dropbox']);
      expect(ids(IntFamily.collaboration), ['slack', 'discord', 'github', 'notion', 'trello', 'teams']);
      expect(ids(IntFamily.telecom), ['mtn_momo', 'orange_money']);
    });

    test('les limites officielles sont dites, sans fonction inventée', () {
      expect(providerById('facebook')!.limit, contains('Pages'));
      expect(providerById('tiktok')!.canPublish, isFalse, reason: 'publication TikTok soumise à audit');
      expect(providerById('tiktok')!.limit, contains('audit'));
      expect(providerById('linkedin')!.canImport, isFalse, reason: 'lecture soumise à approbation LinkedIn');
      expect(providerById('behance')!.linkOnly, isTrue);
      expect(providerById('gmail')!.limit, contains('boîte de réception'));
      expect(providerById('trello')!.oauth1, isTrue, reason: 'Trello n’offre pas OAuth 2.0');
      for (final p in kProviders.where((p) => !p.linkOnly && !p.isMobileMoney)) {
        expect(p.permissions, isNotEmpty, reason: '${p.id} doit annoncer ses permissions');
      }
    });

    test('recherche insensible à la casse et aux accents', () {
      expect([for (final p in filterProviders('GIT')) p.id], ['github']);
      expect(filterProviders('productivite').length, 7);
      expect(filterProviders('télécoms').length, 2);
      expect(filterProviders('zzz'), isEmpty);
      expect(filterProviders('', family: IntFamily.collaboration).length, 6);
    });

    test('exigences du propriétaire listées pour chaque fournisseur', () {
      expect(ownerRequirements(providerById('mtn_momo')!).join(' '), contains('MTN_MOMO_SUBSCRIPTION_KEY'));
      expect(ownerRequirements(providerById('youtube')!).join(' '), contains('GOOGLE_CLIENT_ID'));
      expect(ownerRequirements(providerById('teams')!).join(' '), contains('MICROSOFT_CLIENT_ID'));
      expect(ownerRequirements(providerById('facebook')!).join(' '), contains('integrations-oauth/callback'));
    });
  });

  group('adaptation du texte par plateforme', () {
    test('Instagram : lien remplacé par « Lien dans la bio », limite 2200', () {
      final a = adaptForPlatform('instagram', 'Nouveau produit !', link: 'https://boutik-ecole.vercel.app/p/1');
      expect(a.text, 'Nouveau produit !\n\nLien dans la bio.');
      expect(a.text.contains('https://'), isFalse);
      expect(a.note, isNotNull);
      expect(adaptForPlatform('instagram', 'x' * 5000).text.length, lessThanOrEqualTo(2200));
    });

    test('Instagram : 30 mots-clics au maximum', () {
      final tags = List.generate(40, (i) => '#tag$i').join(' ');
      final a = adaptForPlatform('instagram', 'Texte $tags');
      expect(RegExp(r'#\w+').allMatches(a.text).length, 30);
    });

    test('Facebook : le lien part comme aperçu séparé, pas dans le texte', () {
      final a = adaptForPlatform('facebook', 'Annonce', link: 'https://exemple.cm');
      expect(a.text, 'Annonce');
      expect(a.link, 'https://exemple.cm');
    });

    test('Discord : limite 2000 avec lien conservé en fin de message', () {
      final a = adaptForPlatform('discord', 'mot ' * 900, link: 'https://exemple.cm/x');
      expect(a.text.length, lessThanOrEqualTo(2000));
      expect(a.text.endsWith('\n\nhttps://exemple.cm/x'), isTrue);
      expect(a.text.contains('…'), isTrue);
    });

    test('Slack : gras Markdown converti', () {
      expect(adaptForPlatform('slack', 'Un **gros** titre').text, 'Un *gros* titre');
    });

    test('espaces normalisés, texte court inchangé', () {
      expect(adaptForPlatform('linkedin', '  Bonjour   \n\n\n\nMonde  ').text, 'Bonjour\n\nMonde');
    });

    test('la coupure se fait sur un mot entier', () {
      final a = adaptForPlatform('discord', '${'abcdefghij ' * 300}fin');
      expect(a.text.endsWith('…'), isTrue);
      expect(a.text.length, lessThanOrEqualTo(2000));
    });
  });

  group('Mobile Money', () {
    test('normalisation et masquage des numéros', () {
      expect(normalizePhone('6 77 12 34 56'), '237677123456');
      expect(normalizePhone('+237 677 12 34 56'), '237677123456');
      expect(normalizePhone('12345'), isNull);
      expect(normalizePhone('237577123456'), isNull);
      expect(maskPhone('237677123456'), '+237 6 •• •• •• 56');
      expect(maskPhone('237677123456').contains('77123'), isFalse);
      expect(formatPhone('237677123456'), '+237 677 12 34 56');
    });

    MomoNumber number({bool verified = true, String phone = '237677000001'}) =>
        MomoNumber(id: 'n', operator: 'MTN', phone: phone, label: '', primary: true, verif: verified ? MomoVerif.verified : MomoVerif.unverified);

    test('un envoi exige un numéro vérifié, un destinataire valide et un montant dans les bornes', () {
      expect(validateTransfer(to: '677123456', amount: '1000', from: null), contains('Choisissez'));
      expect(validateTransfer(to: '677123456', amount: '1000', from: number(verified: false)), contains('Vérifiez'));
      expect(validateTransfer(to: '12', amount: '1000', from: number()), contains('invalide'));
      expect(validateTransfer(to: '677000001', amount: '1000', from: number()), contains('différent'));
      expect(validateTransfer(to: '677123456', amount: '0', from: number()), contains('Montant'));
      expect(validateTransfer(to: '677123456', amount: '600000', from: number()), contains('Montant'));
      expect(validateTransfer(to: '677123456', amount: 'abc', from: number()), contains('Montant'));
      expect(validateTransfer(to: '677123456', amount: '1 500', from: number()), isNull);
    });

    test('reçu : référence et montant, jamais le numéro complet du destinataire ni de PIN', () {
      final t = MomoTx(reference: 'MM261109000001', operator: 'MTN', direction: 'out', phone: '237677123456', amount: 2500, status: 'confirmed', createdAt: DateTime(2026, 11, 9, 10, 30), note: 'Loyer');
      final r = receiptText(t, fromLabel: 'Boutique');
      expect(r, contains('MM261109000001'));
      expect(r, contains('2500 FCFA'));
      expect(r, contains('Réussi'));
      expect(r, contains('09/11/2026'));
      expect(r.contains('677123456'), isFalse);
      expect(r.toLowerCase().contains('pin'), isFalse);
    });

    test('états lisibles', () {
      expect(momoStatusLabel('awaiting_confirmation'), 'À confirmer');
      expect(momoStatusLabel('pending'), 'En cours');
      expect(momoStatusLabel('failed'), 'Échoué');
      expect(momoVerifLabel(MomoVerif.verified), 'Vérifié');
    });
  });

  group('lecture des données serveur', () {
    test('connexion avec comptes et permissions', () {
      final c = IntConnection.fromJson({
        'id': 'c1', 'provider': 'facebook', 'display_name': 'Mariam', 'status': 'expired', 'last_sync_at': '2026-11-09T08:00:00Z',
        'integration_accounts': [
          {'id': 'a1', 'external_id': 'p1', 'kind': 'page', 'name': 'Ma Page', 'publish_enabled': true},
        ],
        'integration_permissions': [
          {'scope': 'pages_manage_posts'},
        ],
      });
      expect(c.status, ConnStatus.expired);
      expect(connStatusLabel(c.status), 'À reconnecter');
      expect(c.accounts.single.publish, isTrue);
      expect(c.permissions, ['pages_manage_posts']);
      expect(c.active, isFalse);
    });

    test('numéro, transaction, tableau de bord', () {
      final n = MomoNumber.fromJson({'id': 'n1', 'operator': 'ORANGE', 'phone': '237690000000', 'label': 'Perso', 'is_primary': true, 'verification_status': 'verified'});
      expect(n.title, 'Perso');
      expect(n.verified, isTrue);
      expect(n.operatorName, 'Orange Money');
      final d = MomoDashboard.fromJson({'sent_month': 5000, 'received_month': 0, 'pending': 1, 'failed_month': 2, 'count_month': 3});
      expect(d.sentMonth, 5000);
      expect(d.failedMonth, 2);
    });
  });
}
