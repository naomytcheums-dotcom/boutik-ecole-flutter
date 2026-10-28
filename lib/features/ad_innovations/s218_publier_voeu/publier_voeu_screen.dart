import '../../../core/utils/validators_ad.dart';
import '../ad_widgets.dart';

/// 218 · Publier un vœu (formulaire en 4 étapes, ici l'étape « Prix »).
class PublierVoeuScreen extends ConsumerStatefulWidget {
  const PublierVoeuScreen({super.key});

  @override
  ConsumerState<PublierVoeuScreen> createState() => _PublierVoeuScreenState();
}

class _PublierVoeuScreenState extends ConsumerState<PublierVoeuScreen> {
  final _form = GlobalKey<FormState>();
  String? _duration;

  void _publish() {
    if (_form.currentState?.validate() ?? false) {
      context.toast('Vœu envoyé : votre département le valide sous 48 h.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionADDataProvider);
    const gap = SizedBox(height: 14);
    return AdPage(
      header: const AdBackHeader('Publier un vœu'),
      actions: [
        GOutlineButton('Brouillon', onPressed: () => context.toast('Brouillon enregistré.')),
        PrimaryButton(label: 'Publier', height: 54, onPressed: _publish),
      ],
      children: [
        AdStepper(labels: d.wishSteps218, current: 1),
        const SizedBox(height: 14),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PillTextField(
                label: 'Que voulez-vous fabriquer ?',
                icon: AppIcons.lightbulb,
                initialValue: d.draftWish,
                validator: ValidatorsAD.wishTitle,
              ),
              gap,
              PillTextField(
                label: 'Description et photos',
                hint: 'Dessin, matériaux, taille, cible…',
                maxLines: 3,
                minHeight: 95,
                validator: ValidatorsAD.description,
              ),
              gap,
              PillTextField(
                label: 'Prix prévu',
                icon: AppIcons.wallet,
                initialValue: fcfa(d.draftPrice),
                keyboardType: TextInputType.number,
                validator: ValidatorsAD.price,
              ),
              gap,
              PillTextField(
                label: 'Seuil minimum de précommandes',
                icon: AppIcons.users,
                initialValue: d.draftThreshold,
                keyboardType: TextInputType.number,
                validator: ValidatorsAD.threshold,
              ),
              gap,
              PillSelectField(
                label: 'Durée de la campagne',
                icon: AppIcons.calendar,
                options: d.campaignDurations,
                value: _duration ?? d.campaignDurations[1],
                onChanged: (v) => setState(() => _duration = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AdNote(d.validationNote, icon: AppIcons.circleCheck),
      ],
    );
  }
}
