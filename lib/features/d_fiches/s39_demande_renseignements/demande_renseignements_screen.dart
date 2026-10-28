import '../../../core/utils/validators_d.dart';
import '../../common/common.dart';
import '../d_widgets.dart';

/// 39 · Demande de renseignements au vendeur (sujet, question, téléphone facultatif).
class DemandeRenseignementsScreen extends ConsumerStatefulWidget {
  const DemandeRenseignementsScreen({super.key});

  @override
  ConsumerState<DemandeRenseignementsScreen> createState() => _DemandeRenseignementsScreenState();
}

class _DemandeRenseignementsScreenState extends ConsumerState<DemandeRenseignementsScreen> {
  final _form = GlobalKey<FormState>();
  final _question = TextEditingController();
  final _phone = TextEditingController();
  int _topic = 0;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _question.text = ref.read(sectionDDataProvider).inquiryTopics.first.$2;
  }

  @override
  void dispose() {
    _question.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _selectTopic(int i, SectionDData d) {
    // Le modèle de question suit le sujet tant que l'utilisateur ne l'a pas réécrit.
    final untouched = _question.text.trim().isEmpty || d.inquiryTopics.any((t) => t.$2 == _question.text);
    setState(() {
      _topic = i;
      if (untouched) _question.text = d.inquiryTopics[i].$2;
    });
  }

  void _send() {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _sent = true);
    context.toast('Question envoyée au vendeur.');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionDDataProvider);
    return DScaffold(
      title: 'Demande de renseignements',
      actions: [DButton(_sent ? 'Question envoyée' : 'Envoyer la question', onPressed: _sent ? null : _send)],
      children: [
        const SizedBox(height: 2),
        DSummaryCard(
          leading: DPhoto(d.inquiryThumb, radius: 10, width: 50, height: 50),
          title: d.productTitle,
          subtitle: '${fcfa(d.productPrice)} · ${d.creatorShort}',
          onTap: () => context.openScreen('32'),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              for (final (i, t) in d.inquiryTopics.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                DChoiceChip(t.$1, selected: i == _topic, onTap: () => _selectTopic(i, d)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 9.5),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DFieldLabel('Votre question'),
              DTextField(
                controller: _question,
                label: 'Votre question',
                lines: 3,
                height: 94,
                validator: ValidatorsD.question,
                style: DTxt.item.copyWith(
                  fontSize: 13.6,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6E6B76),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 15),
              const DFieldLabel('Votre téléphone (facultatif)'),
              DTextField(
                controller: _phone,
                label: 'Votre téléphone (facultatif)',
                hint: d.inquiryPhoneHint,
                icon: AppIcons.smartphone,
                keyboardType: TextInputType.phone,
                validator: ValidatorsD.optionalPhone,
                hintStyle: DTxt.item.copyWith(fontWeight: FontWeight.w500, height: 1.5),
              ),
              const SizedBox(height: 15),
              DNote(icon: AppIcons.messageCircle, text: d.inquiryNote),
            ],
          ),
        ),
      ],
    );
  }
}
