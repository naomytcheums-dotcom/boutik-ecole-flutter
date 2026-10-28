import '../../../core/utils/validators_e.dart';
import '../../common/common.dart';
import '../e_widgets.dart';

/// 48 · Réclamation sur une commande : motif, détails, photos.
class ReclamationScreen extends ConsumerStatefulWidget {
  const ReclamationScreen({super.key});

  @override
  ConsumerState<ReclamationScreen> createState() => _ReclamationScreenState();
}

class _ReclamationScreenState extends ConsumerState<ReclamationScreen> {
  final _form = GlobalKey<FormState>();
  final _details = TextEditingController();
  int _reason = 0;
  int _photos = 0;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _send(SectionEData d) {
    if (_form.currentState!.validate()) {
      context.toast('Demande envoyée. ${d.claimDelay}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionEDataProvider);
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none);
    OutlineInputBorder errorBorder(double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: AppColors.error, width: w),
    );
    return EScaffold(
      title: 'Réclamation',
      actions: [EButton('Envoyer la demande', onPressed: () => _send(d))],
      children: [
        const SizedBox(height: 2),
        ECard(
          child: ERow(
            height: 65.5,
            leading: EThumb(d.claimImage),
            title: 'Commande ${d.claimRef}',
            titleStyle: ETxt.itemRegular,
            overflowTitle: true,
            subtitle: '${d.claimDate} · ${fcfa(d.claimAmount)}',
            trailing: const EStatusBadge(EOrderStatus.inProgress),
          ),
        ),
        const SizedBox(height: 15.25),
        Semantics(header: true, child: Text('Motif de la demande', style: ETxt.section)),
        const SizedBox(height: 10.25),
        for (final (i, r) in d.claimReasons.indexed)
          ECheckRow(label: r, value: i == _reason, radio: true, onChanged: (_) => setState(() => _reason = i)),
        const SizedBox(height: 7.9),
        Text('Détails de la demande', style: ETxt.label),
        const SizedBox(height: 3.4),
        Form(
          key: _form,
          child: TextFormField(
            controller: _details,
            validator: ValidatorsE.claimDetails,
            minLines: 3,
            maxLines: 6,
            textAlignVertical: TextAlignVertical.top,
            maxLength: 1000,
            keyboardType: TextInputType.multiline,
            style: ETxt.itemRegular,
            decoration: InputDecoration(
              hintText: 'Décrivez le problème rencontré…',
              hintStyle: ETxt.itemRegular.copyWith(color: AppColors.textSecondary),
              counterText: '',
              filled: true,
              isDense: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.fromLTRB(12, 16.7, 12, 26.2),
              border: border,
              enabledBorder: border,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
              ),
              errorBorder: errorBorder(1.5),
              focusedErrorBorder: errorBorder(1.5),
              errorStyle: AppText.small.copyWith(color: AppColors.error, fontWeight: FontWeight.w600),
              errorMaxLines: 2,
            ),
          ),
        ),
        const SizedBox(height: 15),
        ECard(
          child: ERow(
            height: 65,
            leading: const ETile(AppIcons.camera),
            title: 'Ajouter des photos',
            subtitle: _photos == 0
                ? 'Preuves du problème (${d.claimMaxPhotos} max)'
                : '$_photos photo${_photos > 1 ? 's' : ''} ajoutée${_photos > 1 ? 's' : ''} (${d.claimMaxPhotos} max)',
            chevron: true,
            onTap: () {
              if (_photos >= d.claimMaxPhotos) {
                context.toast('${d.claimMaxPhotos} photos maximum.');
              } else {
                setState(() => _photos++);
              }
            },
          ),
        ),
        const SizedBox(height: 15),
        ENote(d.claimDelay, icon: AppIcons.clock),
      ],
    );
  }
}
