import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../gen.dart' show gToast;
import '../i18n.dart' show Text;
import 'auth.dart';
import 'backend.dart';
import 'marche/marche_data.dart';
import 'marche/marche_widgets.dart';

/// Portail web de l'équipe (administrateur, direction, responsable de département, finance, support).
/// Les tableaux de bord de l'équipe se consultent ici, au format web, et non depuis l'espace mobile des clients, étudiants-vendeurs et entreprises.
/// Le lien contient une clé longue et aléatoire : il ne figure sur aucune page publique. La clé seule n'est pas une protection (elle limite la découverte) :
/// l'accès exige un compte de l'équipe (e-mail et mot de passe), et tout compte qui n'est pas de l'équipe est refusé et déconnecté aussitôt.

const staffPortalKey = 'NgoV0_kWqkm3u8cL38pOScrycILe';

String staffPortalPath() => '/equipe/$staffPortalKey';

/// Écran d'arrivée de chaque rôle de l'équipe après connexion (tableau de bord au format web).
String? staffConsoleFor(String staff) => switch (staff) {
      'Admin global' => '127',
      'Resp. département' => '108',
      'Direction' => '117',
      'Finance' => '139',
      'Support' => '145',
      _ => null,
    };

class StaffPortalScreen extends ConsumerStatefulWidget {
  const StaffPortalScreen({super.key, required this.portalKey});
  final String portalKey;

  @override
  ConsumerState<StaffPortalScreen> createState() => _PortalState();
}

class _PortalState extends ConsumerState<StaffPortalScreen> {
  final _mail = TextEditingController(), _pw = TextEditingController();
  bool _busy = false, _hide = true;
  String? _error;

  @override
  void dispose() {
    _mail.dispose();
    _pw.dispose();
    super.dispose();
  }

  void _go(String staff) {
    final id = staffConsoleFor(staff);
    if (id != null && mounted) context.go('/s/$id');
  }

  Future<void> _login() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await Backend.login(_mail.text.trim(), _pw.text);
    if (!mounted) return;
    final a = r.account;
    if (a == null) {
      setState(() {
        _busy = false;
        _error = r.error ?? 'Identifiant ou mot de passe incorrect.';
      });
      return;
    }
    if (staffConsoleFor(a.staff) == null) {
      // compte de l'espace mobile (client, étudiant-vendeur, entreprise) : refusé ici et déconnecté
      await Backend.signOut();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Ce portail est réservé à l’équipe de l’IUT. Utilisez l’application pour votre compte.';
      });
      return;
    }
    ref.read(authProvider.notifier).login(a);
    gToast(context, 'Bienvenue, ${a.firstName} !');
    setState(() => _busy = false);
    _go(a.staff);
  }

  @override
  Widget build(BuildContext context) {
    // Clé incorrecte : aucune indication qu'un portail existe.
    if (widget.portalKey != staffPortalKey) return const Scaffold(body: SizedBox.shrink());
    final current = ref.watch(authProvider.select((a) => a.current));
    final already = current != null && staffConsoleFor(current.staff) != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F4FA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kLine)),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Espace équipe', style: mst(24, w: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Boutik-École · IUT de Douala', style: mst(13, c: kGrey)),
                const SizedBox(height: 20),
                if (already) ...[
                  Text('Vous êtes connecté en tant que ${current.name} (${current.roleLabel}).', style: mst(13.5)),
                  const SizedBox(height: 14),
                  mButton('Ouvrir mon tableau de bord', () => _go(current.staff)),
                ] else ...[
                  TextField(controller: _mail, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username], decoration: const InputDecoration(labelText: 'Adresse e-mail', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pw,
                    obscureText: _hide,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _login(),
                    decoration: InputDecoration(labelText: 'Mot de passe', border: const OutlineInputBorder(), suffixIcon: IconButton(tooltip: _hide ? 'Afficher' : 'Masquer', icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hide = !_hide))),
                  ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: mst(12.5, w: FontWeight.w600, c: kRed))),
                  const SizedBox(height: 16),
                  mButton('Se connecter', _login, busy: _busy, width: double.infinity),
                ],
                const SizedBox(height: 16),
                Text('Accès réservé aux comptes de l’équipe : administrateur, direction, responsable de département, finance et support.', style: mst(11.5, c: kGrey).copyWith(height: 1.4)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
