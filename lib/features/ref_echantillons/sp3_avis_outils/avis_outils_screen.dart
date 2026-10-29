import 'package:flutter/services.dart';

import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

/// P3 · Avis vérifiés, recommandations et outils connectés du talent.
class AvisOutilsScreen extends ConsumerWidget {
  const AvisOutilsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(sectionREFDataProvider);
    final title = AppText.h3.copyWith(fontSize: 17, fontWeight: FontWeight.w600);
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      background: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: [0, 0.12, 0.3, 1],
        colors: [Color(0xFFFDF0DA), Color(0xFFFFF8EE), Colors.white, Colors.white],
      ),
      header: RefHeader(
        title: d.talentName,
        titleTrailing: const RefVerifiedDot(size: 18),
        trailing: RefGlassButton(
          icon: AppIcons.share,
          label: 'Partager le profil',
          onTap: () => context.toast('Lien du profil prêt à partager'),
        ),
      ),
      children: [
        const SizedBox(height: 12),
        RefCard(
          radius: 26,
          padding: const EdgeInsets.fromLTRB(22, 18, 18, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.rating, style: AppText.display.copyWith(fontSize: 48, fontWeight: FontWeight.w700, height: 1)),
                  const SizedBox(height: 4),
                  const RefStars(size: 18, spacing: 3),
                  const SizedBox(height: 10),
                  Text('${d.reviewCount} avis vérifiés', style: AppText.small),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    for (final (label, value) in d.ratingBars)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(width: 26, child: Text(label, style: AppText.small.copyWith(fontSize: 11))),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: value,
                                  minHeight: 6,
                                  color: refStar,
                                  backgroundColor: const Color(0xFFF0EEF2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: const Color(0xFFE4F4EA), borderRadius: BorderRadius.circular(26)),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(color: Color(0xFF1F9D63), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const AppIcon(AppIcons.check, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recommandée par ${d.recommendedClients} clients et ${d.recommendedCompanies} entreprises',
                  style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.success),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Semantics(header: true, child: Text('Avis des clients', style: title)),
        const SizedBox(height: 10),
        for (final (author, text, avatar, stars) in d.reviews) ...[
          RefCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Avatar(image: avatar, size: 36),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(author, style: AppText.body.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        RefStars(value: stars, size: 13),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(text, style: AppText.secondary.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 2),
        Semantics(header: true, child: Text('Mes outils connectés', style: title)),
        const SizedBox(height: 4),
        Text(
          'Tu choisis toi-même les réseaux et outils reliés à ton profil, selon ton métier.',
          style: AppText.small.copyWith(fontSize: 11.2, height: 1.45),
        ),
        const SizedBox(height: 12),
        for (final (name, detail, logo) in d.profileTools) ...[
          RefCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: RefToolRow(
              name: name,
              detail: detail,
              logo: logo,
              logoSize: 36,
              trailing: RefChipButton(
                'Visiter',
                height: 30,
                fontSize: 12,
                padding: 14,
                onTap: () => context.toast('Ouverture de $name'),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 4),
        RefDashedAddCard(
          title: 'Connecter un autre outil',
          subtitle: 'Réseaux, portfolio, gestion de projet, paiement…',
          onTap: () => context.openScreen('P5'),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(colors: [Color(0xFF1E1A33), Color(0xFF3A2D78)]),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suivre hors de l’appli', style: title.copyWith(color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                'Les clients peuvent suivre Aminata sur ses réseaux sans quitter sa recommandation Boutik-École.',
                style: AppText.small.copyWith(color: const Color(0xFFD9D5EC), height: 1.45),
              ),
              const SizedBox(height: 12),
              RefChipButton(
                'Copier le lien',
                leading: AppIcons.link,
                color: Colors.white,
                height: 30,
                fontSize: 12,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: d.profileLink));
                  context.toast('Lien copié');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
