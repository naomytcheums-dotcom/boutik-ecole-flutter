import 'dart:async';

import '../aa_widgets.dart';

/// 210 · « C'est envoyé ! » : reçu avec code de suivi (code-barres Code 39), impression, retour auto à l'accueil.
class EnvoyeBorneScreen extends ConsumerStatefulWidget {
  const EnvoyeBorneScreen({super.key});

  @override
  ConsumerState<EnvoyeBorneScreen> createState() => _EnvoyeBorneScreenState();
}

class _EnvoyeBorneScreenState extends ConsumerState<EnvoyeBorneScreen> {
  late int _left = ref.read(sectionAADataProvider).returnSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        t.cancel();
        context.goScreen('206');
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAADataProvider);
    final p = ref.watch(kioskProductProvider);
    return AAPage(
      builder: (context, l, lang) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(KioskScaffold.padding, 86, KioskScaffold.padding, 30),
        child: Column(
          children: [
            ExcludeSemantics(child: Image.asset('assets/images/aa_chrome_check.png', width: 152, height: 152)),
            const SizedBox(height: 46),
            Semantics(
              header: true,
              liveRegion: true,
              child: Text(l.kioskSentTitle, style: AppText.display.copyWith(fontSize: 50, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Text(l.kioskSentSubtitle, style: AppText.body.copyWith(fontSize: 20, color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            _Ticket(product: p, data: d, l: l, lang: lang),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PillButton(
                  label: l.kioskPrint,
                  icon: AppIcons.printer,
                  width: 300,
                  onTap: () => context.toast(l.kioskPrinting),
                ),
                const SizedBox(width: 16),
                _PillButton(label: l.kioskFinish, width: 144, dark: true, onTap: () => context.goScreen('206')),
              ],
            ),
            const SizedBox(height: 22),
            Semantics(
              liveRegion: true,
              child: Text(
                l.kioskBackHome(_left),
                style: AppText.small.copyWith(fontSize: 16, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.product, required this.data, required this.l, required this.lang});

  final KioskProduct product;
  final SectionAAData data;
  final AppLocalizations l;
  final String lang;

  static const _notch = Color(0xFFEAE7EE);

  @override
  Widget build(BuildContext context) {
    Widget info(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.small.copyWith(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(value, style: AppText.bodyStrong.copyWith(fontSize: 19)),
        ],
      ),
    );
    return SizedBox(
      width: 552,
      height: 560,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: 26,
            right: 26,
            child: Container(
              padding: const EdgeInsets.fromLTRB(36, 36, 36, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(44),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 30, offset: Offset(0, 4))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(product.image, width: 108, height: 108, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name, style: AppText.h2.copyWith(fontSize: 25, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 12),
                            Text(
                              product.workshop,
                              style: AppText.small.copyWith(fontSize: 16.5, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              fcfaLocalized(product.price, lang),
                              style: AppText.h2.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      info(l.kioskDate, data.receiptDate),
                      info(l.kioskTime, data.receiptTime),
                      info(l.kioskPickup, data.receiptPickup),
                    ],
                  ),
                  const SizedBox(height: 26),
                  const _DashedLine(),
                  const SizedBox(height: 44),
                  Text(
                    l.kioskTrackingCode,
                    style: AppText.small.copyWith(fontSize: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(data.trackingCode, style: AppText.display.copyWith(fontSize: 34, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 26),
                  Semantics(
                    label: '${l.kioskTrackingCode} ${data.trackingCode}',
                    image: true,
                    excludeSemantics: true,
                    child: Code39Barcode(data.trackingCode, width: 362, height: 70),
                  ),
                ],
              ),
            ),
          ),
          for (final left in [0.0, 500.0])
            Positioned(
              left: left,
              top: 252,
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: _notch, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < 24; i++)
        Expanded(
          child: Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: const Color(0xFFD9D7DE), borderRadius: BorderRadius.circular(2)),
          ),
        ),
    ],
  );
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.width, required this.onTap, this.icon, this.dark = false});

  final String label;
  final String? icon;
  final double width;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.ink;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: dark ? AppColors.ink : Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            width: width,
            height: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[AppIcon(icon!, size: 30, color: fg), const SizedBox(width: 26)],
                Text(
                  label,
                  style: AppText.button.copyWith(fontSize: 23, fontWeight: FontWeight.w500, color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Code-barres Code 39 (lettres majuscules, chiffres, tiret), lisible par une douchette standard.
class Code39Barcode extends StatelessWidget {
  const Code39Barcode(this.data, {super.key, required this.width, required this.height});

  final String data;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, height), painter: _Code39Painter(code39Pattern(data)));
}

/// Suite de modules (true = barre) : 1 module étroit, 3 modules larges, séparateur étroit entre caractères.
List<bool> code39Pattern(String data) {
  const table = {
    '0': '000110100',
    '1': '100100001',
    '2': '001100001',
    '3': '101100000',
    '4': '000110001',
    '5': '100110000',
    '6': '001110000',
    '7': '000100101',
    '8': '100100100',
    '9': '001100100',
    'A': '100001001',
    'B': '001001001',
    'C': '101001000',
    'D': '000011001',
    'E': '100011000',
    'F': '001011000',
    'G': '000001101',
    'H': '100001100',
    'I': '001001100',
    'J': '000011100',
    'K': '100000011',
    'L': '001000011',
    'M': '101000010',
    'N': '000010011',
    'O': '100010010',
    'P': '001010010',
    'Q': '000000111',
    'R': '100000110',
    'S': '001000110',
    'T': '000010110',
    'U': '110000001',
    'V': '011000001',
    'W': '111000000',
    'X': '010010001',
    'Y': '110010000',
    'Z': '011010000',
    '-': '010000101',
    '*': '010010100',
  };
  final modules = <bool>[];
  final chars = '*${data.toUpperCase()}*'.split('');
  for (var c = 0; c < chars.length; c++) {
    final code = table[chars[c]];
    if (code == null) throw ArgumentError('Caractère non pris en charge par Code 39 : ${chars[c]}');
    for (var i = 0; i < 9; i++) {
      modules.addAll(List.filled(code[i] == '1' ? 3 : 1, i.isEven));
    }
    if (c < chars.length - 1) modules.add(false);
  }
  return modules;
}

class _Code39Painter extends CustomPainter {
  _Code39Painter(this.modules);

  final List<bool> modules;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width / modules.length;
    final paint = Paint()..color = AppColors.ink;
    for (var i = 0; i < modules.length; i++) {
      if (modules[i]) canvas.drawRect(Rect.fromLTWH(i * w, 0, w + .3, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_Code39Painter old) => old.modules != modules;
}
