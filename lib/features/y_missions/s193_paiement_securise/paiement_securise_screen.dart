import '../y_widgets.dart';

/// 193 · Paiement sécurisé : récapitulatif, répartition par jalons et moyen de paiement.
class PaiementSecuriseScreen extends ConsumerStatefulWidget {
  const PaiementSecuriseScreen({super.key});

  @override
  ConsumerState<PaiementSecuriseScreen> createState() => _PaiementSecuriseScreenState();
}

class _PaiementSecuriseScreenState extends ConsumerState<PaiementSecuriseScreen> {
  int _method = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionYDataProvider);
    int part(int pct) => d.quoteTotal * pct ~/ 100;
    final first = part(d.milestones.first.$2);
    return GPage(
      title: 'Paiement sécurisé',
      actions: [
        PrimaryButton(
          label: 'Payer ${fcfa(first)}',
          onPressed: () {
            context.toast(
              'Paiement de ${fcfa(first)} via ${d.paymentMethods[_method].$1} : montant placé en séquestre.',
            );
            context.openScreen('194');
          },
        ),
      ],
      children: [
        YKvCard(
          title: 'Récapitulatif',
          rows: [
            ('Mission', d.missionLabel),
            ('Total', fcfa(d.quoteTotal)),
            ('Frais plateforme inclus', fcfa(d.platformFees)),
          ],
        ),
        const YTitle('Réparti par jalons', top: 18, bottom: 18),
        YVTimeline(
          steps: [
            for (final (i, (t, pct)) in d.milestones.indexed) YVStep(t, '$pct % · ${fcfa(part(pct))}', i == 0 ? 1 : 2),
          ],
        ),
        const YTitle('Moyen de paiement', top: 32, bottom: 14),
        YCard(
          children: [
            for (final (i, (name, detail)) in d.paymentMethods.indexed)
              Semantics(
                selected: i == _method,
                child: YIconRow(
                  icon: AppIcons.wallet,
                  title: name,
                  subtitle: detail,
                  onTap: () => setState(() => _method = i),
                  trailing: i == _method
                      ? const YBadge('Choisi', Tone.success)
                      : const AppIcon(AppIcons.chevronRight, size: 20),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const YNote(
          'L’argent est bloqué par Boutik-École et versé aux étudiants uniquement après votre validation de chaque jalon.',
          icon: AppIcons.lock,
        ),
      ],
    );
  }
}
