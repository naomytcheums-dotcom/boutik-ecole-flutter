import '../../common/common.dart';
import '../d_widgets.dart';

/// 36 · Détail du service « Développement web sur mesure » (formules et modalités).
class DetailServiceScreen extends ConsumerStatefulWidget {
  const DetailServiceScreen({super.key});

  @override
  ConsumerState<DetailServiceScreen> createState() => _DetailServiceScreenState();
}

class _DetailServiceScreenState extends ConsumerState<DetailServiceScreen> {
  int? _formula;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionDDataProvider);
    return DScaffold(
      title: 'Détail du service',
      headerActions: [
        DHeaderAction(
          AppIcons.share,
          label: 'Partager le service',
          onTap: () => context.toast('Lien du service copié.'),
        ),
      ],
      actions: [
        DButton('Demander un devis', kind: DButtonKind.outline, onPressed: () => context.openScreen('40')),
        DButton(
          'Commander',
          onPressed: () {
            final f = d.serviceFormulas[_formula ?? 0];
            ref
                .read(cartProvider.notifier)
                .add(CartLine('${d.serviceTitle} · ${f.$1}', d.serviceProvider, f.$3, d.serviceCover));
            context.toast('Formule ${f.$1} ajoutée au panier.');
          },
        ),
      ],
      children: [
        const SizedBox(height: 2),
        _ServiceHero(
          image: d.serviceCover,
          title: d.serviceTitle,
          subtitle: 'Par ${d.serviceProvider} · ${d.serviceDepartment}',
        ),
        const SizedBox(height: 14),
        DCard(
          child: SizedBox(
            height: 76,
            child: Row(
              children: [
                for (final (i, s) in d.serviceStats.indexed) ...[
                  if (i > 0) Container(width: 1, height: 44, color: DColors.divider),
                  Expanded(
                    child: Semantics(
                      label: '${s.$2} : ${s.$1}',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(s.$1, style: AppText.h2.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(s.$2, style: DTxt.meta.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        const DSectionTitle('Formules'),
        const SizedBox(height: 17),
        DCard(
          padding: const EdgeInsets.only(bottom: 2),
          child: Column(
            children: [
              for (final (i, f) in d.serviceFormulas.indexed) ...[
                if (i > 0) const DDivider(),
                _FormulaRow(
                  icon: f.$4,
                  name: f.$1,
                  meta: f.$2,
                  price: f.$3,
                  selected: _formula == i,
                  onTap: () => setState(() => _formula = _formula == i ? null : i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        DKvCard(title: 'Modalités de prestation', rows: d.serviceTerms),
      ],
    );
  }
}

class _ServiceHero extends StatelessWidget {
  const _ServiceHero({required this.image, required this.title, required this.subtitle});

  final String image;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DPhoto(image, alignment: Alignment.topCenter),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00000000), Color(0x66000000)],
                stops: [.3, 1],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppText.h3.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: DTxt.meta.copyWith(
                    color: const Color(0xE6FFFFFF),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormulaRow extends StatelessWidget {
  const _FormulaRow({
    required this.icon,
    required this.name,
    required this.meta,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String name;
  final String meta;
  final int price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Formule $name, $meta, ${fcfa(price)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 65,
          color: selected ? const Color(0xFFF8F6FD) : null,
          padding: const EdgeInsets.only(left: 12, right: 16),
          child: Row(
            children: [
              DTile(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: DTxt.item),
                    const SizedBox(height: 3),
                    Text(meta, style: DTxt.meta),
                  ],
                ),
              ),
              Text(fcfa(price), style: DTxt.item.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
