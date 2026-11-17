import 'package:boutik_ecole/figma/gen.dart';
import 'package:boutik_ecole/figma/live/backend.dart';
import 'package:boutik_ecole/figma/live/company_public_page.dart';
import 'package:boutik_ecole/figma/live/company_purchases.dart';
import 'package:boutik_ecole/figma/live/f4_api.dart';
import 'package:boutik_ecole/figma/live/quote_negotiation.dart';
import 'package:boutik_ecole/figma/live/talent_search_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/render.dart';

/// Faux serveur du lot F4 : enregistre chaque appel de fonction serveur et répond avec les données du test.
class _Server {
  final calls = <(String, Map<String, dynamic>)>[];
  final handlers = <String, Object? Function(Map<String, dynamic>)>{};

  Future<({Object? data, String? error})> call(String fn, Map<String, dynamic> p) async {
    calls.add((fn, p));
    final h = handlers[fn];
    if (h == null) return (data: null, error: 'Fonction $fn non prévue par le test');
    try {
      return (data: h(p), error: null);
    } on String catch (e) {
      return (data: null, error: e);
    }
  }

  List<Map<String, dynamic>> of(String fn) => [for (final c in calls) if (c.$1 == fn) c.$2];
}

Map<String, dynamic> _fiche({bool verified = true, bool mine = false, String? status, bool needs = true}) => {
      'owner_id': 'o1', 'company_name': 'Orange Cameroun', 'sector': 'Télécoms', 'city': 'Douala', 'size': '1000+', 'website': 'https://orange.cm',
      'description': 'Opérateur de télécommunications.', 'founded_year': 1999, 'logo_path': null, 'cover_path': null, 'verified': verified, 'status': status, 'mine': mine,
      'offers': [{'id': 'f1', 'title': 'Stage développeur', 'kind': 'stage', 'location': 'Douala', 'deadline': '2099-12-31'}],
      'contests': [{'id': 'c1', 'title': 'Défi Orange Digital', 'kind': 'contest', 'deadline': '2099-11-30'}],
      'needs': needs ? [{'id': 'n1', 'title': 'Refonte du site', 'budget_min': 100000, 'budget_max': 250000, 'deadline': '30 nov. 2099'}] : null,
      'offers_open': 1, 'contests_open': 1, 'needs_open': needs ? 1 : null, 'recruits': 4,
    };

Map<String, dynamic> _thread({String status = 'quoted', String role = 'requester', bool expired = false, int answers = 1}) => {
      'my_role': role,
      'quote': {
        'id': 'q1', 'requester_id': 'r1', 'provider_id': 'p1', 'brief': 'Un logo pour notre agence', 'budget': 20000, 'deadline': '2 semaines', 'status': status,
        'quote_amount': 18000, 'quote_delay_days': 5, 'quote_message': 'Trois pistes', 'order_number': null, 'created_at': '2026-11-10T10:00:00Z',
        'valid_until': '2099-01-01T00:00:00Z', 'answers': answers, 'listing_title': 'Création de logo', 'requester_name': 'Carl K.', 'provider_name': 'Paul P.', 'expired': expired,
      },
      'can': {
        'write': role != 'staff' && const ['requested', 'quoted', 'accepted'].contains(status),
        'accept': role == 'requester' && status == 'quoted' && !expired,
        'decline': role == 'requester' && status == 'quoted',
        'cancel': role == 'requester' && (status == 'requested' || status == 'quoted'),
        'revise': role == 'provider' && (status == 'requested' || status == 'quoted'),
        'reject': role == 'provider' && (status == 'requested' || status == 'quoted'),
      },
      'messages': [
        {'id': 'm1', 'sender_id': 'r1', 'sender_name': 'Carl K.', 'kind': 'event', 'body': 'Demande de devis envoyée.', 'created_at': '2026-11-10T10:00:00Z', 'mine': role == 'requester'},
        {'id': 'm2', 'sender_id': 'p1', 'sender_name': 'Paul P.', 'kind': 'event', 'body': 'Devis du prestataire : 18 000 FCFA en 5 jour(s).', 'created_at': '2026-11-10T11:00:00Z', 'mine': role == 'provider'},
        {'id': 'm3', 'sender_id': 'p1', 'sender_name': 'Paul P.', 'kind': 'message', 'body': 'Je peux livrer en 5 jours.', 'created_at': '2026-11-10T11:05:00Z', 'mine': role == 'provider'},
      ],
    };

Map<String, dynamic> _talent(int i) => {'id': 't$i', 'name': 'Étudiant $i.', 'name_full': false, 'department': 'Génie informatique', 'institution': 'IUT Douala', 'skills': 'Flutter, Figma', 'city': 'Douala', 'avatar_url': null, 'certified': i.isEven, 'cv_published': false};

Map<String, dynamic> _order(String n, String state, {bool byMe = true}) => {
      'number': '#BE-2026-$n', 'invoice_number': 'FA-2026-$n', 'created_at': '2026-11-12T10:00:00Z', 'paid': state == 'paid', 'cancelled': state == 'cancelled', 'cod': false, 'state': state,
      'total': 18000, 'discount': 0, 'fee': 0, 'method': 'Orange Money', 'buyer_name': 'Fabrice F.', 'by_me': byMe, 'items': [{'title': 'Création de logo', 'qty': 1, 'unit_price': 18000}],
    };

void main() {
  setUpAll(loadAppFonts);
  late _Server srv;
  setUp(() {
    GScreen.mockupFrame = false;
    srv = _Server();
  });
  tearDown(() {
    GScreen.mockupFrame = true;
    Backend.ready = false;
  });

  Future<void> monter(WidgetTester t, Widget page, {double h = 844}) async {
    GAnim.enabled = false;
    t.view.physicalSize = Size(390, h);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const SizedBox());
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(path: '/etudiant/:id', builder: (_, s) => Scaffold(body: Text('profil ${s.pathParameters['id']}'))),
      GoRoute(path: '/entreprise/profil', builder: (_, _) => const Scaffold(body: Text('fiche entreprise'))),
    ]);
    await t.pumpWidget(ProviderScope(overrides: [f4RpcProvider.overrideWithValue(srv.call)], child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
  }

  group('page publique d\'entreprise', () {
    testWidgets('fiche vérifiée : identité, badge réel, compteurs et listes publiques, sans débordement à 390 px', (t) async {
      srv.handlers['company_public'] = (_) => _fiche();
      await monter(t, const CompanyPublicPage(ownerId: 'o1'), h: 1800);
      expect(srv.of('company_public').single['p_owner'], 'o1');
      expect(find.text('Orange Cameroun'), findsWidgets);
      expect(find.text('Entreprise vérifiée'), findsOneWidget);
      expect(find.text('Offres ouvertes'), findsOneWidget);
      expect(find.text('Recrutés'), findsOneWidget);
      expect(find.text('Stage développeur'), findsOneWidget);
      expect(find.text('Défi Orange Digital'), findsOneWidget);
      expect(find.text('Refonte du site'), findsOneWidget);
      expect(find.text('Modifier la fiche'), findsNothing);
      expect(find.byTooltip('Partager la page de l’entreprise'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('visiteur : pas de liste ni de compteur de besoins ; fiche non visible : message honnête, pas de partage', (t) async {
      srv.handlers['company_public'] = (_) => _fiche(needs: false);
      await monter(t, const CompanyPublicPage(ownerId: 'o1'));
      expect(find.text('Besoins ouverts'), findsNothing);
      expect(find.text('Refonte du site'), findsNothing);
      srv.handlers['company_public'] = (_) => null;
      await monter(t, const CompanyPublicPage(ownerId: 'o2'));
      expect(find.textContaining('n’a pas de fiche publique'), findsOneWidget);
      expect(find.byTooltip('Partager la page de l’entreprise'), findsNothing);
      expect(find.text('Entreprise vérifiée'), findsNothing);
    });

    testWidgets('fiche non approuvée vue par son propriétaire : statut réel, page non publique, accès à la modification', (t) async {
      srv.handlers['company_public'] = (_) => _fiche(verified: false, mine: true, status: 'pending');
      await monter(t, const CompanyPublicPage(ownerId: 'o1'));
      expect(find.text('Entreprise vérifiée'), findsNothing);
      expect(find.textContaining('En cours de vérification'), findsOneWidget);
      expect(find.textContaining('visible que de vous'), findsOneWidget);
      expect(find.byTooltip('Partager la page de l’entreprise'), findsNothing);
      await t.ensureVisible(find.text('Modifier la fiche'));
      await t.tap(find.text('Modifier la fiche'));
      await t.pumpAndSettle();
      expect(find.text('fiche entreprise'), findsOneWidget);
    });

    testWidgets('erreur serveur : message clair et bouton Réessayer qui relance la lecture', (t) async {
      srv.handlers['company_public'] = (_) => throw 'Le serveur ne répond pas';
      await monter(t, const CompanyPublicPage(ownerId: 'o1'));
      expect(find.text('Réessayer'), findsOneWidget);
      srv.handlers['company_public'] = (_) => _fiche();
      await t.tap(find.text('Réessayer'));
      await t.pumpAndSettle();
      expect(find.text('Entreprise vérifiée'), findsOneWidget);
      expect(srv.of('company_public').length, 2);
    });

    testWidgets('sans fiche visible, le profil de la personne reste affiché (repli)', (t) async {
      srv.handlers['company_public'] = (_) => null;
      await monter(t, CompanyPublicPage(ownerId: 'o3', fallback: () => const Scaffold(body: Text('profil de la personne'))));
      expect(find.text('profil de la personne'), findsOneWidget);
    });
  });

  group('achats de l\'entreprise', () {
    void serveur({List<Map<String, dynamic>> orders = const []}) {
      srv.handlers['company_billing_context_get'] = (_) => {'owner_id': 'o1', 'forced': false, 'company_name': 'Orange Cameroun'};
      srv.handlers['company_billing_get'] = (_) => {'owner_id': 'o1', 'company_name': 'Orange Cameroun', 'tax_id': 'M01', 'registration_number': 'RC1', 'address': 'Rue 1', 'city': 'Douala', 'email': 'compta@orange.cm', 'my_role': 'finance'};
      srv.handlers['company_orders_list'] = (_) => orders;
    }

    testWidgets('liste réelle : statut, total, facture, auteur ; pas de facture pour une commande annulée ; aucun débordement', (t) async {
      serveur(orders: [_order('0001', 'paid'), _order('0002', 'pending', byMe: false), _order('0003', 'cancelled')]);
      await monter(t, const CompanyPurchasesScreen(), h: 2400);
      expect(find.text('Payée'), findsOneWidget);
      expect(find.text('En attente de paiement'), findsOneWidget);
      expect(find.text('Annulée'), findsOneWidget);
      expect(find.text('Facture FA-2026-0001'), findsOneWidget);
      expect(find.textContaining('Passée par Fabrice F.'), findsOneWidget);
      expect(find.text('Facture (PDF)'), findsNWidgets(2));
      expect(find.textContaining('Facturé à : Orange Cameroun'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('« acheter au nom de l\'entreprise » : l\'interrupteur appelle le serveur et le dit', (t) async {
      serveur();
      srv.handlers['company_billing_context_set'] = (p) => p['p_owner'];
      await monter(t, const CompanyPurchasesScreen());
      expect(find.textContaining('Aucune commande au nom de l’entreprise'), findsOneWidget);
      final sw = find.byType(Switch);
      expect(sw, findsOneWidget);
      expect(t.getSize(find.ancestor(of: sw, matching: find.byType(SizedBox)).first).height, greaterThanOrEqualTo(48));
      await t.tap(sw);
      await t.pumpAndSettle();
      expect(srv.of('company_billing_context_set').single.containsKey('p_owner'), isTrue);
    });

    testWidgets('refus du serveur : message d\'erreur et possibilité de réessayer, jamais une liste vide trompeuse', (t) async {
      serveur();
      srv.handlers['company_orders_list'] = (_) => throw 'Réservé au propriétaire, aux administrateurs et à la finance de l’entreprise';
      await monter(t, const CompanyPurchasesScreen());
      expect(find.textContaining('Réservé au propriétaire'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.textContaining('Aucune commande au nom'), findsNothing);
    });

    testWidgets('identité de facturation : l\'enregistrement envoie NIU, adresse, ville et e-mail', (t) async {
      serveur();
      srv.handlers['company_billing_set'] = (_) => {'company_name': 'Orange Cameroun'};
      await monter(t, const CompanyPurchasesScreen());
      await t.enterText(find.widgetWithText(TextField, 'NIU (numéro d’identifiant unique)'), 'M0123456789');
      await t.scrollUntilVisible(find.text('Enregistrer la facturation'), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Enregistrer la facturation'));
      await t.pumpAndSettle();
      final sent = srv.of('company_billing_set').single['p'] as Map;
      expect(sent['tax_id'], 'M0123456789');
      expect(sent['billing_email'], 'compta@orange.cm');
      expect(sent['billing_city'], 'Douala');
    });
  });

  group('négociation de devis', () {
    void serveur({Map<String, dynamic>? thread}) {
      srv.handlers['quote_thread'] = (_) => thread ?? _thread();
      srv.handlers['quote_message_send'] = (_) => 'm9';
      srv.handlers['decide_quote'] = (p) => p['p_accept'] == true ? 'accepted' : 'declined';
      srv.handlers['cancel_quote'] = (_) => 'cancelled';
      srv.handlers['answer_quote'] = (_) => 'quoted';
      srv.handlers['decline_quote'] = (_) => 'rejected';
    }

    Future<void> ouvrir(WidgetTester t) async {
      await monter(t, Builder(builder: (context) => Consumer(builder: (context, ref, _) => Scaffold(body: Center(child: TextButton(onPressed: () => openQuoteNegotiation(context, ref, {'id': 'q1'}), child: const Text('Ouvrir le devis')))))));
      await t.tap(find.text('Ouvrir le devis'));
      await t.pumpAndSettle();
    }

    testWidgets('demandeur : fil réel (évènements et messages), devis, actions selon le statut', (t) async {
      serveur();
      await ouvrir(t);
      expect(srv.of('quote_thread').single['p_quote'], 'q1');
      expect(find.text('Création de logo'), findsOneWidget);
      expect(find.text('Demande de devis envoyée.'), findsOneWidget);
      expect(find.textContaining('Devis du prestataire : 18 000 FCFA'), findsOneWidget);
      expect(find.text('Je peux livrer en 5 jours.'), findsOneWidget);
      expect(find.text('Accepter ce devis'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
      expect(find.text('Annuler la demande'), findsOneWidget);
      expect(find.text('Modifier mon devis'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('envoi d\'un message : appelle quote_message_send, vide le champ, relit le fil', (t) async {
      serveur();
      await ouvrir(t);
      await t.enterText(find.byType(TextField), 'Pouvez-vous faire un geste ?');
      expect(t.getSize(find.byTooltip('Envoyer')).height, greaterThanOrEqualTo(48));
      await t.tap(find.byTooltip('Envoyer'));
      await t.pumpAndSettle();
      expect(srv.of('quote_message_send').single, {'p_quote': 'q1', 'p_body': 'Pouvez-vous faire un geste ?'});
      expect(srv.of('quote_thread').length, greaterThanOrEqualTo(2));
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
    });

    testWidgets('accepter : confirmation obligatoire, puis decide_quote avec le montant vu ; refus du serveur affiché sans faux succès', (t) async {
      serveur();
      await ouvrir(t);
      await t.tap(find.text('Accepter ce devis'));
      await t.pumpAndSettle();
      expect(find.text('Accepter ce devis ?'), findsOneWidget);
      expect(srv.of('decide_quote'), isEmpty);
      srv.handlers['decide_quote'] = (_) => throw 'Le prestataire a modifié son devis : relisez le nouveau montant avant d’accepter';
      await t.tap(find.text('Accepter ce montant'));
      await t.pumpAndSettle();
      expect(srv.of('decide_quote').single, {'p_id': 'q1', 'p_accept': true, 'p_amount': 18000});
      expect(find.textContaining('Devis accepté. Le prestataire est prévenu.'), findsNothing);
    });

    testWidgets('prestataire : contre-proposition validée avant envoi, puis answer_quote avec prix, délai et message', (t) async {
      serveur(thread: _thread(role: 'provider'));
      await ouvrir(t);
      expect(find.text('Accepter ce devis'), findsNothing);
      expect(find.text('Modifier mon devis'), findsOneWidget);
      expect(find.text('Décliner la demande'), findsOneWidget);
      await t.tap(find.text('Modifier mon devis'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Montant (FCFA)'), 'abc');
      await t.tap(find.text('Envoyer').last);
      await t.pumpAndSettle();
      expect(srv.of('answer_quote'), isEmpty);
      expect(find.textContaining('Montant illisible'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Montant (FCFA)'), '16000');
      await t.enterText(find.widgetWithText(TextField, 'Délai (jours)'), '3');
      await t.enterText(find.widgetWithText(TextField, 'Message (facultatif)'), 'Geste commercial');
      await t.tap(find.text('Envoyer').last);
      await t.pumpAndSettle();
      expect(srv.of('answer_quote').single, {'p_id': 'q1', 'p_amount': 16000, 'p_delay_days': 3, 'p_message': 'Geste commercial'});
    });

    testWidgets('devis clos : plus de champ de message ni d\'action, mention claire ; lecture seule pour l\'administration', (t) async {
      serveur(thread: _thread(status: 'cancelled'));
      await ouvrir(t);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('clôturée'), findsOneWidget);
      expect(find.text('Accepter ce devis'), findsNothing);
      serveur(thread: _thread(role: 'staff'));
      await ouvrir(t);
      expect(find.textContaining('Lecture seule'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('devis introuvable : erreur du serveur affichée avec Réessayer', (t) async {
      srv.handlers['quote_thread'] = (_) => throw 'Demande introuvable';
      await ouvrir(t);
      expect(find.text('Demande introuvable'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });

  group('recherche de talents', () {
    List<Map<String, dynamic>> page(int from, int n) => [for (var i = from; i < from + n; i++) _talent(i)];

    void serveur({int total = 45, bool locked = false}) {
      srv.handlers['talents_search'] = (p) {
        if (locked) return {'total': 0, 'items': [], 'locked': true, 'reason': 'Votre entreprise doit être vérifiée par l’administrateur.', 'limit': 20, 'offset': 0};
        final off = p['p_offset'] as int;
        final q = (p['p_query'] as String).toLowerCase();
        if (q == 'zzz') return {'total': 0, 'items': [], 'locked': false, 'limit': 20, 'offset': 0};
        return {'total': total, 'items': page(off, (total - off).clamp(0, 20)), 'locked': false, 'limit': 20, 'offset': off};
      };
    }

    Future<void> panneau(WidgetTester t) => monter(t, const Scaffold(body: Padding(padding: EdgeInsets.all(16), child: TalentSearchPanel())));

    testWidgets('première page, compteur réel et « Voir plus » sans limite de 12 : la page suivante est demandée avec le bon décalage', (t) async {
      serveur();
      await panneau(t);
      expect(srv.of('talents_search').first['p_limit'], 20);
      expect(find.text('45 talents correspondent'), findsOneWidget);
      expect(find.text('Étudiant 0.'), findsOneWidget);
      await t.scrollUntilVisible(find.textContaining('Voir plus'), 300, scrollable: find.byType(Scrollable).last);
      await t.tap(find.textContaining('Voir plus'));
      await t.pumpAndSettle();
      expect(srv.of('talents_search').last['p_offset'], 20);
      expect(t.takeException(), isNull);
    });

    testWidgets('recherche active avec délai : un seul appel par saisie, requête transmise ; état vide honnête avec effacement', (t) async {
      serveur();
      await panneau(t);
      final avant = srv.of('talents_search').length;
      await t.enterText(find.byType(TextField).first, 'zzz');
      await t.pump(const Duration(milliseconds: 100));
      expect(srv.of('talents_search').length, avant);
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(srv.of('talents_search').length, avant + 1);
      expect(srv.of('talents_search').last['p_query'], 'zzz');
      expect(find.textContaining('Aucun talent ne correspond'), findsOneWidget);
      await t.tap(find.text('Effacer la recherche et les filtres'));
      await t.pumpAndSettle();
      expect(srv.of('talents_search').last['p_query'], '');
      expect(find.text('45 talents correspondent'), findsOneWidget);
    });

    testWidgets('filtres réels : filière et compétences envoyées au serveur', (t) async {
      serveur();
      await panneau(t);
      await t.tap(find.byTooltip('Filtres : filière et compétences'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'Ajouter une compétence (Flutter, Figma…)'), 'Flutter');
      await t.tap(find.byTooltip('Ajouter la compétence'));
      await t.pumpAndSettle();
      expect(srv.of('talents_search').last['p_skills'], ['Flutter']);
      expect(find.byType(InputChip), findsOneWidget);
    });

    testWidgets('profil et vivier : « Voir le profil » ouvre /etudiant/<id> ; étoile et cibles d\'au moins 48 dp', (t) async {
      serveur();
      await panneau(t);
      final etoile = find.byTooltip('Enregistrer dans une liste du vivier').first;
      expect(t.getSize(etoile).width, greaterThanOrEqualTo(48));
      expect(t.getSize(etoile).height, greaterThanOrEqualTo(48));
      expect(t.getSize(find.text('Voir le profil').first).height, greaterThan(0));
      expect(t.getSize(find.ancestor(of: find.text('Voir le profil').first, matching: find.byType(TextButton)).first).height, greaterThanOrEqualTo(48));
      await t.tap(find.text('Voir le profil').first);
      await t.pumpAndSettle();
      expect(find.text('profil t0'), findsOneWidget);
    });

    testWidgets('entreprise non vérifiée : aucun talent, raison du serveur et lien vers la fiche ; erreur : Réessayer', (t) async {
      serveur(locked: true);
      await panneau(t);
      expect(find.textContaining('réservée aux entreprises vérifiées'), findsOneWidget);
      expect(find.textContaining('doit être vérifiée par l’administrateur'), findsOneWidget);
      expect(find.byTooltip('Enregistrer dans une liste du vivier'), findsNothing);
      await t.tap(find.text('Compléter la fiche entreprise'));
      await t.pumpAndSettle();
      expect(find.text('fiche entreprise'), findsOneWidget);
      srv.handlers['talents_search'] = (_) => throw 'Le service ne répond pas pour le moment.';
      await panneau(t);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
