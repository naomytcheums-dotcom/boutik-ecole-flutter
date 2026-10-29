import '../../../data/demo/section_ref_demo.dart';
import '../../common/common.dart';
import '../ref_widgets.dart';

typedef _Tool = (String, String, String?, String?, int, bool);

/// P5 · Connecter mes outils : réseaux, portfolio, gestion et paiement reliés au profil.
class ConnecterOutilsScreen extends ConsumerStatefulWidget {
  const ConnecterOutilsScreen({super.key});

  @override
  ConsumerState<ConnecterOutilsScreen> createState() => _ConnecterOutilsScreenState();
}

class _ConnecterOutilsScreenState extends ConsumerState<ConnecterOutilsScreen> {
  late final Set<String> _connected = {
    for (final g in ref.read(sectionREFDataProvider).toolGroups)
      for (final t in g.$4)
        if (t.$6) t.$1,
  };
  int _filter = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionREFDataProvider);
    final q = _query.trim().toLowerCase();
    final groups = [
      for (final g in d.toolGroups)
        if (_filter == 0 || d.toolFilters[_filter] == g.$2)
          (
            g.$1,
            g.$3,
            g.$4,
            [
              for (final t in g.$4)
                if (q.isEmpty || t.$1.toLowerCase().contains(q)) t,
            ],
          ),
    ].where((g) => g.$4.isNotEmpty).toList();
    return AppScaffold(
      showNav: false,
      padding: const EdgeInsets.symmetric(horizontal: 23),
      header: RefHeader(
        title: 'Connecter mes outils',
        subtitle: 'Ton profil, tes outils, ton choix',
        titleSize: 17.5,
        trailing: RefGlassButton(icon: AppIcons.search, label: 'Rechercher', onTap: () => context.openScreen('V1')),
      ),
      bottomBarHeight: 54,
      bottomBar: RefPillButton(
        label: 'Enregistrer mes outils',
        height: 50,
        fontSize: 15,
        onTap: () => context.toast('${_connected.length} outils enregistrés sur ton profil'),
      ),
      children: [
        const SizedBox(height: 6),
        // Maquette : « 3 outils connectés » = réseaux sociaux reliés (voir docs/questions/REF.md, Q3).
        _Hero(count: d.toolGroups.first.$4.where((t) => _connected.contains(t.$1)).length),
        const SizedBox(height: 18),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white),
          ),
          child: Row(
            children: [
              const AppIcon(AppIcons.search, size: 18),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  key: const Key('ref-tool-search'),
                  onChanged: (v) => setState(() => _query = v),
                  style: AppText.body.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un outil ou un réseau',
                    hintStyle: AppText.body.copyWith(fontSize: 13, color: AppColors.textSecondary),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        RefPillRow(
          labels: d.toolFilters,
          selected: _filter,
          onSelected: (i) => setState(() => _filter = i),
          height: 34,
          padding: 18,
          fontSize: 13,
        ),
        const SizedBox(height: 16),
        if (groups.isEmpty)
          RefCard(
            radius: 30,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const AppIcon(AppIcons.search, size: 26, color: AppColors.textSecondary),
                const SizedBox(height: 10),
                Text('Aucun outil ne correspond à « $_query ».', style: AppText.body, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Ajoute-le comme lien personnalisé.', style: AppText.small, textAlign: TextAlign.center),
              ],
            ),
          ),
        for (final (title, more, all, tools) in groups) ...[
          RefCard(
            radius: 30,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title, style: AppText.h3.copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    Text(
                      '${all.where((t) => _connected.contains(t.$1)).length} / ${all.length}',
                      style: AppText.small.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < tools.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56, color: Color(0xFFF0EEEC)),
                  _ToolLine(
                    tool: tools[i],
                    connected: _connected.contains(tools[i].$1),
                    onConnect: () => setState(() => _connected.add(tools[i].$1)),
                  ),
                ],
                if (more > 0)
                  Semantics(
                    button: true,
                    child: InkWell(
                      onTap: () => context.toast('$more autres outils disponibles'),
                      child: SizedBox(
                        height: 46,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Voir $more outils de plus',
                                style: AppText.small.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const AppIcon(AppIcons.chevronRight, size: 16),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        RefDashedAddCard(
          title: 'Ajouter un autre lien',
          subtitle: 'Site web, portfolio, boutique, WhatsApp Business…',
          onTap: () => context.toast('Ajoute l’adresse de ton lien'),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            top: 0,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 150, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2366), Color(0xFF5A3FD2)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Relie tes outils,\nton profil se met\nà jour tout seul.',
                    style: AppText.h3.copyWith(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w500,
                      height: 1.32,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count outils connectés',
                      style: AppText.small.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: -4,
            top: 6,
            width: 136,
            height: 136,
            child: Image.asset('assets/images/ref_3d_kela_fleur.png', fit: BoxFit.contain, excludeFromSemantics: true),
          ),
        ],
      ),
    );
  }
}

class _ToolLine extends StatelessWidget {
  const _ToolLine({required this.tool, required this.connected, required this.onConnect});

  final _Tool tool;
  final bool connected;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final (name, detail, logo, mark, tint, _) = tool;
    final color = Color(tint);
    final Widget logoWidget = mark != null && mark.startsWith('assets/')
        ? Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFEDECEE), borderRadius: BorderRadius.circular(11)),
            alignment: Alignment.center,
            child: AppIcon(mark, size: 20, color: color),
          )
        : RefToolLogo(image: logo, initials: mark, tint: color, size: 44, radius: 11);
    return SizedBox(
      height: 59,
      child: Row(
        children: [
          logoWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(
                  connected && detail == 'Non connecté' ? 'Connecté à l’instant' : detail,
                  style: AppText.small.copyWith(fontSize: 11.5, color: connected ? AppColors.success : null),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (connected)
            Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppIcon(AppIcons.check, size: 13, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'Connecté',
                    style: AppText.small.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          else
            Semantics(
              button: true,
              label: 'Connecter $name',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onConnect,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
                  child: Text(
                    'Connecter',
                    style: AppText.small.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
