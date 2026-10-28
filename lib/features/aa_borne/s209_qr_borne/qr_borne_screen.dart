import 'dart:async';

import '../aa_widgets.dart';
import '../kiosk_qr.dart';

/// 209 · Continuer sur le téléphone : QR de session valable 5 minutes, compte à rebours, trois étapes.
/// Toucher le QR simule le scan (en production, le serveur signale le scan à la borne).
class QrBorneScreen extends ConsumerStatefulWidget {
  const QrBorneScreen({super.key});

  @override
  ConsumerState<QrBorneScreen> createState() => _QrBorneScreenState();
}

class _QrBorneScreenState extends ConsumerState<QrBorneScreen> {
  late int _left = ref.read(sectionAADataProvider).qrSecondsLeft;
  int _renewals = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
      if (_left == 0) t.cancel();
    });
  }

  void _renew() {
    setState(() {
      _renewals++;
      _left = ref.read(sectionAADataProvider).qrValiditySeconds;
    });
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAADataProvider);
    final expired = _left == 0;
    // Lien court : le serveur retrouve la borne et l'article à partir du jeton de session signé.
    final data = '${d.qrBaseUrl}${d.sessionToken}$_renewals';
    final clock = '${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}';
    return AAPage(
      builder: (context, l, lang) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(KioskScaffold.padding, 48, KioskScaffold.padding, 40),
        child: Column(
          children: [
            Semantics(
              header: true,
              child: Text(
                l.kioskQrTitle,
                textAlign: TextAlign.center,
                style: AppText.display.copyWith(fontSize: 40, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l.kioskQrSubtitle,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(fontSize: 19.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 46),
            Semantics(
              button: !expired,
              label: expired ? l.kioskQrExpired : l.kioskQrSemantics,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: expired ? null : () => context.openScreen('210'),
                child: Container(
                  width: 460,
                  height: 460,
                  padding: const EdgeInsets.all(44),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(48),
                    boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 30, offset: Offset(0, 4))],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: expired ? .12 : 1,
                        child: KioskQr(data: data, size: 372, logo: 'assets/images/ai_logo_be.png'),
                      ),
                      if (expired)
                        PrimaryButton(
                          label: l.kioskQrRenew,
                          icon: AppIcons.refreshCw,
                          expand: false,
                          onPressed: _renew,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Semantics(
              liveRegion: true,
              label: expired ? l.kioskQrExpired : '${l.kioskQrValid} $clock',
              excludeSemantics: true,
              child: Column(
                children: [
                  KioskCountdownRing(fraction: _left / d.qrValiditySeconds, label: clock),
                  const SizedBox(height: 8),
                  Text(
                    expired ? l.kioskQrExpired : l.kioskQrValid,
                    style: AppText.small.copyWith(
                      fontSize: 16,
                      color: expired ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Row(
              children: [
                for (final (i, s) in [l.kioskStepScan, l.kioskStepOpen, l.kioskStepOrder].indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _Step(number: i + 1, label: s),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 50),
            Semantics(
              button: true,
              label: l.kioskCancel,
              excludeSemantics: true,
              child: Material(
                color: Colors.white,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => context.goScreen('208'),
                  child: SizedBox(
                    width: 260,
                    height: 84,
                    child: Center(
                      child: Text(
                        l.kioskCancel,
                        style: AppText.button.copyWith(fontSize: 23, fontWeight: FontWeight.w500, color: AppColors.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$number', style: AppText.bodyStrong.copyWith(fontSize: 22, color: Colors.white)),
          ),
          const Spacer(),
          Text(label, style: AppText.body.copyWith(fontSize: 19.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
