import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr/qr.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'seller.dart' show allProductsProvider;
import 'share.dart' show siteUrl;
import '../../data/repositories/repositories.dart' show cartProvider;

/// QR codes réels (migration 20261110000300) : chaque code est un jeton aléatoire unique, stocké côté serveur et rattaché à son
/// propriétaire et à un contenu. L'application ne fabrique jamais de code localement.

/// Contenu encodé : adresse du site + jeton (un appareil photo ordinaire ouvre le site ; l'application lit le jeton).
String qrPayload(String token) => '$siteUrl/?qr=$token';

/// Jeton contenu dans un texte scanné (adresse complète ou jeton seul) ; null si le format est inconnu.
String? qrTokenOf(String raw) {
  final t = raw.trim();
  final u = Uri.tryParse(t);
  final fromUrl = u?.queryParameters['qr'];
  final c = fromUrl ?? t;
  return RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(c) ? c : null;
}

/// Dessin d'un QR (modules carrés, correction d'erreur moyenne) pour [data].
class QrView extends StatelessWidget {
  const QrView({super.key, required this.data, this.size = 180, this.color = const Color(0xFF111015)});
  final String data;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M));
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(size * 0.06)),
      child: CustomPaint(painter: _QrPainter(image, color)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image, this.color);
  final QrImage image;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final m = size.width / n;
    final p = Paint()..color = color;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (image.isDark(r, c)) canvas.drawRect(Rect.fromLTWH(c * m, r * m, m + 0.4, m + 0.4), p);
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image || old.color != color;
}

/// Crée ou retrouve un QR sur le serveur. Retourne {token, expires_at} ou un message d'erreur.
Future<({String? token, String? error})> issueQr(String kind, String targetId, {String label = '', int? ttlSeconds}) async {
  final r = await Backend.rpc('qr_issue', {'p_kind': kind, 'p_target_id': targetId, 'p_label': label, 'p_ttl_seconds': ttlSeconds});
  if (r.error != null) return (token: null, error: r.error);
  final d = r.data;
  final t = d is Map ? d['token'] : null;
  return t is String ? (token: t, error: null) : (token: null, error: 'Code QR indisponible pour le moment.');
}

/// Ouvre la caméra et retourne le premier code lu (null si fermé). Refus de permission ou absence de caméra : message clair.
Future<String?> scanQrCamera(BuildContext context) => Navigator.of(context, rootNavigator: true).push<String>(
  MaterialPageRoute(fullscreenDialog: true, builder: (_) => const _ScannerPage()),
);

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _ctrl = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _error(MobileScannerException e) => switch (e.errorCode) {
    MobileScannerErrorCode.permissionDenied => 'L’accès à la caméra est refusé. Autorisez la caméra dans les réglages de votre navigateur ou de votre téléphone, puis réessayez.',
    MobileScannerErrorCode.unsupported => 'La caméra n’est pas disponible sur cet appareil.',
    _ => 'La caméra n’a pas pu démarrer. Fermez les autres applications qui l’utilisent, puis réessayez.',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (cap) {
            if (_done) return;
            for (final b in cap.barcodes) {
              final v = b.rawValue;
              if (v != null && v.isNotEmpty) {
                _done = true;
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(v);
                return;
              }
            }
          },
          errorBuilder: (context, e) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(_error(e), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
            ),
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 3), borderRadius: BorderRadius.circular(24)),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 56,
          child: const Text('Placez le code QR dans le cadre', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
              tooltip: 'Fermer',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Scanne un QR et agit selon ce que le serveur répond (profil, annonce, retrait, borne, événement).
Future<void> scanAndHandleQr(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'La lecture d’un QR nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'scanner un code QR') || !context.mounted) return;
  final raw = await scanQrCamera(context);
  if (raw == null || !context.mounted) return;
  final token = qrTokenOf(raw);
  if (token == null) return gAlert(context, 'Code non reconnu', 'Ce code QR n’a pas été créé par Boutik-École.');
  final r = await Backend.rpc('qr_resolve', {'p_token': token, 'p_consume': true});
  if (!context.mounted) return;
  if (r.error != null) return gAlert(context, 'Lecture impossible', r.error!);
  final d = r.data is Map ? Map<String, dynamic>.from(r.data as Map) : <String, dynamic>{};
  if (d['valid'] != true) {
    final why = switch (d['reason']) {
      'expired' => 'Ce code a expiré. Demandez-en un nouveau.',
      'used' => 'Ce code a déjà été utilisé : il ne sert qu’une fois.',
      'revoked' => 'Ce code a été retiré par son propriétaire.',
      _ => 'Ce code est inconnu.',
    };
    return gAlert(context, 'Code refusé', why);
  }
  final label = '${d['label'] ?? ''}';
  switch (d['kind']) {
    case 'profile':
      return gOpenProfile(context, '${d['target_id']}');
    case 'kiosk_transfer':
      final hit = ref.read(allProductsProvider).where((p) => p.title == label).toList();
      if (hit.isEmpty) return gAlert(context, 'Article introuvable', 'L’article de ce code n’est plus au catalogue.');
      ref.read(cartProvider.notifier).add(hit.first.toLine());
      gToast(context, '$label ajouté à votre panier.');
      return gOpen(context, '210');
    case 'order_pickup':
    case 'listing':
    case 'event':
    case 'certificate':
      return gAlert(context, 'Code valide', '${label.isEmpty ? 'Contenu' : label} · proposé par ${d['owner_name']}.');
  }
}

/// « Mon QR » : le QR permanent et unique du profil du titulaire, avec lecture d'un autre code.
class MyQrCard extends ConsumerStatefulWidget {
  const MyQrCard({super.key, this.width = 342});
  final double width;
  @override
  ConsumerState<MyQrCard> createState() => _MyQrCardState();
}

class _MyQrCardState extends ConsumerState<MyQrCard> {
  String? _token, _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = ref.read(authProvider).current?.serverId ?? '';
    if (!Backend.ready || uid.isEmpty) return;
    final r = await issueQr('profile', uid, label: ref.read(authProvider).current?.name ?? '');
    if (mounted) setState(() { _token = r.token; _error = r.error; });
  }

  @override
  Widget build(BuildContext context) {
    const ink = TextStyle(fontSize: 13, color: Color(0xFF57545F), height: 1.45);
    if (!Backend.ready || (ref.watch(authProvider).current?.serverId ?? '').isEmpty) {
      return SizedBox(width: widget.width, child: const Text('Connectez-vous pour obtenir votre QR personnel.', textAlign: TextAlign.center, style: ink));
    }
    return SizedBox(
      width: widget.width,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (_token != null) QrView(data: qrPayload(_token!), size: 200) else Text(_error ?? 'Création du code…', textAlign: TextAlign.center, style: ink),
        const SizedBox(height: 10),
        const Text('Ce code est unique et permanent : il ouvre votre profil.', textAlign: TextAlign.center, style: ink),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111015), shape: const StadiumBorder()),
          onPressed: () => scanAndHandleQr(context, ref),
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: const Text('Scanner un code'),
        ),
      ]),
    );
  }
}

/// Fenêtre « Mon QR personnel » (menu du compte).
Future<void> myQrDialog(BuildContext context, WidgetRef ref) => gDialog<void>(
  context: context,
  builder: (ctx) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Mon QR personnel', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111015))),
        const SizedBox(height: 16),
        const MyQrCard(width: 280),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer', style: TextStyle(color: Color(0xFF111015), fontWeight: FontWeight.w700))),
      ]),
    ),
  ),
);
