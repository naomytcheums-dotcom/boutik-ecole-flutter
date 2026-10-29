import 'dart:ui';

import '../../../core/utils/validators_ref.dart';
import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// L1 · Aller en direct : aperçu caméra, titre, critères d'éligibilité et diffusion multi-réseaux.
class AllerDirectScreen extends ConsumerStatefulWidget {
  const AllerDirectScreen({super.key});

  @override
  ConsumerState<AllerDirectScreen> createState() => _AllerDirectScreenState();
}

class _AllerDirectScreenState extends ConsumerState<AllerDirectScreen> {
  late final _title = TextEditingController(text: ref.read(sectionREFDataProvider).liveTitle);
  late final List<bool> _criteria = [for (final c in ref.read(sectionREFDataProvider).liveCriteria) c.$2];
  bool _micOn = true;
  bool _youtube = true;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _launch() {
    final error = validateLiveTitle(_title.text);
    setState(() => _error = error);
    if (error == null) {
      context.toast(_youtube ? 'Live lancé sur Boutik-École et YouTube' : 'Live lancé sur Boutik-École');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    final done = _criteria.where((c) => c).length;
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      background: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFBEDE8), Color(0xFFF2E8EE), Color(0xFFF6E7E0)],
      ),
      header: RefHeader(
        title: 'Aller en direct',
        trailing: RefGlassButton(
          icon: AppIcons.share,
          label: 'Partager le live',
          onTap: () => context.toast('Lien du live copié'),
        ),
      ),
      bottomBarHeight: 50,
      bottomBar: RefPillButton(key: const Key('ref-launch-live'), label: 'Lancer le live', height: 44, onTap: _launch),
      children: [
        const SizedBox(height: 10),
        SizedBox(
          height: 328,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(d.livePreview, fit: BoxFit.cover, semanticLabel: 'Aperçu de la caméra'),
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: refLive, borderRadius: BorderRadius.circular(13)),
                    child: Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Text('EN DIRECT', style: AppText.label.copyWith(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  top: 16,
                  child: Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: () => context.toast('Aperçu plein écran'),
                      child: Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xB3222026),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            const AppIcon(AppIcons.eye, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Aperçu',
                              style: AppText.small.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          width: 170,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _Control(
                                icon: AppIcons.refreshCw,
                                label: 'Changer de caméra',
                                onTap: () => context.toast('Caméra frontale'),
                              ),
                              _Control(
                                icon: _micOn ? AppIcons.mic : AppIcons.micOff,
                                label: _micOn ? 'Couper le micro' : 'Activer le micro',
                                onTap: () => setState(() => _micOn = !_micOn),
                              ),
                              _Control(
                                icon: AppIcons.sparkleFilled,
                                label: 'Effets',
                                onTap: () => context.toast('Effets : lumière douce'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: _error != null ? Border.all(color: AppColors.error) : null,
          ),
          child: TextField(
            key: const Key('ref-live-title'),
            controller: _title,
            style: AppText.body.copyWith(fontSize: 13),
            onChanged: (_) {
              if (_error != null) setState(() => _error = validateLiveTitle(_title.text));
            },
            decoration: InputDecoration(
              hintText: 'Titre du live',
              hintStyle: AppText.body.copyWith(fontSize: 13, color: AppColors.textSecondary),
              filled: false,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Semantics(
              liveRegion: true,
              child: Text(_error!, style: AppText.small.copyWith(color: AppColors.error)),
            ),
          ),
        const SizedBox(height: 12),
        RefCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        done == _criteria.length ? 'Tout est prêt pour ton live' : 'Tu peux lancer ce live',
                        style: AppText.h3.copyWith(fontSize: 15.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      '$done / ${_criteria.length}',
                      style: AppText.small.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 4.3,
                children: [
                  for (var i = 0; i < _criteria.length; i++)
                    _Criterion(
                      label: d.liveCriteria[i].$1,
                      done: _criteria[i],
                      onTap: d.liveCriteria[i].$2 ? null : () => setState(() => _criteria[i] = !_criteria[i]),
                    ),
                ],
              ),
              Text(d.liveNote, style: AppText.small.copyWith(color: AppColors.success, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RefCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Diffuser aussi sur', style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Destination(
                      name: 'YouTube',
                      status: _youtube ? 'Prêt' : 'Désactivé',
                      icon: AppIcons.play,
                      iconColor: const Color(0xFFE53935),
                      iconBg: const Color(0xFFFBE3E6),
                      statusColor: _youtube ? AppColors.success : AppColors.textSecondary,
                      selected: _youtube,
                      filled: true,
                      onTap: () => setState(() => _youtube = !_youtube),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: _Destination(
                      name: 'TikTok',
                      status: 'Non éligible',
                      icon: AppIcons.music,
                      iconColor: AppColors.ink,
                      iconBg: Color(0xFFE6E4EA),
                      statusColor: AppColors.warning,
                      locked: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({required this.icon, required this.label, required this.onTap});

  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: AppIcon(icon, size: 20, color: Colors.white)),
        ),
      ),
    );
  }
}

class _Criterion extends StatelessWidget {
  const _Criterion({required this.label, required this.done, this.onTap});

  final String label;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: done,
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: done ? const Color(0xFF239A62) : const Color(0xFFE6E4EA),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: done ? const AppIcon(AppIcons.check, size: 13, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: AppText.body.copyWith(fontSize: 13, color: done ? AppColors.ink : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.name,
    required this.status,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.statusColor,
    this.selected = false,
    this.locked = false,
    this.onTap,
    this.filled = false,
  });

  final bool filled;

  final String name;
  final String status;
  final String icon;
  final Color iconColor;
  final Color iconBg;
  final Color statusColor;
  final bool selected;
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      toggled: onTap != null ? selected : null,
      label: '$name, $status',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: const Color(0xFFF4F2F7), borderRadius: BorderRadius.circular(24)),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: filled
                    ? CustomPaint(size: const Size(12, 14), painter: _TrianglePainter(iconColor))
                    : AppIcon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppText.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: locked ? AppColors.textSecondary : AppColors.ink,
                      ),
                    ),
                    Text(status, style: AppText.small.copyWith(fontSize: 11, color: statusColor)),
                  ],
                ),
              ),
              if (locked) ...[const AppIcon(AppIcons.lock, size: 14), const SizedBox(width: 8)],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}
