import '../../../core/utils/validators_d.dart';
import '../../common/common.dart';
import '../d_widgets.dart';

/// 40 · Demande de devis à un prestataire (objet, besoin, budget, délai, cahier des charges).
class DemandeDevisScreen extends ConsumerStatefulWidget {
  const DemandeDevisScreen({super.key});

  @override
  ConsumerState<DemandeDevisScreen> createState() => _DemandeDevisScreenState();
}

class _DemandeDevisScreenState extends ConsumerState<DemandeDevisScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _need = TextEditingController();
  int? _budget;
  int? _delay;
  bool _attached = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _subject.text = ref.read(sectionDDataProvider).quoteSubject;
  }

  @override
  void dispose() {
    _subject.dispose();
    _need.dispose();
    super.dispose();
  }

  void _send() {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _sent = true);
    context.toast('Demande de devis envoyée.');
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionDDataProvider);
    final budgets = [for (final b in d.quoteBudgets) '${fcfa(b.$1, withUnit: false)} – ${fcfa(b.$2)}'];
    return DScaffold(
      title: 'Demande de devis',
      actions: [DButton(_sent ? 'Demande envoyée' : 'Envoyer la demande', onPressed: _sent ? null : _send)],
      children: [
        const SizedBox(height: 2),
        DSummaryCard(
          leading: DAvatar(d.providerAvatar, size: 50),
          title: d.serviceProvider,
          subtitle: d.serviceTitle,
          onTap: () => context.openScreen('36'),
        ),
        const SizedBox(height: 13),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DFieldLabel('Objet de la demande'),
              DTextField(
                controller: _subject,
                label: 'Objet de la demande',
                icon: AppIcons.tag,
                validator: ValidatorsD.quoteSubject,
              ),
              const SizedBox(height: 15.5),
              const DFieldLabel('Description du besoin'),
              DTextField(
                controller: _need,
                label: 'Description du besoin',
                hint: 'Décrivez votre projet, vos attentes et vos contraintes…',
                lines: 3,
                height: 96,
                validator: ValidatorsD.quoteNeed,
              ),
              const SizedBox(height: 15.5),
              const DFieldLabel('Budget estimé'),
              DSelectField(
                label: 'Budget estimé',
                icon: AppIcons.wallet,
                options: budgets,
                selected: _budget ?? d.quoteBudgetIndex,
                onChanged: (i) => setState(() => _budget = i),
              ),
              const SizedBox(height: 15.5),
              const DFieldLabel('Délai souhaité'),
              DSelectField(
                label: 'Délai souhaité',
                icon: AppIcons.calendar,
                options: d.quoteDelays,
                selected: _delay ?? d.quoteDelayIndex,
                onChanged: (i) => setState(() => _delay = i),
              ),
              const SizedBox(height: 16),
              DSummaryCard(
                leading: const DTile(AppIcons.upload),
                title: _attached ? 'cahier_des_charges.pdf' : 'Joindre un cahier des charges',
                subtitle: _attached ? 'PDF · 1,2 Mo · Touchez pour retirer' : d.quoteAttachmentHint,
                trailing: AppIcon(_attached ? AppIcons.x : AppIcons.chevronRight, size: 18),
                onTap: () => setState(() => _attached = !_attached),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
