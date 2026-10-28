import '../s_widgets.dart';

/// 156 · Préférences d’alertes.
class PreferencesAlertesScreen extends ConsumerStatefulWidget {
  const PreferencesAlertesScreen({super.key});

  @override
  ConsumerState<PreferencesAlertesScreen> createState() => _PreferencesAlertesScreenState();
}

class _PreferencesAlertesScreenState extends ConsumerState<PreferencesAlertesScreen> {
  late final d = ref.read(sectionSDataProvider);
  late final _channels = [for (final c in d.channels) c.$3];
  late final _types = [for (final t in d.alertTypes) t.$3];
  late String _frequency = d.frequencies.first;

  @override
  Widget build(BuildContext context) {
    return GPage(
      title: 'Préférences d’alertes',
      actions: [
        PrimaryButton(
          label: 'Enregistrer les préférences',
          height: 54,
          onPressed: () => context.toast('Préférences enregistrées.'),
        ),
      ],
      children: [
        Text('Canaux', style: AppText.bodyStrong),
        gap8,
        QCard(
          children: [
            for (final (i, c) in d.channels.indexed)
              ToggleRow(
                title: c.$1,
                subtitle: c.$2,
                value: _channels[i],
                onChanged: i == 0 ? (_) {} : (v) => setState(() => _channels[i] = v),
              ),
          ],
        ),
        gap16,
        Text('Types d’alertes', style: AppText.bodyStrong),
        gap8,
        QCard(
          children: [
            for (final (i, t) in d.alertTypes.indexed)
              ToggleRow(title: t.$1, subtitle: t.$2, value: _types[i], onChanged: (v) => setState(() => _types[i] = v)),
          ],
        ),
        gap16,
        SelectField(
          label: 'Fréquence',
          icon: AppIcons.clock,
          options: d.frequencies,
          value: _frequency,
          onChanged: (v) => setState(() => _frequency = v),
        ),
        gap12,
        const GNote('L’IA n’envoie jamais d’alerte sans votre accord et vous pouvez tout désactiver.', icon: AppIcons.shieldCheck),
      ],
    );
  }
}
