import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'store.dart';

/// 09 · Suivi de commande — frise des 4 étapes qui suit l'état réel de la commande.
const _v = 'assets/figma/v';
const _cx = [56.5, 156.0, 251.5, 338.5];
const _cy = 222.5;

const _icons = <List<(double, double, double, double, String)>>[
  [(47.036, 215.266, 18.158, 14.359, '7ae4e203268ca9')],
  [(144.828, 211.934, 21.782, 20.906, '45dda349ab79b7'), (144.828, 216.318, 21.782, 6, 'b1f5a12a829132'), (150.089, 218.948, 11.261, 10.384, '10f3d4a53580fd')],
  [
    (240.516, 213.746, 15.119, 16.638, '533640c4bbfa13'),
    (245.835, 224.385, 10.559, 6, '0e67405676e82f'),
    (249.635, 216.786, 12.079, 13.599, 'c212df7d0ef075'),
    (250.395, 222.865, 9.04, 9.04, 'a8085b2df62831'),
    (242.796, 222.865, 9.04, 9.04, 'a8085b2df62831'),
  ],
  [
    (332.054, 212.226, 12.079, 9.04, 'e7e0b3a93e63c4'),
    (329.014, 213.746, 18.158, 19.678, 'f294dc8b7afee1'),
    (335.094, 219.065, 9.04, 6, 'f4da83d6b6a8db'),
    (335.094, 222.865, 9.04, 6, 'f4da83d6b6a8db'),
    (332.054, 219.065, 6.008, 6, 'f5ee10b4cf6bcd'),
    (332.054, 222.865, 6.008, 6, 'f5ee10b4cf6bcd'),
  ],
];
const _labels = ['Confirmée', 'En préparation', 'Expédiée', 'Livrée'];
const _labelX = [32.727, 114.518, 226.317, 320.191];
const _labelW = [58.0, 81.0, 51.0, 33.0];

List<Widget> liveTimeline(WidgetRef ref) => [
      Positioned.fill(
        child: Consumer(builder: (context, ref, _) {
          final s = ref.watch(viewedOrderProvider).status.clamp(0, 3);
          double r(int i) => i == s ? 24 : 17.5;
          return Stack(clipBehavior: Clip.none, children: [
            for (var k = 0; k < 3; k++)
              gP(_cx[k] + r(k), 221, (_cx[k + 1] - r(k + 1)) - (_cx[k] + r(k)), 3,
                  gBox(color: k < s ? const Color(0xFF111015) : const Color(0xFFE6E1EE))),
            for (var i = 0; i < 4; i++) ...[
              gP(_cx[i] - r(i), _cy - r(i), r(i) * 2, r(i) * 2,
                  gBox(color: i <= s ? const Color(0xFF111015) : Colors.white, oval: true, border: i <= s ? null : const Color(0xFFE6E1EE), bw: 1)),
              for (final ic in _icons[i])
                gP(ic.$1, ic.$2, ic.$3, ic.$4,
                    ColorFiltered(colorFilter: ColorFilter.mode(i <= s ? Colors.white : const Color(0xFF6B6877), BlendMode.srcIn), child: gImg('$_v/${ic.$5}.svg'))),
              gP(_labelX[i], 256.643, _labelW[i], 14,
                  gText(_labels[i], 11.223, i < s ? const Color(0xFF5A3FE0) : (i == s ? const Color(0xFF111015) : const Color(0xFF6B6877)),
                      weight: i == s ? 700 : 500, align: TextAlign.center, wrap: true)),
            ],
          ]);
        }),
      ),
    ];
