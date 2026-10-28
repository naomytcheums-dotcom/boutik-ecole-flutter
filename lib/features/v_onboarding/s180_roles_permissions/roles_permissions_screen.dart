import '../../n_admin_globale/n_widgets.dart' show NAdminShell, OpsSplit;
import '../v_widgets.dart';

/// 180 · Rôles et permissions (web, administration globale).
class RolesPermissionsScreen extends ConsumerStatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  ConsumerState<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends ConsumerState<RolesPermissionsScreen> {
  int _role = 0;

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionVDataProvider);
    final role = d.roles[_role].$2;
    final rules = d.roleRules[role]!;
    return NAdminShell(
      title: 'Rôles et permissions',
      selected: 1,
      children: [
        OpsSplit(
          left: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OpsCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < d.roles.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
                      _RoleRow(role: d.roles[i], selected: i == _role, onTap: () => setState(() => _role = i)),
                    ],
                  ],
                ),
              ),
              gap16,
              SizedBox(
                width: 170,
                child: OpsBigButton(
                  label: 'Créer un rôle',
                  icon: AppIcons.plus,
                  onTap: () => context.toast('Nouveau rôle : définissez ses permissions dans la matrice.'),
                ),
              ),
            ],
          ),
          right: OpsKvCard(
            title: 'Règles du rôle $role',
            rows: [
              ('Rôle sélectionné', role),
              ('Création', rules.$1),
              ('Validation', rules.$2),
              ('Expiration', rules.$3),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role, required this.selected, required this.onTap});

  final (String, String, String, int) role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              OpsIconTile(role.$1, size: 32, iconSize: 18, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.$2, style: AppText.web(AppText.bodyStrong.copyWith(fontSize: 13))),
                    const SizedBox(height: 2),
                    Text(role.$3, style: AppText.web(AppText.small.copyWith(fontSize: 11))),
                  ],
                ),
              ),
              OpsBadge('${role.$4} comptes', tone: OpsTone.info),
            ],
          ),
        ),
      ),
    );
  }
}
