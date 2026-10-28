import '../v_widgets.dart';

/// 177 · Bienvenue, entreprise.
class BienvenueEntrepriseScreen extends ConsumerWidget {
  const BienvenueEntrepriseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => VOnboardingPage(ref.watch(sectionVDataProvider).company);
}
