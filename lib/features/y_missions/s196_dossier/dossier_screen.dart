import '../y_widgets.dart';

/// 196 · Dossier : fil de discussion, fichiers, paiements et équipe d'une mission.
class DossierScreen extends ConsumerStatefulWidget {
  const DossierScreen({super.key});

  @override
  ConsumerState<DossierScreen> createState() => _DossierScreenState();
}

class _DossierScreenState extends ConsumerState<DossierScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    final (fileName, fileDetail) = d.sharedFile;
    final (n, amount, paidDetail) = d.paidMilestone;
    final fileRow = YIconRow(
      icon: AppIcons.file,
      title: fileName,
      subtitle: fileDetail,
      trailing: Semantics(
        button: true,
        label: 'Voir $fileName',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => context.toast('Ouverture de $fileName'),
          child: const YBadge('Voir', Tone.accent),
        ),
      ),
    );
    final payRow = YIconRow(
      icon: AppIcons.receipt,
      title: 'Jalon $n · ${fcfa(amount)}',
      subtitle: paidDetail,
      trailing: const YBadge('Payé', Tone.success),
    );
    return GPage(
      title: 'Dossier #${d.fileNumber}',
      actions: [
        YOutlineButton('Ajouter un fichier', onPressed: () => context.toast('Choisissez un fichier à partager.')),
        PrimaryButton(label: 'Envoyer', onPressed: () => context.toast('Message envoyé à l’équipe.')),
      ],
      children: [
        Transform.translate(
          offset: const Offset(0, -7),
          child: YTabs(labels: d.fileTabs, selected: _tab, onSelected: (i) => setState(() => _tab = i)),
        ),
        const SizedBox(height: 2),
        const _TeamFaces(count: 4),
        const SizedBox(height: 14),
        ...switch (_tab) {
          0 => [
            for (final (text, time, mine) in d.messages) _Bubble(text: text, time: time, mine: mine),
            const SizedBox(height: 14),
            YCard(children: [fileRow, payRow]),
          ],
          1 => [
            YCard(children: [fileRow]),
          ],
          2 => [
            YCard(children: [payRow]),
          ],
          _ => [
            YCard(
              children: [
                for (final (name, role) in d.fileTeam) YIconRow(icon: AppIcons.user, title: name, subtitle: role),
              ],
            ),
          ],
        },
      ],
    );
  }
}

/// Pastilles rondes superposées des membres de l'équipe.
class _TeamFaces extends StatelessWidget {
  const _TeamFaces({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Équipe de $count personnes',
    excludeSemantics: true,
    child: SizedBox(
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * 32.0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.time, required this.mine});

  final String text;
  final String time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: mine ? 88 : 0, right: mine ? 0 : 88, bottom: 6),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: mine ? AppColors.ink : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              style: AppText.body.copyWith(fontSize: 13, height: 1.45, color: mine ? Colors.white : AppColors.ink),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
            child: Text(time, style: AppText.small.copyWith(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
