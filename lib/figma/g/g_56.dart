// GÉNÉRÉ par tool/figma_export/convert.py — écran 56 (nœud Figma 40:802). Ne pas éditer à la main.
// ignore_for_file: camel_case_types, prefer_is_empty, prefer_interpolation_to_compose_strings, unnecessary_string_interpolations, unused_import, prefer_const_constructors, prefer_const_literals_to_create_immutables
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../gen.dart';
import '../nav.dart';
import '../live/store.dart';
import '../live/l06.dart';
import '../live/l09.dart';
import '../live/lfav.dart';
import '../live/auth.dart';
import '../live/seller.dart';
import '../live/review.dart';
import '../live/audit.dart';
import '../live/admin.dart';
import '../live/talents.dart';
import '../live/hackathons.dart';
import '../live/ops.dart';
import '../live/missions.dart';
import '../live/docs.dart';
import '../live/kela.dart';
import '../live/chat.dart';
import '../live/share.dart';
import '../live/inert_actions.dart';
import '../live/notif_client.dart';
import '../live/pay.dart';
import '../../data/repositories/repositories.dart' show cartProvider;

class G_56 extends ConsumerWidget {
  const G_56({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notifSettingsProvider).value ?? const NotifSettings();
    final rev = ref.watch(notifSettingsRevisionProvider);
    // Interrupteur d'une catégorie : enregistré sur le serveur ; en cas de refus, l'état réel est relu et le refus est annoncé.
    Widget category(String cat, double y, {bool demoOn = true}) => gP(
          308, y, 42, 24,
          GToggle(
            key: ValueKey('$cat-$rev'),
            on: demoContent ? demoOn : settings.category(cat),
            onChanged: (v) async {
              if (demoContent) return;
              if (!await requireLogin(context, ref, 'régler vos notifications')) return ref.read(notifSettingsRevisionProvider.notifier).set(rev + 1);
              final err = await setNotificationCategory(cat, v);
              if (err != null && context.mounted) gToast(context, err);
              ref.invalidate(notifSettingsProvider);
              if (err != null) ref.read(notifSettingsRevisionProvider.notifier).set(rev + 1);
            },
            onColor: Color(0xFF111015),
            offColor: Color(0xFFDAD8DF),
            knob: 18,
          ),
        );
    return GScreen(w: 390, h: 844, radius: 34, bg: LinearGradient(begin: Alignment(0, -1), end: Alignment(0, 1), colors: [Color(0xFFF4EFE6), Color(0xFFEEE8F3), Color(0xFFF7E6D6)], stops: [0, 0.5, 1]), children: [
      gP(200, 128.52, 300, 300, gBox(color: Color(0x8CCDB2F2), layerBlur: 120, oval: true), fx: 'halo'),
      gP(-110, 575.84, 300, 300, gBox(color: Color(0x80FFC38A), layerBlur: 120, oval: true), fx: 'halo'),
      gP(30, 14, 30, 18, gText('9:41', 14.5, Color(0xFF111015), weight: 700)),
      gP(281, 27, 9, 11, gImg('assets/figma/v/b121442ee3614d.svg')),
      gP(286, 24, 9, 14, gImg('assets/figma/v/c57de3594f8754.svg')),
      gP(291, 21, 9, 17, gImg('assets/figma/v/a1b9d0cbd609c8.svg')),
      gP(296, 18, 9, 20, gImg('assets/figma/v/5b8887c3459f31.svg')),
      gP(307, 19.941, 20, 12.259, gImg('assets/figma/v/560b90a7edf47b.svg')),
      gP(312.4, 27.8, 9.2, 9.2, gImg('assets/figma/v/415c542d2adf04.svg')),
      gP(331.5, 19.5, 28, 17, gImg('assets/figma/v/6a818f3296df50.svg')),
      gP(333.5, 21.5, 22, 13, gImg('assets/figma/v/270d9e714b8cbf.svg')),
      gP(355, 23, 8, 10, gImg('assets/figma/v/6ed615efa73f1c.svg')),
      gP(31, 71, 22, 22, const SizedBox.expand(), tap: () => gBack(context)),
      gP(21.98, 61.98, 40, 40, const GGlassCircle()),
      gP(32.583, 72.583, 12.417, 18.833, gImg('assets/figma/v/65dc27d13237d5.svg')),
      gP(32.583, 79, 18.833, 6, gImg('assets/figma/v/cfefc4b0da4201.svg')),
      gP(76, 70, 311, 26, gText('Notifications et confidentialité', 21, Color(0xFF111015), weight: 700)),
      gP(24, 120, 95, 19, gText('Notifications', 15, Color(0xFF111015), weight: 700)),
      gP(40, 170, 142, 17, gText('Suivi des commandes', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 192, 260, 14, gText('Commandes, paiements, litiges et devis', 11.5, Color(0xFF57545F))),
      category('orders', 179),
      gP(40, 224, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 236, 66, 17, gText('Messages', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 258, 145, 14, gText('Nouveaux messages reçus', 11.5, Color(0xFF57545F))),
      category('messages', 245),
      gP(40, 290, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 302, 176, 17, gText('Alertes et promotions', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 324, 260, 14, gText('Alertes de prix, offres et campagnes', 11.5, Color(0xFF57545F))),
      category('promotions', 311, demoOn: false),
      gP(40, 356, 314, 1, gBox(color: Color(0xFFF2EFF6))),
      gP(40, 368, 120, 17, gText('Avis et questions', 13.5, Color(0xFF111015), weight: 600)),
      gP(40, 390, 260, 14, gText('Avis et questions sur vos produits', 11.5, Color(0xFF57545F))),
      category('reviews', 377),
      gP(24, 436, 110, 19, gText('Confidentialité', 15, Color(0xFF111015), weight: 700)),
      gP(40, 486, 77, 17, gText('Profil public', 13.5, Color(0xFF111015), weight: 600), show: demoContent),
      gP(40, 508, 138, 14, gText('Visible par les entreprises', 11.5, Color(0xFF57545F)), show: demoContent),
      gP(308, 495, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18), show: demoContent),
      gP(40, 540, 314, 1, gBox(color: Color(0xFFF2EFF6)), show: demoContent),
      gP(40, 552, 180, 17, gText('Afficher mon établissement', 13.5, Color(0xFF111015), weight: 600), show: demoContent),
      gP(40, 574, 75, 14, gText('Sur mon profil', 11.5, Color(0xFF57545F)), show: demoContent),
      gP(308, 561, 42, 24, GToggle(on: true, onColor: Color(0xFF111015), offColor: Color(0xFFDAD8DF), knob: 18), show: demoContent),
      gP(40, 606, 314, 1, gBox(color: Color(0xFFF2EFF6)), show: demoContent),
      gP(40, 618, 149, 17, gText('Statistiques anonymes', 13.5, Color(0xFF111015), weight: 600), show: demoContent),
      gP(40, 640, 122, 14, gText('Améliorer l’application', 11.5, Color(0xFF57545F)), show: demoContent),
      gP(308, 627, 42, 24, GToggle(on: false, onColor: Color(0xFF111015), offColor: Color(0xFFE6E1EE), knob: 18), show: demoContent),
      gP(40, 486, 314, 80, gText('Aucun réglage de visibilité n’est encore proposé. Vos informations ne sont montrées que selon les règles de la plateforme, et vous pouvez télécharger toutes vos données ci-dessous.', 12.5, Color(0xFF4A4854), lh: 18, wrap: true), show: !demoContent),
      gP(24, 686, 342, 50, gBox(color: Color(0xFFFFFFFF), border: Color(0xFFE6E1EE), bw: 1.5, radii: [25, 25, 25, 25])),
      gP(118, 702, 179, 18, gText('Télécharger mes données', 14.5, Color(0xFF111015), weight: 600, align: TextAlign.center)),
      gP(92.125, 710.125, 18.75, 10.25, gImg('assets/figma/v/e0834926a737bf.svg')),
      gP(94.958, 706.583, 13.083, 9.542, gImg('assets/figma/v/3ee7d7ad9e826a.svg')),
      gP(98.5, 701.625, 6, 14.5, gImg('assets/figma/v/c6f78b73bf1246.svg')),
      gP(24, 748, 342, 24, gText('Canaux : SMS, WhatsApp, e-mail, navigateur', 12.5, Color(0xFF5A3FE0), weight: 600, align: TextAlign.center), tap: () => gOpen(context, '236')),
      gP(125, 830, 140, 5, gBox(color: Color(0xFF111015), radii: [3, 3, 3, 3])),
      gTap(24, 686, 342, 50, () { gOpen(context, '273'); }), // audit 01/11 : « Télécharger mes données » n'avait aucun effet
    ]);
  }
}
