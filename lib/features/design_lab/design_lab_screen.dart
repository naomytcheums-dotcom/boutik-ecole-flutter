import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import '../../core/router/screen_entry.dart';
import '../screens.dart';

/// Nouvelle direction visuelle (proposition, 01/11) : bannières d'en-tête (« hero ») de chaque section et pieds de page,
/// plus vifs que les maquettes actuelles. Page hors des 315 écrans : rien n'est modifié tant que le propriétaire n'a pas validé.

/// Palette « peps » : les couleurs de la marque, saturées (bleu nuit, ambre, orange, violet, menthe, corail, ciel).
class Peps {
  static const nuit = Color(0xFF0E1A3A);
  static const ambre = Color(0xFFFFB300);
  static const orange = Color(0xFFFF6A1A);
  static const violet = Color(0xFF6A3DFF);
  static const menthe = Color(0xFF19D3A2);
  static const corail = Color(0xFFFF3D6E);
  static const ciel = Color(0xFF1EA7FF);

  static const gradients = <List<Color>>[
    [violet, corail],
    [orange, ambre],
    [ciel, violet],
    [menthe, ciel],
    [corail, orange],
    [nuit, violet],
    [violet, menthe],
  ];
}

class DesignLabScreen extends StatefulWidget {
  const DesignLabScreen({super.key});

  @override
  State<DesignLabScreen> createState() => _DesignLabScreenState();
}

class _DesignLabScreenState extends State<DesignLabScreen> {
  bool _compare = true;

  /// Sections de l'application (dans l'ordre du catalogue) et leurs écrans.
  List<(String, List<ScreenEntry>)> get _sections {
    final m = <String, List<ScreenEntry>>{};
    for (final s in allScreens) {
      (m[s.section] ??= []).add(s);
    }
    return [for (final e in m.entries) (e.key, e.value)];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FF),
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: HeroBanner(
            title: 'Nouvelle direction visuelle',
            subtitle: 'Bannières et pieds de page plus vifs pour les ${sections.length} sections et les ${allScreens.length} écrans · proposition à valider',
            colors: const [Peps.violet, Peps.corail, Peps.orange],
            cta: 'Revenir à l’application',
            onCta: () => context.go(screenPath('03')),
            height: 300,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              const Expanded(child: Text('Comparer avec le rendu actuel', style: TextStyle(fontWeight: FontWeight.w600))),
              Switch(value: _compare, activeThumbColor: Peps.violet, onChanged: (v) => setState(() => _compare = v)),
            ]),
          ),
        ),
        SliverList.builder(
          itemCount: sections.length,
          itemBuilder: (context, i) {
            final (name, screens) = sections[i];
            final g = Peps.gradients[i % Peps.gradients.length];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${i + 1}. $name · ${screens.length} écran${screens.length > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4A4854))),
                const SizedBox(height: 8),
                if (_compare) ...[
                  _CurrentHero(title: screens.first.title),
                  const SizedBox(height: 6),
                  const Text('Proposé', style: TextStyle(fontSize: 11, color: Color(0xFF66636E))),
                  const SizedBox(height: 6),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: HeroBanner(
                    title: screens.first.title,
                    subtitle: name,
                    colors: g,
                    cta: 'Voir l’écran',
                    onCta: () => context.push(screenPath(screens.first.id)),
                  ),
                ),
              ]),
            );
          },
        ),
        const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 8), child: Text('Pied de page mobile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))),
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: PepsTabBar())),
        const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.fromLTRB(20, 24, 20, 8), child: Text('Pied de page web', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)))),
        const SliverToBoxAdapter(child: PepsWebFooter()),
      ]),
    );
  }
}

/// Rendu actuel (pâle) : dégradé crème et lavande, texte sombre — pour comparaison.
class _CurrentHero extends StatelessWidget {
  const _CurrentHero({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
        height: 96,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFFF5F0E8), Color(0xFFEFE9F4), Color(0xFFF7E9DB)]),
        ),
        alignment: Alignment.centerLeft,
        child: Text('Actuel · $title', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111015))),
      );
}

/// Bannière d'en-tête proposée : dégradé saturé, formes lumineuses, titre blanc, appel à l'action contrasté.
class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key, required this.title, required this.subtitle, required this.colors, required this.cta, required this.onCta, this.height = 200});
  final String title, subtitle, cta;
  final List<Color> colors;
  final VoidCallback onCta;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors))),
          ),
          Positioned(right: -40, top: -50, child: _Glow(size: 200, color: Colors.white.withValues(alpha: 0.22))),
          Positioned(left: -30, bottom: -60, child: _Glow(size: 170, color: Peps.ambre.withValues(alpha: 0.35))),
          Positioned(right: 30, bottom: 26, child: _Glow(size: 54, color: Colors.white.withValues(alpha: 0.30))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
                child: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.1)),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onCta,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    color: Peps.nuit,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Peps.nuit.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(cta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, color: Peps.ambre, size: 18),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
}

/// Barre d'onglets proposée : fond bleu nuit, bouton central en dégradé orange-corail, onglet actif souligné d'ambre.
class PepsTabBar extends StatelessWidget {
  const PepsTabBar({super.key});
  @override
  Widget build(BuildContext context) {
    Widget tab(IconData i, String l, {bool active = false}) => Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, color: active ? Peps.ambre : Colors.white70),
          const SizedBox(height: 3),
          Text(l, style: TextStyle(color: active ? Peps.ambre : Colors.white70, fontSize: 10.5, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
          const SizedBox(height: 3),
          Container(width: 18, height: 3, decoration: BoxDecoration(color: active ? Peps.ambre : Colors.transparent, borderRadius: BorderRadius.circular(2))),
        ]);
    return Container(
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Peps.nuit,
        borderRadius: BorderRadius.circular(38),
        boxShadow: [BoxShadow(color: Peps.violet.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        tab(Icons.search_rounded, 'Explorer', active: true),
        tab(Icons.chat_bubble_outline_rounded, 'Messages'),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Peps.orange, Peps.corail])),
          child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
        ),
        tab(Icons.shopping_bag_outlined, 'Panier'),
        tab(Icons.person_outline_rounded, 'Profil'),
      ]),
    );
  }
}

/// Pied de page web proposé : bleu nuit, liseré ambre, colonnes claires.
class PepsWebFooter extends StatelessWidget {
  const PepsWebFooter({super.key});
  @override
  Widget build(BuildContext context) {
    Widget col(String t, List<String> l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(color: Peps.ambre, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final x in l) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(x, style: const TextStyle(color: Colors.white70))),
        ]);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Peps.nuit, Color(0xFF1B1050)]),
        border: Border(top: BorderSide(color: Peps.ambre, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Boutik-École', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Les productions et l’expertise des étudiants de l’IUT de Douala', style: TextStyle(color: Colors.white70)),
        const SizedBox(height: 20),
        Wrap(spacing: 40, runSpacing: 20, children: [
          col('Boutique', ['Produits', 'Services', 'Missions sur mesure']),
          col('Communauté', ['Talents', 'Concours', 'Reels']),
          col('Aide', ['Guide', 'Support', 'Confidentialité']),
        ]),
        const SizedBox(height: 20),
        Container(height: 1, color: Colors.white24),
        const SizedBox(height: 12),
        const Text('© 2026 Boutik-École · IUT de Douala', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    );
  }
}
