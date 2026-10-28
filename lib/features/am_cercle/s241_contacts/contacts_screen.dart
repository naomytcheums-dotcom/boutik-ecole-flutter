import '../am_widgets.dart';

/// 241 · Mes contacts : inviter des contacts WhatsApp / téléphone.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  bool _allowed = true;
  int _filter = 0;
  Set<String>? _selected;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(sectionAMDataProvider);
    final selected = _selected ??= {
      for (final c in d.contacts)
        if (c.state == 1) c.name,
    };
    final contacts = [
      for (final c in d.contacts)
        if (c.name.toLowerCase().contains(_query.toLowerCase())) c,
    ];
    return AppScaffold(
      showNav: false,
      header: ScreenHeader(
        title: 'Mes contacts',
        subtitle: 'WhatsApp et répertoire du téléphone',
        actions: [AmHeaderButton(AppIcons.search, label: 'Rechercher', onTap: () {})],
      ),
      bottomBarHeight: 96,
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: 'Envoyer via WhatsApp (${selected.length})',
            onPressed: selected.isEmpty || !_allowed
                ? null
                : () => context.toast('Invitation envoyée à ${selected.length} contacts'),
          ),
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.openScreen('240'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text('Ou copier le lien et le partager moi-même', style: AppText.small.copyWith(fontSize: 11)),
              ),
            ),
          ),
        ],
      ),
      children: [
        AmCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFEDE7FB), shape: BoxShape.circle),
                child: const AppIcon(AppIcons.lock, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Autoriser l’accès aux contacts', style: AppText.bodyStrong),
                    const SizedBox(height: 2),
                    Text(
                      'Rien n’est enregistré sans ton accord. Tu peux le retirer à tout moment.',
                      style: AppText.small.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Toggle(
                value: _allowed,
                label: 'Autoriser l’accès aux contacts',
                onChanged: (v) => setState(() => _allowed = v),
              ),
            ],
          ),
        ),
        gap12,
        SearchField(hint: 'Rechercher un contact', showFilter: false, onChanged: (v) => setState(() => _query = v)),
        gap8,
        Row(
          children: [
            for (var i = 0; i < d.contactFilters.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Pill(d.contactFilters[i], dense: true, selected: i == _filter, onTap: () => setState(() => _filter = i)),
            ],
          ],
        ),
        gap8,
        if (!_allowed)
          const InfoNote(
            'Active l’accès aux contacts pour inviter tes amis, ou copie ton lien pour le partager toi-même.',
            title: 'Accès aux contacts désactivé',
          )
        else if (contacts.isEmpty)
          const InfoNote('Aucun contact ne correspond à ta recherche.', icon: AppIcons.search)
        else
          AmCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: Column(
              children: [
                for (var i = 0; i < contacts.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.cardBorder),
                  _ContactRow(
                    contact: contacts[i],
                    selected: selected.contains(contacts[i].name),
                    onTap: contacts[i].state == 2
                        ? null
                        : () => setState(() {
                            final n = contacts[i].name;
                            selected.contains(n) ? selected.remove(n) : selected.add(n);
                          }),
                  ),
                ],
              ],
            ),
          ),
        gap12,
        AmCard(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Message envoyé', style: AppText.small.copyWith(fontSize: 11)),
              gap8,
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(color: const Color(0xFFE4F3D8), borderRadius: BorderRadius.circular(16)),
                child: Text(d.inviteMessage, style: AppText.small.copyWith(color: AppColors.ink, fontSize: 11.5)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.contact, required this.selected, this.onTap});

  final AmContact contact;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final registered = contact.state == 2;
    return Semantics(
      button: onTap != null,
      checked: registered ? null : selected,
      label: contact.name,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 57,
          child: Row(
            children: [
              Avatar(image: contact.avatar, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.name, style: AppText.bodyStrong),
                    Text(
                      contact.detail,
                      style: AppText.small.copyWith(fontSize: 11, color: registered ? AppColors.success : null),
                    ),
                  ],
                ),
              ),
              if (registered)
                const AmChip('Inscrite', tone: Tone.success, height: 26, fontSize: 11)
              else if (selected)
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
                  child: const AppIcon(AppIcons.check, size: 14, color: Colors.white),
                )
              else
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: Color(0xFFEDE9FA), shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
