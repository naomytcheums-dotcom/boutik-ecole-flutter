import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart' show gToast;
import 'auth.dart';
import 'backend.dart';
import 'seller.dart';
import 'tp_ui.dart';

/// Nouveau service (écran 59) : formulaire vide, sans valeur d'exemple. Un tarif laissé vide signifie « Sur devis » : le prix final est
/// alors fixé avec le client par devis. Brouillon enregistrable ; « Publier » envoie le service à la validation du département.
class ServiceFormPage extends ConsumerStatefulWidget {
  const ServiceFormPage({super.key});
  @override
  ConsumerState<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends ConsumerState<ServiceFormPage> {
  final title = TextEditingController(), category = TextEditingController(), price = TextEditingController(), delay = TextEditingController(), desc = TextEditingController();
  String mode = '';
  bool busy = false;

  static const modes = {'distance': 'À distance', 'campus': 'Sur campus', 'both': 'À distance ou sur campus'};

  @override
  void dispose() {
    for (final c in [title, category, price, delay, desc]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save({required bool submit}) async {
    final t = title.text.trim();
    if (t.length < 3) return gToast(context, 'Donnez un titre à votre service (3 caractères minimum).');
    final raw = price.text.replaceAll(RegExp(r'[^0-9]'), '');
    final p = raw.isEmpty ? 0 : int.parse(raw);
    if (raw.isNotEmpty && p < 500) return gToast(context, 'Tarif : 500 FCFA minimum, ou laissez vide pour « Sur devis ».');
    if (submit && desc.text.trim().length < 20) return gToast(context, 'Pour publier, décrivez votre service (20 caractères minimum).');
    if (!await requireLogin(context, ref, 'publier un service') || !mounted) return;
    setState(() => busy = true);
    final lines = [
      desc.text.trim(),
      if (delay.text.trim().isNotEmpty) 'Délai moyen : ${delay.text.trim()}',
      if (mode.isNotEmpty) 'Prestation : ${modes[mode]}',
      if (category.text.trim().isNotEmpty) 'Domaine : ${category.text.trim()}',
    ].where((x) => x.isNotEmpty).join('\n');
    final r = await Backend.createListing(Listing(title: t, category: 'Services', price: p, stock: 999, description: lines), submit: submit);
    if (!mounted) return;
    setState(() => busy = false);
    if (r.error != null) return gToast(context, r.error!);
    gToast(context, submit ? 'Service envoyé : il sera visible après validation du département.' : 'Brouillon enregistré.');
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return TpPage(
      title: 'Nouveau service',
      bottom: Row(children: [
        Expanded(child: TpButton('Brouillon', busy ? null : () => _save(submit: false), dark: false)),
        const SizedBox(width: 10),
        Expanded(child: TpButton('Publier', busy ? null : () => _save(submit: true), busy: busy)),
      ]),
      children: [
        TpField('Titre du service', title, required: true, maxLength: 80),
        TpField('Catégorie ou domaine', category, maxLength: 60),
        TpField('Tarif à partir de (FCFA)', price, keyboard: TextInputType.number, maxLength: 10, formatters: [FilteringTextInputFormatter.digitsOnly]),
        tpNote('Laissez vide si le prix dépend du besoin : le service s’affichera « Sur devis » et vous répondrez à chaque demande avec un montant et un délai.'),
        const SizedBox(height: 8),
        TpField('Délai moyen', delay, maxLength: 60),
        TpChoice('Mode de prestation', modes, mode, (v) => setState(() => mode = v)),
        TpField('Description du service (livrables, méthode)', desc, lines: 5, maxLength: 2000),
      ],
    );
  }
}
