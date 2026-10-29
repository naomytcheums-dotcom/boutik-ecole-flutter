import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo/section_a_demo.dart';
import '../../data/repositories/repositories.dart' show cartProvider, CartNotifier;
import '../gen.dart';
import '../nav.dart';
import 'store.dart';

/// 06 · Panier — partie vivante : lignes du panier (quantités, suppression) et totaux.
/// Les coordonnées reprennent exactement celles de la maquette Figma (nœud 14:2).
const _ink = Color(0xFF111015);
const _grey = Color(0xFF66636E);
const _violet = Color(0xFF5A3FE0);
const _v = 'assets/figma/v';
const _rowH = 165.56;
const _top = 129.0;

const _figmaImages = {
  'Ordinateur portable prototype': 'assets/figma/img/3a64dd639155a57b27bff9e6c8c6d8fa81362afc.png',
  'Lampe en bois recyclé': 'assets/figma/img/3d6379dbe0e12637d54ca9d283be8cb419701599.png',
  'Logo et identité visuelle': 'assets/figma/img/abbe1a61d7955c52cdd31224bc1569ab44582797.png',
};

List<Widget> liveCart(BuildContext context, WidgetRef ref) => [
      Positioned.fill(child: Consumer(builder: (context, ref, _) => _Cart(ref: ref))),
    ];

class _Cart extends StatelessWidget {
  const _Cart({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final t = ref.watch(totalsProvider);
    final cart = ref.read(cartProvider.notifier);
    final listH = lines.length * _rowH;
    return Stack(clipBehavior: Clip.none, children: [
      // Liste défilante (région de la maquette entre l'en-tête et les totaux)
      Positioned(
        left: 0,
        top: _top,
        width: 390,
        height: 626 - _top,
        child: lines.isEmpty
            ? const Center(child: Text('Votre panier est vide', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: _grey, inherit: false, textBaseline: TextBaseline.alphabetic)))
            : SingleChildScrollView(
                child: SizedBox(
                  width: 390,
                  height: listH,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (var i = 0; i < lines.length; i++) ..._row(context, i, lines[i], cart),
                  ]),
                ),
              ),
      ),
      // Totaux (positions fixes de la maquette)
      gP(25.64, 625.94, 337.37, 0.677, gBox(color: const Color(0xFFF2EFF6))),
      gP(28.339, 642.624, 59, 14, gText('Sous-total', 11.471, _grey)),
      gP(150, 642.624, 211.7, 14, gText(fcfa(t.subtotal), 11.471, _violet, weight: 600, align: TextAlign.right, wrap: true)),
      gP(28.339, 668.338, 48, 14, gText('Livraison', 11.471, _grey)),
      gP(150, 668.338, 211.7, 14, gText(t.fee == 0 ? 'Gratuit' : fcfa(t.fee), 11.471, _violet, weight: 600, align: TextAlign.right, wrap: true)),
      gP(25.64, 695.639, 337.37, 0.677, gBox(color: const Color(0xFFF2EFF6))),
      gP(26.99, 706.793, 40, 21, gText('Total', 16.869, _ink, weight: 700)),
      gP(160, 707.97, 204.4, 20, gText(fcfa(t.total), 15.519, _ink, weight: 700, align: TextAlign.right, wrap: true)),
      gP(
        25.64, 748.421, 338.72, 46.692,
        gBox(color: _ink, shadows: const [BoxShadow(color: Color(0x29122640), offset: Offset(0, 5), blurRadius: 12)], radii: const [22.941, 22.941, 22.941, 22.941]),
        tap: () => lines.isEmpty ? gToast(context, 'Ajoutez un article pour commander') : gOpen(context, '07'),
      ),
      gP(121.68, 764.605, 121, 15, gText('Passer la commande', 12.145, Colors.white, weight: 600, align: TextAlign.center)),
      gP(249.662, 769.105, 13.478, 6, gImg('$_v/120a13c718a727.svg')),
      gP(253.401, 765.366, 9.739, 13.478, gImg('$_v/a0ea9f8dac1b8e.svg')),
    ]);
  }

  List<Widget> _row(BuildContext context, int i, CartLine l, CartNotifier cart) {
    final y = i * _rowH; // relatif à la liste (le haut de la liste = 129)
    final img = _figmaImages[l.title] ?? l.image;
    Widget trash(double dy) => gP(
          330, y + dy - 10, 40, 40,
          Stack(children: [
            Positioned(left: 11.7, top: 10, width: 19.663, height: 6, child: gImg('$_v/59109a95c069c4.svg')),
            Positioned(left: 13.2, top: 10, width: 16.627, height: 18.145, child: gImg('$_v/c1bf1b488ab3d9.svg')),
            Positioned(left: 15.5, top: 6.96, width: 12.073, height: 9.036, child: gImg('$_v/027351e4414ffe.svg')),
            Positioned(left: 17.0, top: 13.8, width: 6, height: 10.554, child: gImg('$_v/26cafc420f6f00.svg')),
            Positioned(left: 20.1, top: 13.8, width: 6, height: 10.554, child: gImg('$_v/26cafc420f6f00.svg')),
          ]),
          tap: () {
            cart.remove(i);
            gToast(context, '« ${l.title} » retiré du panier');
          },
          sound: 'pop',
        );
    return [
      gP(25.64, y, 337.37, 0.677, gBox(color: const Color(0xFFF2EFF6))),
      gP(
        25.64, y + 13.5, 105.26, 125.9,
        gBox(image: img, fit: BoxFit.cover, shadows: const [BoxShadow(color: Color(0x2E122640), offset: Offset(0, 4), blurRadius: 10)], radii: const [14.844, 14.844, 14.844, 14.844]),
        tap: () => gOpen(context, '05'),
      ),
      gP(144.4, y + 22.6, 180, 21, gText(l.title, 14.17, _ink, weight: 700, lh: 20.242, wrap: true, maxLines: 1)),
      gP(144.4, y + 49.8, 180, 14, gText(l.department.startsWith('Département') ? l.department : 'Département : ${l.department}', 10.796, _grey)),
      gP(144.4, y + 77.3, 160, 16, gText(fcfa(l.price * l.qty), 12.82, _violet, weight: 600)),
      gP(144.4, y + 111, 107.284, 27.068, gBox(color: const Color(0xFFF2EFF6), radii: const [13.495, 13.495, 13.495, 13.495])),
      gP(147.093, y + 113.1, 22.941, 22.941, gBox(color: const Color(0xFFE4E8EE), oval: true), tap: () => cart.setQty(i, l.qty - 1), sound: 'tick'),
      gP(226.038, y + 113.1, 22.941, 22.941, gBox(color: const Color(0xFFE4E8EE), oval: true), tap: () => cart.setQty(i, l.qty + 1), sound: 'tick'),
      gP(152.218, y + 121.5, 12.691, 6, gImg('$_v/139c833073ebb8.svg')),
      gP(170, y + 117, 56, 15, gText('${l.qty}', 12.145, _ink, weight: 600, align: TextAlign.center, wrap: true)),
      gP(231.163, y + 121.5, 12.691, 6, gImg('$_v/139c833073ebb8.svg')),
      gP(234.509, y + 118.2, 6, 12.691, gImg('$_v/bf778f966dc21b.svg')),
      trash(25.6),
      trash(117.6),
    ];
  }
}
