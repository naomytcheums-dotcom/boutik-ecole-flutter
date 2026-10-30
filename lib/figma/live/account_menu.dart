import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'access.dart';
import 'auth.dart';
import 'espace.dart';
import 'feedback.dart';
import 'services.dart';

const _st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF111015));

/// Une entrée du menu du compte : un écran (ouvert si le rôle l'autorise) ou une action.
class _Entry {
  const _Entry(this.label, {this.screen, this.action, this.roles});
  final String label;
  final String? screen;
  final Future<void> Function(BuildContext, WidgetRef)? action;
  final Set<String>? roles; // null = tous les rôles connectés
}

class _Group {
  const _Group(this.title, this.entries);
  final String title;
  final List<_Entry> entries;
}

Future<void> _devis(BuildContext c, WidgetRef r) => quotesDialog(c, r);
Future<void> _reclamations(BuildContext c, WidgetRef r) => claimsDialog(c, r);

final _groups = <_Group>[
  const _Group('Mes achats', [
    _Entry('Mes commandes', screen: '45'),
    _Entry('Mes favoris', screen: '25'),
    _Entry('Mes collections', screen: '25b'),
    _Entry('Mes adresses', screen: '27'),
    _Entry('Mes devis', action: _devis),
    _Entry('Mes réclamations', action: _reclamations),
    _Entry('Comparer des offres', screen: '26'),
  ]),
  const _Group('Découvrir et participer', [
    _Entry('Événements', screen: '100'),
    _Entry('Hackathons et concours', screen: '160'),
    _Entry('Opportunités pour moi', screen: '151'),
    _Entry('Communauté et vitrine', screen: '103'),
    _Entry('Départements', screen: '214'),
    _Entry('Marché des vœux', screen: '216'),
    _Entry('Ateliers en direct', screen: '223'),
    _Entry('Reels et lives', screen: '245'),
    _Entry('Défis et récompenses', screen: '253'),
    _Entry('Parrainer et gagner', screen: '240'),
    _Entry('Missions sur mesure', screen: '191'),
    _Entry('Impact de Boutik-École', screen: '238'),
  ]),
  const _Group('Communication', [
    _Entry('Messages', screen: '52'),
    _Entry('Notifications', screen: '50'),
    _Entry('Alertes et opportunités', screen: '155'),
  ]),
  const _Group('Espace étudiant-vendeur', [
    _Entry('Tableau de bord', screen: '57', roles: {'student', 'dept', 'admin'}),
    _Entry('Mes annonces', screen: '58', roles: {'student', 'dept', 'admin'}),
    _Entry('Commandes reçues', screen: '63', roles: {'student', 'dept', 'admin'}),
    _Entry('Stocks', screen: '62', roles: {'student', 'dept', 'admin'}),
    _Entry('Revenus', screen: '66', roles: {'student', 'dept', 'admin'}),
    _Entry('Statistiques', screen: '67', roles: {'student', 'dept', 'admin'}),
    _Entry('Mes documents', screen: '73', roles: {'student', 'dept', 'admin'}),
    _Entry('Publier un service', screen: '59', roles: {'student', 'dept', 'admin'}),
    _Entry('Conformité du compte', screen: '69', roles: {'student', 'dept', 'admin'}),
    _Entry('Opportunités', screen: '75', roles: {'student', 'dept', 'admin'}),
    _Entry('Mon CV vivant', screen: '227', roles: {'student', 'dept', 'admin'}),
    _Entry('Tableau de bord du studio', screen: 'D1', roles: {'student', 'dept', 'admin'}),
    _Entry('Connecter mes outils', screen: 'P5', roles: {'student', 'dept', 'admin'}),
    _Entry('Aller en direct', screen: 'L1', roles: {'student', 'dept', 'admin'}),
    _Entry('Programmer un live', screen: '224', roles: {'student', 'dept', 'admin'}),
    _Entry('Lancer une campagne de financement', screen: '84', roles: {'student', 'dept', 'admin'}),
    _Entry('Publier un vœu', screen: '218', roles: {'student', 'dept', 'admin'}),
    _Entry('Registre des innovations', screen: '87', roles: {'student', 'dept', 'admin'}),
    _Entry('Kit à partager', screen: '242', roles: {'student', 'dept', 'admin'}),
  ]),
  const _Group('Espace entreprise', [
    _Entry('Tableau de bord entreprise', screen: '187', roles: {'company', 'admin'}),
    _Entry('Publier un besoin', screen: '90', roles: {'company', 'admin'}),
    _Entry('Historique des besoins', screen: '99', roles: {'company', 'admin'}),
    _Entry('Propositions reçues', screen: '93', roles: {'company', 'admin'}),
    _Entry('Rechercher des talents', screen: '91', roles: {'company', 'admin'}),
    _Entry('Défis d’innovation', screen: '96', roles: {'company', 'admin'}),
    _Entry('Espace projet', screen: '285', roles: {'company', 'admin'}),
    _Entry('Accueil B2B', screen: '262', roles: {'company', 'admin'}),
  ]),
  const _Group('Administration', [
    _Entry('Console du département', screen: '108', roles: {'dept', 'admin'}),
    _Entry('Registre des certificats', screen: '283', roles: {'dept', 'admin'}),
    _Entry('Catalogue du département', screen: '288', roles: {'dept', 'admin'}),
    _Entry('Espace jury', screen: '178', roles: {'dept', 'admin'}),
    _Entry('Rapport sponsors', screen: '239', roles: {'direction', 'dept', 'admin'}),
    _Entry('Administration institutionnelle', screen: '117', roles: {'direction', 'admin'}),
    _Entry('Administration globale', screen: '127', roles: {'admin'}),
    _Entry('Rôles et permissions', screen: '180', roles: {'admin'}),
    _Entry('Rôles et périmètres', screen: '281', roles: {'admin'}),
    _Entry('Intégrations', screen: '280', roles: {'admin'}),
    _Entry('Pages éditoriales', screen: '264', roles: {'admin'}),
    _Entry('Innovation Radar', screen: '269', roles: {'admin'}),
    _Entry('Finance', screen: '139', roles: {'finance', 'direction', 'admin'}),
    _Entry('Registre financier', screen: '284', roles: {'finance', 'direction', 'admin'}),
    _Entry('Kiosques et support', screen: '145', roles: {'support', 'admin'}),
    _Entry('Supervision des bornes', screen: '277', roles: {'support', 'admin'}),
  ]),
  const _Group('Mon compte', [
    _Entry('Paramètres', screen: '148_1'),
    _Entry('Centre de confiance', screen: '174'),
    _Entry('Aide et support', screen: '49'),
    _Entry('Guide d’utilisation', screen: '179'),
    _Entry('Canaux et notifications', screen: '236'),
    _Entry('Préférences d’alertes', screen: '156'),
    _Entry('Mon espace client', screen: '261'),
    _Entry('Mes données et confidentialité', screen: '273'),
    _Entry('Vérification en 2 étapes', screen: '272'),
    _Entry('Centre de sécurité', screen: '148_2'),
    _Entry('Économie de données', screen: '184'),
    _Entry('Conditions générales', screen: '274'),
  ]),
];

/// Entrées du menu visibles pour un rôle : (libellé, écran ou null pour une action).
List<(String, String?)> accountMenuEntries(String role) => [
      for (final g in _groups)
        for (final e in g.entries)
          if (e.roles == null || e.roles!.contains(role)) (e.label, e.screen),
    ];

/// Menu du compte (écran 10) : les accès réels de la personne, selon son rôle ; rien n'est affiché si le rôle n'y a pas droit.
Future<void> accountMenu(BuildContext context, WidgetRef ref) {
  final role = roleKey(ref.read(authProvider).current);
  final visible = [
    for (final g in _groups)
      _Group(g.title, [
        for (final e in g.entries)
          if (e.roles == null ? true : e.roles!.contains(role)) e,
      ]),
  ].where((g) => g.entries.isNotEmpty).toList();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 420),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.82),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), children: [
          Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFFDAD5E4), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('Mon compte · ${roleNames[role] ?? ''}', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
          for (final g in visible) ...[
            const SizedBox(height: 14),
            Text(g.title, style: _st.copyWith(fontSize: 12, color: const Color(0xFF66636E), fontWeight: FontWeight.w600)),
            for (final e in g.entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.label, style: _st.copyWith(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF66636E)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (e.screen != null) {
                    gOpen(context, e.screen!);
                  } else {
                    e.action?.call(context, ref);
                  }
                },
              ),
          ],
          const Divider(height: 26),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Toutes les rubriques', style: _st.copyWith(color: const Color(0xFF5A3FE0), fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              gEspace(context);
            },
          ),
        ]),
      ),
    ),
  );
}
