import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import 'auth.dart';
import 'backend.dart';

/// Connexion (11) et inscription (12) pour une personne déjà connectée : à l'ouverture de l'écran, elle est renvoyée à l'accueil de son rôle.
/// Le contrôle n'a lieu qu'à l'ouverture : une connexion réussie depuis cet écran garde sa propre navigation.
class SignedInRedirect extends ConsumerStatefulWidget {
  const SignedInRedirect({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SignedInRedirect> createState() => _SignedInRedirectState();
}

class _SignedInRedirectState extends ConsumerState<SignedInRedirect> {
  @override
  void initState() {
    super.initState();
    final a = ref.read(authProvider).current;
    if (!Backend.ready || a == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) GoRouter.of(context).go(screenPath(homeScreenFor(a)));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

const _ink = Color(0xFF111015);
const _grey = Color(0xFF57545F);
TextStyle _st(double size, {FontWeight w = FontWeight.w500, Color c = _ink}) =>
    TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: size, fontWeight: w, color: c, textBaseline: TextBaseline.alphabetic);

/// Porte de la vérification en 2 étapes au démarrage : une session restaurée dont le niveau d'assurance est aal1 alors que le compte a un
/// facteur TOTP vérifié n'ouvre rien tant que le code n'a pas été saisi. Trois codes faux, ou « Se déconnecter » : la session est fermée.
class SecondFactorGate extends StatefulWidget {
  const SecondFactorGate({super.key, required this.factorId, required this.onPassed, required this.onRefused});
  final String factorId;
  final VoidCallback onPassed, onRefused;

  @override
  State<SecondFactorGate> createState() => _SecondFactorGateState();
}

class _SecondFactorGateState extends State<SecondFactorGate> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;
  int _tries = 0;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final code = _code.text.replaceAll(' ', '');
    if (_busy) return;
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Saisissez les 6 chiffres du code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await Backend.verifyTotp(widget.factorId, code);
    if (!mounted) return;
    if (err == null) return widget.onPassed();
    _tries++;
    if (_tries >= 3) return _refuse();
    setState(() {
      _busy = false;
      _error = '$err (${3 - _tries} essai${3 - _tries > 1 ? 's' : ''} restant${3 - _tries > 1 ? 's' : ''}).';
      _code.clear();
    });
  }

  Future<void> _refuse() async {
    setState(() => _busy = true);
    await Backend.signOut();
    Backend.signingOut = false;
    await saveRemembered(null);
    if (mounted) widget.onRefused();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Boutik-École',
    home: Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Icon(Icons.lock_outline_rounded, size: 52, color: _ink),
                const SizedBox(height: 14),
                Text('Vérification en 2 étapes', textAlign: TextAlign.center, style: _st(22, w: FontWeight.w700)),
                const SizedBox(height: 10),
                Text('Saisissez le code à 6 chiffres affiché par votre application d’authentification pour ouvrir votre compte.', textAlign: TextAlign.center, style: _st(13.5, w: FontWeight.w400, c: const Color(0xFF4A4854)).copyWith(height: 1.55)),
                const SizedBox(height: 22),
                TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: _st(22, w: FontWeight.w700),
                  onSubmitted: (_) => _check(),
                  decoration: InputDecoration(counterText: '', filled: true, fillColor: Colors.white, hintText: '••••••', border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, textAlign: TextAlign.center, style: _st(12.5, c: const Color(0xFFC0392B)))),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: _check,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _ink, borderRadius: BorderRadius.circular(28)),
                    child: Text(_busy ? 'Vérification…' : 'Vérifier', style: _st(14.5, w: FontWeight.w600, c: Colors.white)),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _busy ? null : _refuse,
                  child: Padding(padding: const EdgeInsets.all(12), child: Text('Se déconnecter', textAlign: TextAlign.center, style: _st(13, w: FontWeight.w600, c: _grey))),
                ),
              ]),
            ),
          ),
        ),
      ),
    ),
  );
}
