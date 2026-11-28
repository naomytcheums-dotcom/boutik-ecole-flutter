import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;

/// État d'une lecture serveur affichée dans une liste : jamais « vide » tant que la lecture n'a pas réussi.
enum LoadStatus { loading, ok, failed }

/// Message d'échec de lecture avec bouton « Réessayer » (zone tactile 48 px).
class RetryNote extends StatelessWidget {
  const RetryNote({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13, height: 1.5, fontWeight: FontWeight.w500, color: Color(0xFF57545F))),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: 'Réessayer',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRetry,
                child: const SizedBox(
                  height: 48,
                  child: Center(child: Text('Réessayer', style: TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF5A3FE0), decoration: TextDecoration.underline))),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// Texte d'attente centré (« Chargement… »).
class LoadingNote extends StatelessWidget {
  const LoadingNote(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Text(message, textAlign: TextAlign.center, style: const TextStyle(inherit: false, fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF57545F))));
}
