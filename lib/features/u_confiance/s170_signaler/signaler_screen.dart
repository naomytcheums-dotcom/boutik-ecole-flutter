import '../u_widgets.dart';

/// 170 · Signaler une annonce.
class SignalerScreen extends ConsumerStatefulWidget {
  const SignalerScreen({super.key});

  @override
  ConsumerState<SignalerScreen> createState() => _SignalerScreenState();
}

class _SignalerScreenState extends ConsumerState<SignalerScreen> {
  final _selected = <int>{0};
  bool _submitted = false;

  void _send() {
    setState(() => _submitted = true);
    if (_selected.isEmpty) return;
    context.toast('Signalement envoyé à l’équipe de modération.');
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionUDataProvider);
    final l = d.listing;
    return GPage(
      title: 'Signaler une annonce',
      actions: [
        GOutlineButton('Annuler', onPressed: () => Navigator.of(context).maybePop()),
        QDangerButton('Envoyer le signalement', onTap: _send),
      ],
      children: [
        UListingCard(image: l.image, title: l.title, subtitle: '${fcfa(l.price)} · Vendeur : ${l.seller}'),
        const GSectionTitle('Motif du signalement'),
        for (var i = 0; i < d.reportReasons.length; i++)
          CheckRow(
            label: d.reportReasons[i],
            value: _selected.contains(i),
            onChanged: (v) => setState(() => v ? _selected.add(i) : _selected.remove(i)),
          ),
        if (_submitted && _selected.isEmpty)
          Text('Choisissez au moins un motif.', style: AppText.small.copyWith(color: AppColors.error)),
        gap12,
        const TextFieldWithError(
          label: 'Précisions (facultatif)',
          hint: 'Expliquez ce qui pose problème…',
          maxLines: 4,
        ),
        gap16,
        const GNote(
          'Votre signalement est anonyme pour le vendeur et examiné par l’équipe de modération sous 24 h.',
          icon: AppIcons.shieldCheck,
        ),
      ],
    );
  }
}
