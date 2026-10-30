import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import '../../features/screens.dart';
import 'access.dart';
import 'auth.dart';

/// « Mes rubriques » : point d'entrée de toutes les sections de l'application, filtré par rôle.
/// Chaque ligne ouvre l'écran correspondant ; les droits sont appliqués par le routeur (AccessGuard) comme pour tout accès.
class Rubrique {
  const Rubrique(this.code, this.titre, this.debut, this.fin);
  final String code, titre;
  final int debut, fin;
}

/// Sections du projet (numérotation des maquettes). Un écran appartient à la section qui contient son numéro.
const rubriques = <Rubrique>[
  Rubrique('A', 'Démarrage et navigation', 1, 10),
  Rubrique('B', 'Compte et authentification', 11, 18),
  Rubrique('C', 'Découverte et achats', 19, 31),
  Rubrique('D', 'Fiches produits et services', 32, 39),
  Rubrique('E', 'Commandes et livraison', 40, 49),
  Rubrique('F', 'Messages et communication', 50, 56),
  Rubrique('G', 'Espace étudiant-vendeur', 57, 69),
  Rubrique('H', 'Talents étudiants', 70, 77),
  Rubrique('I', 'Projets et financement', 78, 87),
  Rubrique('J', 'Espace entreprise', 88, 99),
  Rubrique('K', 'Événements et communautés', 100, 107),
  Rubrique('L', 'Département', 108, 116),
  Rubrique('M', 'Administration institutionnelle', 117, 126),
  Rubrique('N', 'Administration globale', 127, 138),
  Rubrique('O', 'Finance', 139, 144),
  Rubrique('P', 'Kiosques et support', 145, 147),
  Rubrique('Q', 'Paramètres et états du système', 148, 150),
  Rubrique('S', 'Opportunités et alertes', 151, 159),
  Rubrique('T', 'Hackathons et concours', 160, 169),
  Rubrique('U', 'Confiance, sécurité et partage', 170, 174),
  Rubrique('V', 'Onboarding et rôles', 175, 181),
  Rubrique('W', 'Faible connexion et langues', 182, 186),
  Rubrique('X', 'Web entreprise', 187, 190),
  Rubrique('Y', 'Missions sur mesure', 191, 205),
  Rubrique('AA', 'Borne phygitale', 206, 210),
  Rubrique('AD', 'Innovations', 211, 229),
  Rubrique('AI', 'Kéla et canaux', 230, 237),
  Rubrique('AM', 'Cercle, parrainage et publication', 238, 255),
  Rubrique('Z', 'Services complémentaires', 256, 999),
];

/// Écrans dont l'identifiant ne commence pas par un numéro (studio créateur, assistants, variantes).
const _autres = Rubrique('S+', 'Studio créateur et assistants', -1, -1);

Rubrique rubriqueDe(String id) {
  final m = RegExp(r'^\d+').firstMatch(id);
  if (m == null) return _autres;
  final n = int.parse(m.group(0)!);
  for (final r in rubriques) {
    if (n >= r.debut && n <= r.fin) return r;
  }
  return rubriques.last;
}

int _cle(String id) {
  final m = RegExp(r'^\d+').firstMatch(id);
  return m == null ? 100000 : int.parse(m.group(0)!);
}

/// Rubriques et écrans ouverts au compte (null = visiteur), triés par numéro.
Map<Rubrique, List<(String, String)>> rubriquesPour(Account? a, {String filtre = ''}) {
  final q = filtre.trim().toLowerCase();
  final out = <Rubrique, List<(String, String)>>{};
  for (final s in allScreens) {
    if (!canOpen(a, s.id)) continue;
    if (q.isNotEmpty && !s.title.toLowerCase().contains(q) && !s.id.toLowerCase().contains(q)) continue;
    out.putIfAbsent(rubriqueDe(s.id), () => []).add((s.id, s.title));
  }
  for (final l in out.values) {
    l.sort((x, y) => _cle(x.$1) != _cle(y.$1) ? _cle(x.$1).compareTo(_cle(y.$1)) : x.$1.compareTo(y.$1));
  }
  return out;
}

class EspaceScreen extends ConsumerStatefulWidget {
  const EspaceScreen({super.key});
  @override
  ConsumerState<EspaceScreen> createState() => _EspaceScreenState();
}

class _EspaceScreenState extends ConsumerState<EspaceScreen> {
  String _q = '';

  TextStyle _t(double size, FontWeight w, [Color c = const Color(0xFF111015)]) =>
      TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authProvider).current;
    final data = rubriquesPour(account, filtre: _q);
    final order = [...rubriques, _autres];
    final total = data.values.fold<int>(0, (a, l) => a + l.length);
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, .5, 1]),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => context.canPop() ? context.pop() : context.go(screenPath('03')),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: const Color(0x8CFFFFFF), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                        alignment: Alignment.center,
                        child: Text('‹', style: _t(26, FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text('Mes rubriques', style: _t(22, FontWeight.w700))),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    '${roleNames[roleKey(account)] ?? 'Visiteur'} · $total écran${total > 1 ? 's' : ''} accessible${total > 1 ? 's' : ''}',
                    style: _t(12.5, FontWeight.w500, const Color(0xFF66636E)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v),
                    style: _t(14, FontWeight.w500),
                    cursorColor: const Color(0xFF111015),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une rubrique ou un écran',
                      hintStyle: _t(14, FontWeight.w500, const Color(0xFF9A98A3)),
                      filled: true,
                      fillColor: const Color(0xB2FFFFFF),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
                    children: [
                      if (total == 0) Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('Aucun résultat', style: _t(14, FontWeight.w500, const Color(0xFF66636E))))),
                      for (final r in order)
                        if (data[r] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Container(
                              decoration: BoxDecoration(color: const Color(0xB2FFFFFF), borderRadius: BorderRadius.circular(22), border: Border.all(color: Colors.white, width: 1.5)),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  key: PageStorageKey('rub-${r.code}-${_q.isEmpty}'),
                                  initiallyExpanded: _q.isNotEmpty,
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                                  childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                                  iconColor: const Color(0xFF111015),
                                  collapsedIconColor: const Color(0xFF111015),
                                  title: Text(r.titre, style: _t(14.5, FontWeight.w700)),
                                  subtitle: Text('${data[r]!.length} écran${data[r]!.length > 1 ? 's' : ''}', style: _t(11.5, FontWeight.w500, const Color(0xFF66636E))),
                                  children: [
                                    for (final (id, titre) in data[r]!)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () => context.push(screenPath(id)),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                          child: Row(children: [
                                            SizedBox(width: 46, child: Text(id, style: _t(12, FontWeight.w600, const Color(0xFF66636E)))),
                                            Expanded(child: Text(titre, style: _t(13.5, FontWeight.w500))),
                                            Text('›', style: _t(18, FontWeight.w500, const Color(0xFF66636E))),
                                          ]),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
