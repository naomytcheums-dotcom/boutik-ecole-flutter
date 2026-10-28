import '../../../core/utils/validators_y.dart';
import '../y_widgets.dart';

/// 195 · Ajouter une preuve : l'équipe dépose photos / vidéo et décrit le travail du jalon.
class AjouterPreuveScreen extends ConsumerStatefulWidget {
  const AjouterPreuveScreen({super.key});

  @override
  ConsumerState<AjouterPreuveScreen> createState() => _AjouterPreuveScreenState();
}

class _AjouterPreuveScreenState extends ConsumerState<AjouterPreuveScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text = TextEditingController(text: ref.read(sectionYDataProvider).proofText);
  final _media = <String>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add(String kind) => setState(() => _media.add(kind));

  void _send() {
    if (!_form.currentState!.validate()) return;
    context.toast('Preuve envoyée : le client est notifié.');
    context.openScreen('201');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    final (stage, detail, status) = d.proofStage;
    return GPage(
      title: 'Ajouter une preuve',
      actions: [
        YOutlineButton('Brouillon', onPressed: () => context.toast('Brouillon enregistré.')),
        PrimaryButton(label: 'Envoyer pour validation', onPressed: _send),
      ],
      children: [
        YCard(
          children: [
            YIconRow(icon: AppIcons.layers, title: stage, subtitle: detail, trailing: YBadge(status, Tone.accent)),
          ],
        ),
        const YTitle('Photos ou vidéo du travail', top: 14, bottom: 0),
        SizedBox(
          height: 121,
          child: _media.isEmpty
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    children: [
                      for (final (i, m) in _media.indexed)
                        Semantics(
                          label: '$m ${i + 1}',
                          excludeSemantics: true,
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            alignment: Alignment.center,
                            child: AppIcon(m == 'Photo' ? AppIcons.image : AppIcons.video, size: 24),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
        YCard(
          children: [
            YIconRow(
              icon: AppIcons.camera,
              title: 'Prendre une photo',
              onTap: () => _add('Photo'),
              trailing: const AppIcon(AppIcons.chevronRight, size: 20),
            ),
            YIconRow(
              icon: AppIcons.upload,
              title: 'Importer une vidéo',
              subtitle: '2 minutes maximum',
              onTap: () => _add('Vidéo'),
              trailing: const AppIcon(AppIcons.chevronRight, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const YLabel('Ce qui a été réalisé'),
        Form(
          key: _form,
          child: YTextArea(controller: _text, label: 'Ce qui a été réalisé', validator: validateProofDescription),
        ),
        const SizedBox(height: 14),
        const YNote(
          'Le client est notifié dès l’envoi et peut valider ou demander une correction.',
          icon: AppIcons.bell,
        ),
      ],
    );
  }
}
