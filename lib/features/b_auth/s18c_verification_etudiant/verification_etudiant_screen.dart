import '../auth_common.dart';

/// 18c · Vérification étudiant (matricule, filière, pièces justificatives).
class VerificationEtudiantScreen extends ConsumerStatefulWidget {
  const VerificationEtudiantScreen({super.key});

  @override
  ConsumerState<VerificationEtudiantScreen> createState() => _VerificationEtudiantScreenState();
}

class _VerificationEtudiantScreenState extends ConsumerState<VerificationEtudiantScreen> {
  String _field = 'Génie informatique';
  String? _level;
  bool _certificate = false;
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionBDataProvider);
    return AuthScreen(
      title: 'Vérification étudiant',
      children: [
        const InfoNote(
          'Ces informations permettent de confirmer votre statut d’étudiant de l’IUT de Douala.',
          icon: AppIcons.info,
        ),
        gap16,
        TextFieldWithError(label: 'Matricule', initialValue: d.studentId, prefixIcon: AppIcons.graduationCap),
        gap16,
        SelectField(
          label: 'Filière',
          icon: AppIcons.graduationCap,
          options: d.departments,
          value: _field,
          onChanged: (v) => setState(() => _field = v),
        ),
        gap16,
        SelectField(
          label: 'Niveau d’étude',
          icon: AppIcons.graduationCap,
          hint: 'Sélectionnez votre niveau',
          options: d.levels,
          value: _level,
          errorText: _submitted && _level == null ? 'Le niveau d’étude est obligatoire.' : null,
          onChanged: (v) => setState(() => _level = v),
        ),
        gap16,
        Text('Pièces justificatives', style: AppText.h3),
        gap12,
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: const Color(0xFFF1EFF6), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: const AppIcon(AppIcons.fileText, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Carte d’étudiant', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                    Text(d.studentCardFile, style: AppText.small.copyWith(fontSize: 11)),
                  ],
                ),
              ),
              const AppIcon(AppIcons.circleCheck, size: 22, color: AppColors.success, semanticLabel: 'Fichier valide'),
            ],
          ),
        ),
        gap12,
        Semantics(
          button: true,
          label: _certificate ? 'Certificat de scolarité ajouté' : 'Téléverser le certificat de scolarité',
          child: GestureDetector(
            onTap: () => setState(() => _certificate = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _submitted && !_certificate ? AppColors.error : const Color(0xFFCFCBD6),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(color: Color(0xFFFBE8B7), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: AppIcon(_certificate ? AppIcons.check : AppIcons.upload, size: 16),
                  ),
                  gap8,
                  Text('Certificat de scolarité', style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w600)),
                  Text(
                    _certificate ? 'certificat_scolarite.pdf • 0,8 Mo' : 'Appuyez pour téléverser (PDF ou JPG, 5 Mo max)',
                    style: AppText.small.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
        gap12,
        const InfoNote('Vos documents sont chiffrés et ne sont consultés que par l’équipe de validation.'),
        gap16,
        Material(
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF8E6CF2), Color(0xFF6A4FE6)])),
            child: InkWell(
              onTap: () {
                setState(() => _submitted = true);
                if (_level != null && _certificate) context.openScreen('18');
              },
              child: SizedBox(
                height: AppSizes.buttonHeight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Envoyer pour validation', style: AppText.button),
                    const SizedBox(width: 10),
                    const AppIcon(AppIcons.arrowRight, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
