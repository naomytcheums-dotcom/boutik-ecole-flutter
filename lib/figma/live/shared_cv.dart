import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/paths.dart';
import 'backend.dart';

const _f = 'PlusJakartaSans';
TextStyle _t(double s, FontWeight w, Color c) => TextStyle(inherit: false, fontFamily: _f, fontSize: s, fontWeight: w, color: c, height: 1.45, textBaseline: TextBaseline.alphabetic);

/// CV partagé par un lien (écran 228 → « Régénérer le lien ») : lecture publique, sans compte, des seules informations que la personne expose.
/// Un lien régénéré ou révoqué n'affiche plus rien.
class SharedCvScreen extends StatelessWidget {
  const SharedCvScreen({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EFE6),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FutureBuilder<({Object? data, String? error})>(
              future: RegExp(r'^[0-9a-f]{32}$').hasMatch(token) ? Backend.rpc('shared_cv', {'p_token': token}) : Future.value((data: null, error: null)),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final d = snap.data!.data is Map ? Map<String, dynamic>.from(snap.data!.data as Map) : null;
                return ListView(padding: const EdgeInsets.all(28), children: [
                  Text('Boutik-École · CV', style: _t(13, FontWeight.w600, const Color(0xFF5A3FE0))),
                  const SizedBox(height: 10),
                  if (d == null) ...[
                    Text('Lien de CV invalide', style: _t(22, FontWeight.w700, const Color(0xFF111015))),
                    const SizedBox(height: 8),
                    Text(snap.data!.error ?? 'Ce lien a été remplacé ou n’existe pas. Demandez un nouveau lien à son auteur.', style: _t(14, FontWeight.w400, const Color(0xFF4A4854))),
                  ] else ...[
                    Text('${d['nom']}', style: _t(26, FontWeight.w800, const Color(0xFF111015))),
                    Text([d['departement'], d['etablissement']].where((x) => x != null && '$x'.isNotEmpty).join(' · '), style: _t(14, FontWeight.w500, const Color(0xFF66636E))),
                    if (d['certifie'] == true) Text('✓ Profil certifié par l’établissement', style: _t(13, FontWeight.w600, const Color(0xFF0F7A52))),
                    const SizedBox(height: 18),
                    if ('${d['bio'] ?? ''}'.isNotEmpty) Text('${d['bio']}', style: _t(14.5, FontWeight.w400, const Color(0xFF111015))),
                    if ('${d['competences'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('Compétences', style: _t(13, FontWeight.w700, const Color(0xFF111015))),
                      Text('${d['competences']}', style: _t(14, FontWeight.w400, const Color(0xFF4A4854))),
                    ],
                    for (final l in (d['liens'] as List? ?? const []))
                      if (l is Map) Text('${l['label'] ?? 'Lien'} : ${l['url']}', style: _t(13, FontWeight.w500, const Color(0xFF5A3FE0))),
                  ],
                  const SizedBox(height: 26),
                  TextButton(onPressed: () => context.go(screenPath('03')), child: Text('Découvrir Boutik-École', style: _t(14, FontWeight.w600, const Color(0xFF111015)))),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
