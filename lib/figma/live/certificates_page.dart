import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gAlert, gToast;
import 'auth.dart' show authProvider;
import 'backend.dart';
import 'lots.dart' show copyText, verifyCertificateDialog;
import 'share.dart';
import 'tp_ui.dart';

/// Mes certificats : une page (et non une fenêtre) qui explique ce qu'est un certificat, liste ceux du compte et permet de vérifier un code.
class CertificatesPage extends ConsumerStatefulWidget {
  const CertificatesPage({super.key});
  @override
  ConsumerState<CertificatesPage> createState() => _CertificatesPageState();
}

class _CertificatesPageState extends ConsumerState<CertificatesPage> {
  List<Map<String, dynamic>>? _rows;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = Backend.currentUserId;
    final r = await Backend.rows('certificates', 'code,subject_title,issued_at,revoked,holder_id', order: 'issued_at', limit: 100);
    if (!mounted) return;
    setState(() {
      _error = r.error != null;
      _rows = [for (final x in r.rows) if (x['holder_id'] == me) x];
    });
  }

  String _date(Object? iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final signed = ref.watch(authProvider.select((a) => a.current != null));
    return TpPage(
      title: 'Mes certificats',
      children: [
        TpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Qu’est-ce qu’un certificat ?', style: tpSt(14.5, w: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('C’est un document officiel émis par le département de l’IUT de Douala pour attester une réalisation : un projet validé, une formation, une distinction. '
                'Il porte un code unique, de la forme BE-CERT-0000. Toute personne (recruteur, entreprise, école) peut saisir ce code dans « Vérifier un certificat » '
                'pour constater qu’il est authentique et qu’il n’a pas été révoqué.', style: tpSt(13, c: tpGrey, h: 1.5)),
          ]),
        ),
        const SizedBox(height: 4),
        TpButton('Vérifier un certificat', () => verifyCertificateDialog(context, ref), dark: false, icon: Icons.verified_outlined),
        tpSection('Mes certificats', hint: 'Les certificats qui vous ont été délivrés.'),
        if (!signed)
          const TpEmpty(title: 'Connexion requise', text: 'Connectez-vous pour voir vos certificats.', icon: Icons.lock_outline)
        else if (_rows == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_error)
          const TpEmpty(title: 'Lecture impossible', text: 'Vos certificats ne peuvent pas être chargés pour le moment.', icon: Icons.cloud_off_rounded)
        else if (_rows!.isEmpty)
          const TpEmpty(title: 'Aucun certificat pour le moment', text: 'Quand le département vous délivrera un certificat, il apparaîtra ici avec son code.', icon: Icons.workspace_premium_outlined)
        else
          for (final c in _rows!)
            TpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c['subject_title']}', style: tpSt(14.5, w: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Délivré le ${_date(c['issued_at'])}${c['revoked'] == true ? ' · révoqué' : ''}', style: tpSt(12, c: c['revoked'] == true ? tpRed : tpGrey)),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF2EFF6), borderRadius: BorderRadius.circular(12)), child: SelectableText('${c['code']}', style: tpSt(14, w: FontWeight.w800, c: tpViolet))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TpButton('Copier le code', () async {
                    final ok = await copyText('${c['code']}');
                    if (context.mounted) gToast(context, ok ? 'Code copié' : '${c['code']}');
                  }, dark: false, compact: true)),
                  const SizedBox(width: 8),
                  Expanded(child: TpButton('Partager', () => shareText(context, 'Certificat Boutik-École ${c['code']} — vérifiable sur $siteUrl'), compact: true)),
                ]),
              ]),
            ),
      ],
    );
  }
}

