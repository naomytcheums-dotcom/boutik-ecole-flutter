import '../../../core/utils/validators_ai.dart';
import '../../common/common.dart';
import '../ai_widgets.dart';

/// 236 · Canaux et notifications : choix des canaux de suivi des missions et numéro WhatsApp.
class CanauxNotificationsScreen extends ConsumerStatefulWidget {
  const CanauxNotificationsScreen({super.key});

  @override
  ConsumerState<CanauxNotificationsScreen> createState() => _CanauxNotificationsScreenState();
}

class _CanauxNotificationsScreenState extends ConsumerState<CanauxNotificationsScreen> {
  final _form = GlobalKey<FormState>();
  Map<String, bool>? _enabled;

  void _save() {
    if (!(_form.currentState?.validate() ?? false)) return;
    context.toast('Préférences enregistrées');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAIDataProvider);
    final enabled = _enabled ??= {for (final c in d.channels) c.title: c.enabled};
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: AppScaffold(
              showNav: false,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              header: const _Header('Canaux et notifications'),
              children: _content(d, enabled),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 15, 24, 30),
            child: SafeArea(
              top: false,
              child: PrimaryButton(label: 'Enregistrer', height: 54, onPressed: _save),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _content(SectionAIData d, Map<String, bool> enabled) {
    return [
      Semantics(
        header: true,
        child: Text('Où voulez-vous suivre vos missions ?', style: AppText.bodyStrong.copyWith(fontSize: 15)),
      ),
      const SizedBox(height: 18),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          children: [
            for (final (i, c) in d.channels.indexed) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, indent: 12, endIndent: 12, color: Color(0xFFF0EEEC)),
              _ChannelRow(
                channel: c,
                enabled: enabled[c.title]!,
                onToggle: c.locked ? null : () => setState(() => enabled[c.title] = !enabled[c.title]!),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 15),
      Form(
        key: _form,
        child: PillTextField(
          label: 'Numéro WhatsApp',
          icon: AppIcons.messageCircle,
          initialValue: d.whatsappNumber,
          keyboardType: TextInputType.phone,
          validator: (v) => enabled['WhatsApp']! ? AiValidators.whatsappNumber(v, saved: d.whatsappNumber) : null,
        ),
      ),
      const SizedBox(height: 15),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
        decoration: BoxDecoration(color: const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const AppIcon(AppIcons.shieldCheck, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucune donnée bancaire n’est demandée dans WhatsApp : le paiement passe par votre application Mobile Money.',
                style: AppText.small.copyWith(color: const Color(0xFF4A4854), height: 1.45),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

/// En-tête : flèche retour et titre gras aligné à gauche.
class _Header extends StatelessWidget {
  const _Header(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(19, 34, 20, 7),
      child: Row(
        children: [
          RoundIconButton(
            icon: AppIcons.arrowLeft,
            label: 'Retour',
            bordered: false,
            background: Colors.transparent,
            onTap: () => ScreenHeader.back(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AppText.h1.copyWith(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ligne de canal : pictogramme, nom, usage, état (cliquable sauf canal obligatoire).
class _ChannelRow extends StatelessWidget {
  const _ChannelRow({required this.channel, required this.enabled, required this.onToggle});

  final AiChannel channel;
  final bool enabled;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onToggle != null,
      toggled: enabled,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: 65,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: channel.whatsapp ? const Color(0xFFDDF5EC) : const Color(0xFFF1EEFB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: AppIcon(channel.icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        channel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Text(channel.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StateBadge(enabled: enabled),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: enabled ? const Color(0xFFDDF5EC) : const Color(0xFFF2EFF6),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      enabled ? 'Activé' : 'Désactivé',
      style: AppText.small.copyWith(
        fontWeight: FontWeight.w600,
        color: enabled ? AppColors.success : AppColors.textSecondary,
      ),
    ),
  );
}
