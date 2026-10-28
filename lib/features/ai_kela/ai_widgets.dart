import 'dart:math' as math;

import '../../core/utils/validators_ai.dart';
import '../../data/demo/section_ai_demo.dart';
import '../common/common.dart';

export '../../data/demo/section_ai_demo.dart';

/// Vert des boutons WhatsApp (bouton d'envoi).
const aiWhatsAppGreen = Color(0xFF128C7E);

/// Vert foncé des libellés WhatsApp (contraste ≥ 4,5:1 sur blanc).
const aiWhatsAppText = Color(0xFF0F7A6E);

/// Bulle sortante WhatsApp.
const aiWhatsAppOutgoing = Color(0xFFD9FDD3);

/// Gris des heures et légendes WhatsApp.
const aiWhatsAppMuted = Color(0xFF6B6B6B);

/// Bouton rond blanc à ombre douce des écrans Kéla (icône ou court libellé).
class AiRoundButton extends StatelessWidget {
  const AiRoundButton({super.key, this.icon, this.text, required this.label, this.onTap});

  final String? icon;
  final String? text;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x1A6B5A8E), blurRadius: 12, offset: Offset(0, 4)),
              BoxShadow(color: Color(0x14F0A070), blurRadius: 3, offset: Offset(0, 2)),
            ],
          ),
          child: icon != null
              ? AppIcon(icon!, size: 20)
              : Text(text ?? '', style: AppText.label.copyWith(fontSize: 12.5)),
        ),
      ),
    );
  }
}

/// Texte où chaque « ✓ » est dessiné avec l'icône `check` (glyphe absent de la police de l'app).
Widget aiCheckText(String text, TextStyle style) {
  if (!text.contains('✓')) return Text(text, style: style);
  final size = (style.fontSize ?? 14) + 1;
  final spans = <InlineSpan>[];
  for (final (i, part) in text.split('✓').indexed) {
    if (i > 0) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AppIcon(AppIcons.check, size: size, color: style.color ?? AppColors.ink),
        ),
      );
    }
    if (part.isNotEmpty) spans.add(TextSpan(text: part));
  }
  return Semantics(
    label: text.replaceAll('✓', '').trim(),
    excludeSemantics: true,
    child: Text.rich(TextSpan(style: style, children: spans)),
  );
}

/// Décoration sans bordure ni fond des champs de saisie des compositeurs.
InputDecoration aiBareInput(String hint, TextStyle hintStyle) => InputDecoration(
  hintText: hint,
  hintStyle: hintStyle,
  filled: false,
  isDense: true,
  contentPadding: EdgeInsets.zero,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
);

/// En-tête des écrans Kéla : retour, titre centré (+ sous-titre), bouton menu.
class AiKelaHeader extends StatelessWidget {
  const AiKelaHeader({super.key, required this.title, this.subtitle, this.onMenu, this.bottom = 18});

  final String title;
  final String? subtitle;
  final VoidCallback? onMenu;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(30, 42, 30, bottom),
      child: Row(
        children: [
          AiRoundButton(icon: AppIcons.arrowLeft, label: 'Retour', onTap: () => ScreenHeader.back(context)),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle!, textAlign: TextAlign.center, style: AppText.small),
                  ],
                ],
              ),
            ),
          ),
          AiRoundButton(icon: AppIcons.equal, label: 'Menu', onTap: onMenu),
        ],
      ),
    );
  }
}

/// Onde vocale décorative (barres verticales arrondies).
class AiVoiceWave extends StatelessWidget {
  const AiVoiceWave({
    super.key,
    required this.heights,
    this.color = const Color(0xFF8E7BFF),
    this.barWidth = 3,
    this.gap = 5,
  });

  final List<double> heights;
  final Color color;
  final double barWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, h) in heights.indexed) ...[
            if (i > 0) SizedBox(width: gap),
            Container(
              width: barWidth,
              height: h,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(barWidth)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Triangle « lecture » plein (pas d'équivalent plein dans le jeu d'icônes).
class AiPlayGlyph extends StatelessWidget {
  const AiPlayGlyph({super.key, this.size = 14, this.color = AppColors.ink});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _PlayPainter(color));
}

class _PlayPainter extends CustomPainter {
  _PlayPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.2, w * 0.1)
      ..lineTo(w * 0.9, w * 0.5)
      ..lineTo(w * 0.2, w * 0.9)
      ..close();
    final paint = Paint()
      ..color = color
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = w * 0.14;
    canvas
      ..drawPath(path, paint..style = PaintingStyle.fill)
      ..drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_PlayPainter old) => old.color != color;
}

/// Compositeur des écrans Kéla : « + », champ, micro (devient « Envoyer » dès qu'un texte est saisi).
class AiKelaComposer extends StatefulWidget {
  const AiKelaComposer({super.key, required this.onSend, this.hint = 'Écris ou parle à Kéla…'});

  final ValueChanged<String> onSend;
  final String hint;

  @override
  State<AiKelaComposer> createState() => _AiKelaComposerState();
}

class _AiKelaComposerState extends State<AiKelaComposer> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ctrl.text.trim().isEmpty) {
      context.toast('Kéla vous écoute : parlez maintenant.');
      return;
    }
    final error = AiValidators.chatMessage(_ctrl.text);
    setState(() => _error = error);
    if (error != null) return;
    widget.onSend(_ctrl.text.trim());
    _ctrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _ctrl.text.trim().isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              _error!,
              style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
        Container(
          height: 62,
          padding: const EdgeInsets.only(left: 6, right: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(31),
            boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6))],
          ),
          child: Row(
            children: [
              RoundIconButton(
                icon: AppIcons.plus,
                label: 'Joindre un fichier',
                bordered: false,
                background: Colors.transparent,
                onTap: () => context.toast('Ajoutez une photo ou un document.'),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _submit(),
                  style: AppText.body,
                  decoration: aiBareInput(widget.hint, AppText.body.copyWith(color: const Color(0xFF6E6A73))),
                ),
              ),
              RoundIconButton(
                icon: hasText ? AppIcons.send : AppIcons.mic,
                label: hasText ? 'Envoyer' : 'Dicter un message',
                bordered: false,
                background: AppColors.ink,
                foreground: Colors.white,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bulle des conversations Kéla : blanche (Kéla) ou noire (utilisateur).
class AiKelaBubble extends StatelessWidget {
  const AiKelaBubble(this.text, {super.key, this.outgoing = false, this.maxWidth = 276});

  final String text;
  final bool outgoing;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: outgoing ? const EdgeInsets.fromLTRB(18, 5, 18, 5) : const EdgeInsets.fromLTRB(18, 12, 18, 12),
        decoration: BoxDecoration(
          color: outgoing ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(outgoing ? 18 : 22),
        ),
        child: Text(
          text,
          style: AppText.body.copyWith(
            fontSize: 13.5,
            height: outgoing ? 1.35 : 1.5,
            color: outgoing ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Gabarit des conversations WhatsApp : barre sombre, fil de messages, compositeur.
class AiWhatsAppScaffold extends StatefulWidget {
  const AiWhatsAppScaffold({
    super.key,
    required this.messages,
    this.incomingWidth = 310,
    this.cardBuilder,
    this.onAction,
  });

  final List<AiMessage> messages;
  final double incomingWidth;

  /// Construit les cartes spéciales (jalon, paiement).
  final Widget Function(BuildContext context, AiMessage message)? cardBuilder;

  /// Action d'un bouton de réponse rapide ; renvoie `true` si elle est gérée sans envoyer de message.
  final bool Function(BuildContext context, String label)? onAction;

  @override
  State<AiWhatsAppScaffold> createState() => _AiWhatsAppScaffoldState();
}

class _AiWhatsAppScaffoldState extends State<AiWhatsAppScaffold> {
  final _sent = <AiMessage>[];
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _now {
    final t = TimeOfDay.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  void _send(String text) {
    setState(() => _sent.add((kind: AiMsgKind.outgoing, text: text, time: _now)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  void _action(String label) {
    if (widget.onAction?.call(context, label) ?? false) return;
    _send(label);
  }

  Widget _item(AiMessage m) {
    final w = widget.incomingWidth;
    return switch (m.kind) {
      AiMsgKind.day => Center(child: AiWhatsAppDayChip(m.text)),
      AiMsgKind.incoming => Align(
        alignment: Alignment.centerLeft,
        child: AiWhatsAppBubble(m.text, time: m.time, width: w),
      ),
      AiMsgKind.outgoing => Align(
        alignment: Alignment.centerRight,
        child: AiWhatsAppBubble(m.text, time: m.time, width: 300, outgoing: true),
      ),
      AiMsgKind.proof => Align(
        alignment: Alignment.centerLeft,
        child: AiWhatsAppProof(m.text, width: w),
      ),
      AiMsgKind.actions => Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: w,
          child: Column(
            children: [
              for (final (i, label) in m.text.split('|').indexed) ...[
                if (i > 0) const SizedBox(height: 4),
                AiWhatsAppAction(label, onTap: () => _action(label), strong: !label.startsWith('Demander')),
              ],
            ],
          ),
        ),
      ),
      _ => Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(width: w, child: widget.cardBuilder?.call(context, m) ?? const SizedBox.shrink()),
      ),
    };
  }

  double _gapAfter(List<AiMessage> all, int i) {
    final a = all[i].kind;
    final b = all[i + 1].kind;
    if (a == AiMsgKind.day) return 18;
    if (b == AiMsgKind.actions) return a == AiMsgKind.milestone ? 15 : 9;
    if (a == AiMsgKind.actions) return 19;
    if (a == AiMsgKind.outgoing || b == AiMsgKind.outgoing) return 14;
    return 10;
  }

  @override
  Widget build(BuildContext context) {
    final all = [...widget.messages, ..._sent];
    return Scaffold(
      backgroundColor: AppColors.bgTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Stack(
          children: [
            const Positioned.fill(child: AppBackgroundGlow()),
            Column(
              children: [
                const AiWhatsAppHeader(),
                Expanded(
                  child: ListView.separated(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    itemCount: all.length,
                    separatorBuilder: (_, i) => SizedBox(height: _gapAfter(all, i)),
                    itemBuilder: (_, i) => _item(all[i]),
                  ),
                ),
                SafeArea(top: false, child: AiWhatsAppComposer(onSend: _send)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Barre sombre WhatsApp : retour, logo, nom du compte professionnel.
class AiWhatsAppHeader extends StatelessWidget {
  const AiWhatsAppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final top = math.max(60.0, MediaQuery.paddingOf(context).top + 14);
    return Container(
      color: AppColors.ink,
      padding: EdgeInsets.fromLTRB(8, top, 19, 6),
      child: Row(
        children: [
          RoundIconButton(
            icon: AppIcons.arrowLeft,
            label: 'Retour',
            bordered: false,
            background: Colors.transparent,
            foreground: Colors.white,
            onTap: () => ScreenHeader.back(context),
          ),
          const SizedBox(width: 2),
          ClipOval(
            child: Image.asset(
              'assets/images/ai_logo_be.png',
              width: 40,
              height: 40,
              semanticLabel: 'Logo Boutik-École',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Boutik-École', style: AppText.h3.copyWith(fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 1),
                  Text(
                    'Compte professionnel · en ligne',
                    style: AppText.small.copyWith(color: const Color(0xFFB4B1BA)),
                  ),
                ],
              ),
            ),
          ),
          RoundIconButton(
            icon: AppIcons.messageCircle,
            label: 'Toutes les conversations',
            bordered: false,
            background: Colors.transparent,
            foreground: Colors.white,
            onTap: () => context.openScreen('52'),
          ),
        ],
      ),
    );
  }
}

/// Séparateur de date centré.
class AiWhatsAppDayChip extends StatelessWidget {
  const AiWhatsAppDayChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(11)),
    child: Text(label, style: AppText.small.copyWith(color: aiWhatsAppMuted)),
  );
}

/// Bulle WhatsApp avec l'heure en bas à droite.
class AiWhatsAppBubble extends StatelessWidget {
  const AiWhatsAppBubble(this.text, {super.key, required this.time, this.width = 310, this.outgoing = false});

  final String text;
  final String time;
  final double width;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
      decoration: BoxDecoration(
        color: outgoing ? aiWhatsAppOutgoing : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          aiCheckText(text, AppText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w400, height: 1.45)),
          if (time.isNotEmpty)
            Text(
              time,
              textAlign: TextAlign.end,
              style: AppText.small.copyWith(fontSize: 10.5, color: aiWhatsAppMuted, height: 1.3),
            ),
        ],
      ),
    );
  }
}

/// Photo de preuve avec l'étiquette « Preuve ».
class AiWhatsAppProof extends StatelessWidget {
  const AiWhatsAppProof(this.image, {super.key, this.width = 300});

  final String image;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 170,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(image, fit: BoxFit.cover, semanticLabel: 'Photo de preuve envoyée par l’équipe'),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
              child: Text(
                'Preuve',
                style: AppText.small.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton de réponse rapide (blanc, libellé vert ou noir).
class AiWhatsAppAction extends StatelessWidget {
  const AiWhatsAppAction(this.label, {super.key, required this.onTap, this.strong = true});

  final String label;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: Center(
              child: aiCheckText(label, AppText.bodyStrong.copyWith(color: strong ? aiWhatsAppText : AppColors.ink)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compositeur WhatsApp : champ « Message » et bouton vert d'envoi.
class AiWhatsAppComposer extends StatefulWidget {
  const AiWhatsAppComposer({super.key, required this.onSend});

  final ValueChanged<String> onSend;

  @override
  State<AiWhatsAppComposer> createState() => _AiWhatsAppComposerState();
}

class _AiWhatsAppComposerState extends State<AiWhatsAppComposer> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final error = AiValidators.chatMessage(_ctrl.text);
    setState(() => _error = error);
    if (error != null) return;
    widget.onSend(_ctrl.text.trim());
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 4),
              child: Text(
                _error!,
                style: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23)),
                  child: TextField(
                    controller: _ctrl,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _submit(),
                    style: AppText.body.copyWith(fontSize: 15),
                    decoration: aiBareInput(
                      'Message',
                      AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w400, color: const Color(0xFF75727C)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              RoundIconButton(
                icon: AppIcons.send,
                label: 'Envoyer',
                size: 46,
                bordered: false,
                background: aiWhatsAppGreen,
                foreground: Colors.white,
                onTap: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
