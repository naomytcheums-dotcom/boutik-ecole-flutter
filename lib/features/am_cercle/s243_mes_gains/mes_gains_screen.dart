import '../am_widgets.dart';

/// 243 · Mes gains : solde de parrainage, retrait Mobile Money, filleuls.
class MesGainsScreen extends ConsumerWidget {
  const MesGainsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionAMDataProvider);
    return AppScaffold(
      tab: NavTab.home,
      header: ScreenHeader(
        title: 'Mes gains',
        subtitle: 'Parrainage et ambassadeur',
        actions: [AmHeaderButton(AppIcons.wallet, label: 'Portefeuille', onTap: () {})],
      ),
      children: [
        AmCard(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Solde disponible', style: AppText.secondary)),
                  AmChip(
                    '+ ${fcfa(d.monthGain, withUnit: false)} ce mois',
                    tone: Tone.success,
                    height: 26,
                    fontSize: 11,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                fcfa(d.balance),
                style: AppText.display.copyWith(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              gap12,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Bars(d.gainBars),
                  const Spacer(),
                  AmChip(
                    'Retirer vers Orange Money',
                    dark: true,
                    height: 44,
                    fontSize: 12.5,
                    onTap: () => context.toast('Retrait de ${fcfa(d.balance)} demandé'),
                  ),
                ],
              ),
            ],
          ),
        ),
        gap16,
        Row(
          children: [
            for (var i = 0; i < d.gainStats.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: AmCard(
                  radius: 24,
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.gainStats[i].$1, style: AppText.h2.copyWith(fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(d.gainStats[i].$2, style: AppText.small),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text('Mes filleuls', style: AppText.h3.copyWith(fontWeight: FontWeight.w600)),
        ),
        gap12,
        AmCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 20, 8),
          child: Column(
            children: [
              for (var i = 0; i < d.referrals.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
                _ReferralRow(d.referrals[i], d.referralAvatars[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars(this.values);

  final List<double> values;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Évolution des gains sur 7 semaines',
    child: SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Container(
              width: 8,
              height: 52 * values[i],
              decoration: BoxDecoration(
                color: i == values.length - 1 ? amViolet : const Color(0xFFD9D1F5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ReferralRow extends StatelessWidget {
  const _ReferralRow(this.r, this.avatar);

  final AmReferral r;
  final String avatar;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: Row(
      children: [
        Avatar(image: avatar, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              AmChip(
                r.status,
                height: 22,
                fontSize: 10.5,
                tone: switch (r.tone) {
                  0 => Tone.success,
                  1 => Tone.accent,
                  _ => Tone.warning,
                },
              ),
            ],
          ),
        ),
        Text(r.gain == null ? '—' : '+ ${fcfaF(r.gain!)}', style: AppText.bodyStrong),
      ],
    ),
  );
}
