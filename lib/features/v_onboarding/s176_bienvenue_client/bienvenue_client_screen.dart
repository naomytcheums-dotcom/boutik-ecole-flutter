import '../v_widgets.dart';

/// 176 · Bienvenue (client).
class BienvenueClientScreen extends ConsumerWidget {
  const BienvenueClientScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => VOnboardingPage(ref.watch(sectionVDataProvider).buyer);
}
