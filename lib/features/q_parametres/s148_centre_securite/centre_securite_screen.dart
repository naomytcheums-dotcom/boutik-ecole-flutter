import '../q_widgets.dart';

/// 148 (2/2) · Centre de sécurité.
class CentreSecuriteScreen extends ConsumerStatefulWidget {
  const CentreSecuriteScreen({super.key});

  @override
  ConsumerState<CentreSecuriteScreen> createState() => _CentreSecuriteScreenState();
}

class _CentreSecuriteScreenState extends ConsumerState<CentreSecuriteScreen> {
  bool _twoFactor = true;
  final _closed = <String>{};

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionQDataProvider);
    final sessions = d.sessions.where((s) => !_closed.contains(s.$2)).toList();
    return CPage(
      title: 'Centre de sécurité',
      tab: NavTab.profile,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF7F0),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFB8E4CB), width: 1.4),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const AppIcon(AppIcons.shieldCheck, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Compte bien protégé', style: AppText.bodyStrong.copyWith(fontSize: 15)),
                        Text('Niveau de sécurité : ${d.securityLevel}', style: AppText.small.copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${d.securityScore} %', style: AppText.label.copyWith(color: AppColors.success)),
              ),
              const SizedBox(height: 4),
              ProgressLine(value: d.securityScore / 100, color: AppColors.success, height: 5),
            ],
          ),
        ),
        const GSectionTitle('Accès et protection'),
        QCard(
          children: [
            QRow(
              icon: AppIcons.keyRound,
              title: 'Changer le mot de passe',
              subtitle: d.passwordAge,
              trailing: const AppIcon(AppIcons.chevronRight, size: 18),
              onTap: () => context.openScreen('16'),
            ),
            QRow(
              icon: AppIcons.shieldCheck,
              title: 'Double authentification',
              subtitle: 'Code SMS à chaque connexion',
              trailing: Toggle(value: _twoFactor, label: 'Double authentification', onChanged: (v) => setState(() => _twoFactor = v)),
            ),
            QRow(
              icon: AppIcons.smartphone,
              title: 'Téléphone vérifié',
              subtitle: d.verifiedPhone,
              trailing: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const AppIcon(AppIcons.check, size: 13, color: Colors.white, semanticLabel: 'Vérifié'),
              ),
            ),
          ],
        ),
        GSectionTitle(
          'Appareils et sessions',
          trailing: Text('${sessions.length} actif${sessions.length > 1 ? 's' : ''}', style: AppText.small),
        ),
        QCard(
          children: [
            for (final s in sessions)
              QRow(
                icon: s.$1,
                title: s.$2,
                subtitle: s.$3,
                trailing: s.$4
                    ? const StatusDot(AppColors.success, size: 8)
                    : TextLink('Déconnecter', color: AppColors.error, onTap: () => setState(() => _closed.add(s.$2))),
              ),
          ],
        ),
        gap16,
        QDangerButton(
          'Se déconnecter de tous les appareils',
          onTap: () {
            setState(() => _closed.addAll([for (final s in d.sessions) if (!s.$4) s.$2]));
            context.toast('Toutes les autres sessions ont été fermées.');
          },
        ),
      ],
    );
  }
}
