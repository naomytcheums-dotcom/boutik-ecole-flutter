import '../v_widgets.dart';

/// 175 · Bienvenue, étudiant.
class BienvenueEtudiantScreen extends ConsumerWidget {
  const BienvenueEtudiantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => VOnboardingPage(ref.watch(sectionVDataProvider).student);
}
