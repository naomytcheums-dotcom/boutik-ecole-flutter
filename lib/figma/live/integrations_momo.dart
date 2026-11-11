import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import 'auth.dart';
import 'integrations_data.dart';
import 'integrations_model.dart';
import 'integrations_widgets.dart';
import 'lots.dart' show copyText;
import 'store.dart' show fcfa;

/// Mobile Money (MTN MoMo, Orange Money) : numéros, vérification, envoi avec confirmation explicite, historique, reçu.
/// Jamais de code PIN : l'opérateur demande la validation sur le téléphone. Les envois restent désactivés tant que le contrat marchand n'est pas actif.

void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Color _txColor(String s) => switch (s) { 'confirmed' => kOk, 'failed' => kBad, 'pending' => kWarn, _ => kMuted };

class MomoHubScreen extends ConsumerWidget {
  const MomoHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(integrationsProvider);
    final d = st.dashboard;
    final recent = st.transactions.take(3).toList();
    final anyReady = st.momoReady.mtn;
    return IntPage(
      title: 'Mobile Money',
      subtitle: 'MTN MoMo et Orange Money',
      bottom: Row(children: [
        Expanded(child: IntButton('Ajouter un numéro', filled: false, onTap: () => addNumberDialog(context, ref))),
        const SizedBox(width: 10),
        Expanded(child: IntButton('Envoyer', onTap: () => _push(context, const MomoSendScreen()))),
      ]),
      children: [
        if (!anyReady)
          const IntCard(
            child: _Info(
              'Envois pas encore activés',
              'Vous pouvez enregistrer et vérifier vos numéros. L’envoi d’argent s’active dès que le contrat marchand de l’opérateur est en place (MTN : clés Disbursement ; Orange : contrat marchand). Aucun débit n’est possible d’ici là.',
            ),
          ),
        IntCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ce mois-ci', style: intText(12, color: kMuted, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Stat('Envoyé', fcfa(d.sentMonth))),
              Expanded(child: _Stat('Reçu', fcfa(d.receivedMonth))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Stat('Opérations réussies', '${d.countMonth}')),
              Expanded(child: _Stat('En cours', '${d.pending}')),
              Expanded(child: _Stat('Échecs', '${d.failedMonth}')),
            ]),
          ]),
        ),
        const IntSectionTitle('Mes numéros', hint: 'Le compte principal est utilisé par défaut'),
        if (st.numbers.isEmpty)
          IntCard(child: Text('Aucun numéro enregistré. Ajoutez votre numéro MTN ou Orange, puis vérifiez-le par SMS.', style: intText(12.5, color: kMuted, height: 1.45))),
        for (final n in st.numbers) _NumberCard(n),
        IntSectionTitle('Dernières opérations', hint: st.transactions.isEmpty ? null : 'Touchez une opération pour voir le détail et le reçu'),
        if (recent.isEmpty) IntCard(child: Text('Aucune opération pour le moment.', style: intText(12.5, color: kMuted))),
        for (final t in recent) _TxCard(t),
        if (st.transactions.isNotEmpty) Center(child: TextButton(onPressed: () => _push(context, const MomoHistoryScreen()), child: Text('Voir tout l’historique', style: intText(13, weight: FontWeight.w700, color: kAccent)))),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.title, this.body);
  final String title, body;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: intText(13.5, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(body, style: intText(12.5, color: kMuted, height: 1.45)),
      ]);
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: intText(16, weight: FontWeight.w800)),
        Text(label, style: intText(11, color: kMuted)),
      ]);
}

class _NumberCard extends ConsumerWidget {
  const _NumberCard(this.n);
  final MomoNumber n;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IntCard(
        semantics: '${n.title}, ${maskPhone(n.phone)}, ${momoVerifLabel(n.verif)}',
        onTap: () => numberSheet(context, n),
        child: Row(children: [
          IntLogo(n.operator == 'MTN' ? 'mtn_momo' : 'orange_money'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title, style: intText(14, weight: FontWeight.w700)),
              Text(maskPhone(n.phone), style: intText(12, color: kMuted)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                if (n.primary) const IntPill('Principal', color: kAccent),
                IntPill(momoVerifLabel(n.verif), color: n.verified ? kOk : kWarn),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: kMuted),
        ]),
      );
}

class _TxCard extends StatelessWidget {
  const _TxCard(this.t);
  final MomoTx t;

  @override
  Widget build(BuildContext context) => IntCard(
        semantics: '${t.outgoing ? 'Envoi' : 'Réception'} ${t.amount} francs, ${t.statusLabel}',
        onTap: () => _push(context, MomoDetailScreen(reference: t.reference)),
        child: Row(children: [
          Icon(t.outgoing ? Icons.north_east_rounded : Icons.south_west_rounded, color: kInk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${t.outgoing ? 'Envoi à' : 'Reçu de'} ${maskPhone(t.phone)}', style: intText(13, weight: FontWeight.w600)),
              Text(_date(t.createdAt), style: intText(11.5, color: kMuted)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${t.outgoing ? '−' : '+'} ${fcfa(t.amount)}', style: intText(13.5, weight: FontWeight.w800)),
            IntPill(t.statusLabel, color: _txColor(t.status)),
          ]),
        ]),
      );
}

// ---------------------------------------------------------------- numéros

Future<void> addNumberDialog(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'ajouter un numéro Mobile Money') || !context.mounted) return;
  final phone = TextEditingController();
  final label = TextEditingController();
  var op = 'MTN';
  final ok = await gDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Ajouter un numéro', style: intText(17, weight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'MTN', label: Text('MTN MoMo')), ButtonSegment(value: 'ORANGE', label: Text('Orange Money'))],
              selected: {op},
              onSelectionChanged: (s) => set(() => op = s.first),
            ),
            const SizedBox(height: 14),
            IntField(controller: phone, label: 'Numéro (6XX XX XX XX)', keyboard: TextInputType.phone),
            IntField(controller: label, label: 'Nom du compte (ex. Boutique, Perso)', maxLength: 40),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: intText(13, weight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Ajouter', style: intText(13, weight: FontWeight.w700, color: kAccent))),
        ],
      ),
    ),
  );
  final p = phone.text;
  final l = label.text;
  phone.dispose();
  label.dispose();
  if (ok != true || !context.mounted) return;
  final norm = normalizePhone(p);
  if (norm == null) return gAlert(context, 'Numéro invalide', 'Saisissez un numéro camerounais : 6XX XX XX XX.');
  final err = await ref.read(integrationsProvider.notifier).addNumber(op, norm, l);
  if (!context.mounted) return;
  err == null ? gToast(context, 'Numéro ajouté : vérifiez-le par SMS.') : gAlert(context, 'Numéro non ajouté', err);
}

Future<void> numberSheet(BuildContext context, MomoNumber n) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFFAF8F5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _NumberSheet(id: n.id),
    );

class _NumberSheet extends ConsumerStatefulWidget {
  const _NumberSheet({required this.id});
  final String id;

  @override
  ConsumerState<_NumberSheet> createState() => _NumberSheetState();
}

class _NumberSheetState extends ConsumerState<_NumberSheet> {
  bool _busy = false;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _do(Future<String?> Function() job, {String? ok, bool close = false}) async {
    setState(() => _busy = true);
    final err = await job();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) return gAlert(context, 'Mobile Money', err);
    if (ok != null) gToast(context, ok);
    if (close) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(integrationsProvider);
    MomoNumber? n;
    for (final x in st.numbers) {
      if (x.id == widget.id) n = x;
    }
    if (n == null) return const SizedBox(height: 120);
    final nb = n;
    final notifier = ref.read(integrationsProvider.notifier);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            IntLogo(nb.operator == 'MTN' ? 'mtn_momo' : 'orange_money', size: 52),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(nb.title, style: intText(19, weight: FontWeight.w800)), Text(formatPhone(nb.phone), style: intText(13, color: kMuted))])),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [if (nb.primary) const IntPill('Principal', color: kAccent), IntPill(momoVerifLabel(nb.verif), color: nb.verified ? kOk : kWarn)]),
          const SizedBox(height: 16),
          if (!nb.verified) ...[
            Text('Pour envoyer de l’argent, prouvez que ce numéro est le vôtre : un code à 6 chiffres vous est envoyé par SMS (valable 10 minutes).', style: intText(12.5, color: kMuted, height: 1.45)),
            const SizedBox(height: 10),
            IntButton('Envoyer le code par SMS', filled: false, busy: _busy, onTap: () => _do(() => notifier.requestVerification(nb.id), ok: 'Code envoyé par SMS.')),
            const SizedBox(height: 10),
            IntField(controller: _code, label: 'Code reçu (6 chiffres)', keyboard: TextInputType.number, maxLength: 6),
            IntButton('Vérifier le code', busy: _busy, onTap: () async {
              final code = _code.text.trim();
              if (!RegExp(r'^\d{6}$').hasMatch(code)) return gAlert(context, 'Code invalide', 'Saisissez les 6 chiffres reçus par SMS.');
              setState(() => _busy = true);
              final (ok, err) = await notifier.confirmVerification(nb.id, code);
              if (!mounted) return;
              setState(() => _busy = false);
              if (err != null) return gAlert(context, 'Vérification', err);
              ok ? gToast(context, 'Numéro vérifié.') : gAlert(context, 'Code incorrect', 'Le code ne correspond pas. Réessayez.');
            }),
            const SizedBox(height: 16),
          ],
          if (!nb.primary && nb.verified) ...[IntButton('Définir comme compte principal', filled: false, busy: _busy, onTap: () => _do(() => notifier.setPrimary(nb.id), ok: 'Compte principal mis à jour.')), const SizedBox(height: 10)],
          IntButton('Renommer', filled: false, busy: _busy, onTap: () async {
            final c = TextEditingController(text: nb.label);
            final ok = await gDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                title: Text('Nom du compte', style: intText(17, weight: FontWeight.w700)),
                content: IntField(controller: c, label: 'Nom personnalisé', maxLength: 40),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: intText(13, weight: FontWeight.w700))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Enregistrer', style: intText(13, weight: FontWeight.w700, color: kAccent))),
                ],
              ),
            );
            final v = c.text;
            c.dispose();
            if (ok == true && mounted) await _do(() => notifier.renameNumber(nb.id, v), ok: 'Nom enregistré.');
          }),
          const SizedBox(height: 10),
          IntButton('Supprimer ce numéro', danger: true, filled: false, busy: _busy, onTap: () async {
            final ok = await gDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: Colors.white,
                title: Text('Supprimer ce numéro ?', style: intText(17, weight: FontWeight.w700)),
                content: Text('L’historique des opérations est conservé. Le numéro ne pourra plus servir à envoyer de l’argent.', style: intText(13.5, color: kMuted, height: 1.45)),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler', style: intText(13, weight: FontWeight.w700))),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Supprimer', style: intText(13, weight: FontWeight.w700, color: kBad))),
                ],
              ),
            );
            if (ok == true && mounted) await _do(() => notifier.removeNumber(nb.id), ok: 'Numéro supprimé.', close: true);
          }),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- envoi

class MomoSendScreen extends ConsumerStatefulWidget {
  const MomoSendScreen({super.key});

  @override
  ConsumerState<MomoSendScreen> createState() => _SendState();
}

class _SendState extends ConsumerState<MomoSendScreen> {
  final _to = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _from;
  bool _busy = false;
  // La clé d'unicité d'un envoi est créée une seule fois par saisie : rejouer « Continuer » ne peut jamais créer un second envoi.
  String _key = '';
  String _keyFor = '';

  @override
  void dispose() {
    _to.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(integrationsProvider);
    final verified = [for (final n in st.numbers) if (n.verified) n];
    MomoNumber? from;
    for (final n in verified) {
      if (n.id == _from) from = n;
    }
    from ??= verified.isEmpty ? null : verified.firstWhere((n) => n.primary, orElse: () => verified.first);
    final ready = from == null ? false : (from.operator == 'MTN' ? st.momoReady.mtn : st.momoReady.orange);
    return IntPage(
      title: 'Envoyer de l’argent',
      subtitle: 'Vous confirmerez avant tout débit',
      bottom: IntButton('Continuer', busy: _busy, onTap: () => _continue(from)),
      children: [
        if (verified.isEmpty)
          const IntCard(child: _Info('Aucun numéro vérifié', 'Ajoutez un numéro puis vérifiez-le par SMS dans « Mobile Money » pour pouvoir envoyer de l’argent.'))
        else ...[
          if (!ready)
            IntCard(child: _Info('Envoi pas encore activé pour ${from!.operatorName}', 'Vous pouvez préparer l’envoi, mais l’opérateur ne l’exécutera qu’une fois le contrat marchand actif. Rien ne sera débité.')),
          const IntSectionTitle('Depuis'),
          for (final n in verified)
            IntCard(
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () => setState(() => _from = n.id),
              semantics: '${n.title}, ${maskPhone(n.phone)}',
              child: Row(children: [
                IntLogo(n.operator == 'MTN' ? 'mtn_momo' : 'orange_money', size: 36),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n.title, style: intText(13.5, weight: FontWeight.w700)), Text(maskPhone(n.phone), style: intText(12, color: kMuted))])),
                Icon(n.id == from.id ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: n.id == from.id ? kAccent : kMuted),
              ]),
            ),
          const SizedBox(height: 8),
          IntField(controller: _to, label: 'Numéro du destinataire (6XX XX XX XX)', keyboard: TextInputType.phone),
          IntField(controller: _amount, label: 'Montant (FCFA)', keyboard: TextInputType.number),
          IntField(controller: _note, label: 'Note (facultatif)', maxLength: 120),
        ],
      ],
    );
  }

  Future<void> _continue(MomoNumber? from) async {
    final err = validateTransfer(to: _to.text, amount: _amount.text, from: from);
    if (err != null) return gAlert(context, 'Envoi', err);
    final to = normalizePhone(_to.text)!;
    final amount = int.parse(_amount.text.replaceAll(RegExp(r'[\s.]'), ''));
    final sig = '${from!.id}|$to|$amount|${_note.text.trim()}';
    if (_keyFor != sig) {
      _keyFor = sig;
      _key = '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${UniqueKey().hashCode.toRadixString(36)}';
    }
    setState(() => _busy = true);
    final r = await ref.read(integrationsProvider.notifier).prepareTransfer(numberId: from.id, to: to, amount: amount, note: _note.text.trim(), idempotencyKey: _key);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.error != null) return gAlert(context, 'Envoi', r.error!);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MomoConfirmScreen(reference: r.reference!)));
  }
}

/// Récapitulatif : rien n'est envoyé tant que la case n'est pas cochée et que « Confirmer l'envoi » n'est pas touché.
class MomoConfirmScreen extends ConsumerStatefulWidget {
  const MomoConfirmScreen({super.key, required this.reference});
  final String reference;

  @override
  ConsumerState<MomoConfirmScreen> createState() => _ConfirmState();
}

class _ConfirmState extends ConsumerState<MomoConfirmScreen> {
  bool _checked = false, _busy = false;

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(integrationsProvider);
    MomoTx? t;
    for (final x in st.transactions) {
      if (x.reference == widget.reference) t = x;
    }
    if (t == null) return IntPage(title: 'Confirmer l’envoi', children: const [IntCard(child: _Info('Transaction introuvable', 'Revenez en arrière et recommencez.'))]);
    final tx = t;
    MomoNumber? from;
    for (final n in st.numbers) {
      if (tx.operator == n.operator && n.verified) from ??= n;
    }
    final waiting = tx.status == 'awaiting_confirmation';
    return IntPage(
      title: 'Confirmer l’envoi',
      subtitle: waiting ? 'Vérifiez chaque ligne avant de confirmer' : tx.statusLabel,
      bottom: waiting
          ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              IntButton('Confirmer l’envoi de ${fcfa(tx.amount)}', busy: _busy, onTap: _checked ? () => _confirm(tx) : null),
              const SizedBox(height: 8),
              IntButton('Annuler', filled: false, danger: true, onTap: _busy ? null : () => _cancel(tx)),
            ])
          : IntButton('Voir le détail', onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => MomoDetailScreen(reference: tx.reference)))),
      children: [
        IntCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Row('Montant', fcfa(tx.amount)),
            _Row('Destinataire', formatPhone(tx.phone)),
            _Row('Depuis', from == null ? tx.operator : '${from.title} · ${maskPhone(from.phone)}'),
            if (tx.note != null && tx.note!.isNotEmpty) _Row('Note', tx.note!),
            _Row('Référence', tx.reference),
          ]),
        ),
        const IntCard(
          child: _Info('Votre code PIN reste privé', 'Boutik-École ne demande, ne reçoit et ne conserve jamais votre code PIN. Après confirmation, l’opérateur vous demande de valider l’opération sur votre téléphone.'),
        ),
        if (waiting)
          Semantics(
            container: true,
            child: CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked,
              onChanged: (v) => setState(() => _checked = v == true),
              title: Text('Je confirme l’envoi de ${fcfa(tx.amount)} au ${formatPhone(tx.phone)}.', style: intText(13, weight: FontWeight.w600, height: 1.4)),
            ),
          ),
      ],
    );
  }

  Future<void> _confirm(MomoTx tx) async {
    setState(() => _busy = true);
    final (status, message) = await ref.read(integrationsProvider.notifier).confirmTransfer(tx.reference);
    if (!mounted) return;
    setState(() => _busy = false);
    if (status == 'error' || status == 'failed') {
      return gAlert(context, status == 'failed' ? 'Envoi refusé' : 'Envoi impossible', message.isEmpty ? 'Aucun débit n’a eu lieu.' : message);
    }
    gToast(context, message.isEmpty ? 'Envoi demandé.' : message);
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => MomoDetailScreen(reference: tx.reference)));
  }

  Future<void> _cancel(MomoTx tx) async {
    final err = await ref.read(integrationsProvider.notifier).cancelTransfer(tx.reference);
    if (!mounted) return;
    if (err != null) return gAlert(context, 'Annulation', err);
    gToast(context, 'Envoi annulé : rien n’a été débité.');
    Navigator.of(context).pop();
  }
}

class _Row extends StatelessWidget {
  const _Row(this.k, this.v);
  final String k, v;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(k, style: intText(12.5, color: kMuted))),
          Expanded(child: Text(v, style: intText(13.5, weight: FontWeight.w700))),
        ]),
      );
}

// ---------------------------------------------------------------- historique, détail, reçu

class MomoHistoryScreen extends ConsumerStatefulWidget {
  const MomoHistoryScreen({super.key});

  @override
  ConsumerState<MomoHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<MomoHistoryScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(integrationsProvider);
    final list = [for (final t in st.transactions) if (_status == null || t.status == _status) t];
    Widget chip(String label, String? v) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(label: Text(label), selected: _status == v, onSelected: (_) => setState(() => _status = v)),
        );
    return IntPage(
      title: 'Historique',
      subtitle: 'Toutes vos opérations Mobile Money',
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(height: 52, child: Row(children: [chip('Toutes', null), chip('Réussies', 'confirmed'), chip('En cours', 'pending'), chip('Échouées', 'failed'), chip('Annulées', 'cancelled')])),
        ),
        const SizedBox(height: 10),
        if (list.isEmpty) IntCard(child: Text('Aucune opération dans cette catégorie.', style: intText(12.5, color: kMuted))),
        for (final t in list) _TxCard(t),
      ],
    );
  }
}

class MomoDetailScreen extends ConsumerStatefulWidget {
  const MomoDetailScreen({super.key, required this.reference});
  final String reference;

  @override
  ConsumerState<MomoDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<MomoDetailScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(integrationsProvider);
    MomoTx? t;
    for (final x in st.transactions) {
      if (x.reference == widget.reference) t = x;
    }
    if (t == null) return IntPage(title: 'Détail', children: const [IntCard(child: _Info('Opération introuvable', 'Elle n’est plus dans votre historique.'))]);
    final tx = t;
    return IntPage(
      title: tx.done ? 'Reçu' : 'Détail de l’opération',
      subtitle: tx.reference,
      bottom: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (tx.status == 'pending')
          IntButton('Actualiser l’état', filled: false, busy: _busy, onTap: () async {
            setState(() => _busy = true);
            await ref.read(integrationsProvider.notifier).refreshTransfer(tx.reference);
            if (mounted) setState(() => _busy = false);
          }),
        if (tx.status == 'pending') const SizedBox(height: 8),
        IntButton(tx.done ? 'Copier le reçu' : 'Copier le détail', onTap: () async {
          final ok = await copyText(receiptText(tx));
          if (context.mounted) gToast(context, ok ? 'Copié dans le presse-papiers' : 'Copie impossible');
        }),
      ]),
      children: [
        IntCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [IntLogo(tx.operator == 'MTN' ? 'mtn_momo' : 'orange_money', size: 40), const SizedBox(width: 12), IntPill(tx.statusLabel, color: _txColor(tx.status))]),
            const SizedBox(height: 12),
            Text('${tx.outgoing ? '−' : '+'} ${fcfa(tx.amount)}', style: intText(26, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            _Row(tx.outgoing ? 'Destinataire' : 'Expéditeur', formatPhone(tx.phone)),
            _Row('Opérateur', tx.operator == 'MTN' ? 'MTN MoMo' : 'Orange Money'),
            _Row('Créée le', _date(tx.createdAt)),
            if (tx.confirmedByUserAt != null) _Row('Confirmée par vous', _date(tx.confirmedByUserAt!)),
            if (tx.decidedAt != null) _Row('Résultat le', _date(tx.decidedAt!)),
            if (tx.fee != null) _Row('Frais', fcfa(tx.fee!)),
            if (tx.note != null && tx.note!.isNotEmpty) _Row('Note', tx.note!),
            if (tx.failure != null && tx.status == 'failed') _Row('Motif', tx.failure!),
          ]),
        ),
        if (tx.status == 'pending') const IntCard(child: _Info('Validation en attente', 'Si l’opérateur vous l’a demandé, validez l’opération sur votre téléphone. L’état se met à jour automatiquement à la réception du rappel de l’opérateur.')),
      ],
    );
  }
}
