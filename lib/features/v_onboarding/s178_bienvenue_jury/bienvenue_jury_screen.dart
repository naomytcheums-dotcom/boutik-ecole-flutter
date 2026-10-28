import '../v_widgets.dart';

/// 178 · Bienvenue, jury.
class BienvenueJuryScreen extends ConsumerWidget {
  const BienvenueJuryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => VOnboardingPage(ref.watch(sectionVDataProvider).jury);
}
