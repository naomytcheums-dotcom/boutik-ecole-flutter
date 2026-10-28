import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../ad_widgets.dart';

/// 228 · Partager mon CV (QR code, lien, visibilité pour les recruteurs).
class PartagerCvScreen extends ConsumerStatefulWidget {
  const PartagerCvScreen({super.key});

  @override
  ConsumerState<PartagerCvScreen> createState() => _PartagerCvScreenState();
}

class _PartagerCvScreenState extends ConsumerState<PartagerCvScreen> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    final link = _version == 0 ? d.cvLink : '${d.cvLink}-$_version';
    return AdPage(
      header: const AdBackHeader('Partager mon CV'),
      floatingAction: PrimaryButton(
        label: 'Régénérer le lien',
        height: 52,
        onPressed: () {
          setState(() => _version++);
          context.toast('Nouveau lien créé : l’ancien ne fonctionne plus.');
        },
      ),
      children: [
        const SizedBox(height: 14),
        Center(
          child: Container(
            width: 202,
            height: 202,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: adShadow,
            ),
            alignment: Alignment.center,
            child: Image.asset(
              'assets/images/ad_qr_cv.png',
              width: 170,
              height: 170,
              filterQuality: FilterQuality.none,
              semanticLabel: 'QR code de mon CV',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          link,
          textAlign: TextAlign.center,
          style: AppText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Un recruteur le scanne et voit votre CV à jour',
          textAlign: TextAlign.center,
          style: AppText.small.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 44),
        AdCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Column(
            children: [
              _ActionRow(
                icon: AppIcons.link,
                label: 'Copier le lien',
                trailing: GBadge('Copier', Tone.accent),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: 'https://$link'));
                  context.toast('Lien copié.');
                },
              ),
              _ActionRow(
                icon: AppIcons.share,
                label: 'Envoyer par WhatsApp',
                onTap: () => context.toast('Ouverture de WhatsApp…'),
              ),
              _ActionRow(
                icon: AppIcons.download,
                label: 'Télécharger en PDF',
                onTap: () => context.toast('CV téléchargé en PDF.'),
              ),
            ],
          ),
        ),
        const AdSectionTitle('Ce que les recruteurs voient', top: 20, bottom: 10),
        AdCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final (i, v) in d.cvVisibility.indexed) ...[
                if (i > 0) const Divider(height: 1, color: Color(0xFFEDEBF0)),
                SizedBox(
                  height: 66,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.$1, style: AppText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(v.$2, style: AppText.small.copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      Text(
                        v.$3 ? 'Oui' : 'Non',
                        style: AppText.label.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, required this.onTap, this.trailing});

  final String icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 51,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: adLavender, borderRadius: BorderRadius.circular(10)),
              alignment: Alignment.center,
              child: AppIcon(icon, size: 17),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: AppText.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
            trailing ?? const AppIcon(AppIcons.chevronRight, size: 18),
          ],
        ),
      ),
    ),
  );
}
