import 'package:qr/qr.dart';

import 'aa_widgets.dart';

/// QR code dessiné comme la maquette 209 : modules arrondis encre, repères aux coins encre + violet,
/// logo au centre (correction d'erreur élevée pour rester lisible malgré le logo).
class KioskQr extends StatelessWidget {
  const KioskQr({super.key, required this.data, required this.size, this.logo});

  final String data;
  final double size;
  final String? logo;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(payload: QrPayload.fromString(data), errorCorrectLevel: QrErrorCorrectLevel.high));
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.square(size), painter: _QrPainter(image)),
          if (logo != null)
            Container(
              width: size * .18,
              height: size * .18,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              padding: EdgeInsets.all(size * .02),
              child: ClipOval(child: Image.asset(logo!, fit: BoxFit.cover)),
            ),
        ],
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final m = size.width / n;
    final ink = Paint()..color = AppColors.ink;
    final centre = n / 2;
    final hole = n * .11;
    bool inFinder(int r, int c) => (r < 8 && c < 8) || (r < 8 && c >= n - 8) || (r >= n - 8 && c < 8);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (inFinder(r, c) || !image.isDark(r, c)) continue;
        if ((r + .5 - centre).abs() < hole && (c + .5 - centre).abs() < hole) continue;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(c * m, r * m, m * 1.02, m * 1.02), Radius.circular(m * .2)),
          ink,
        );
      }
    }
    void finder(double x, double y) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + m / 2, y + m / 2, m * 6, m * 6), Radius.circular(m * 1.8)),
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = m,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x + m * 2, y + m * 2, m * 3, m * 3), Radius.circular(m * .8)),
        Paint()..color = AppColors.accent,
      );
    }

    finder(0, 0);
    finder((n - 7) * m, 0);
    finder(0, (n - 7) * m);
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}

/// Anneau du compte à rebours (fraction restante en violet, quatre segments).
class KioskCountdownRing extends StatelessWidget {
  const KioskCountdownRing({super.key, required this.fraction, required this.label, this.size = 108});

  final double fraction;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(fraction.clamp(0, 1)),
        child: Center(
          child: Text(label, style: AppText.bodyStrong.copyWith(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    canvas.drawCircle(
      rect.center,
      arc.width / 2,
      Paint()
        ..color = const Color(0xFFE6E3EE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    const quarter = 3.14159265 / 2;
    const gap = .42;
    var left = fraction * 4;
    for (var i = 0; i < 4 && left > 0; i++) {
      final part = left >= 1 ? 1.0 : left;
      final start = -quarter + i * quarter + gap / 2 - quarter / 2;
      canvas.drawArc(arc, start, (quarter - gap) * part, false, paint);
      left -= 1;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction;
}
