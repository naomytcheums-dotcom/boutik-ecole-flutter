import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'messages.dart' show contactSeller;
import 'share.dart';
import 'store.dart';

const _st = TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, color: Color(0xFF111015));

/// Action enregistrée sur le serveur (inscription, candidature, vote, alerte, suivi, demande…).
/// Demande la connexion au moment où l'action l'exige ; un doublon est annoncé clairement, jamais ignoré en silence.
Future<bool> engageAction(BuildContext context, WidgetRef ref, String kind, String refKey,
    {Map<String, dynamic> data = const {}, required String success, String need = 'cette action', String already = 'C’est déjà enregistré pour votre compte.'}) async {
  if (!await requireLogin(context, ref, need)) return false;
  if (!Backend.ready) {
    if (context.mounted) await gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    return false;
  }
  final err = await Backend.engage(kind, refKey, data);
  if (!context.mounted) return false;
  if (err != null) {
    if (err.contains('Déjà enregistré')) {
      gToast(context, already);
    } else {
      await gAlert(context, 'Action impossible', err);
    }
    return false;
  }
  gToast(context, success);
  return true;
}

/// État enregistré d'un engagement, clé « type|cible » ; null hors connexion ou s'il n'existe pas. Recalculé à la connexion/déconnexion.
final engagementProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, key) async {
  ref.watch(authProvider);
  final i = key.indexOf('|');
  return Backend.myEngagement(key.substring(0, i), key.substring(i + 1));
});

/// Vrai si l'engagement « type|cible » est actif pour la personne connectée (sert à afficher l'état sur le bouton).
bool isEngaged(WidgetRef ref, String key) => ref.watch(engagementProvider(key)).value?['status'] == 'active';

String engagementDate(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

Future<bool?> _confirm(BuildContext context, String title, String body, String keep, String go) => gDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(title, style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(body, style: _st),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(keep)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(go)),
        ],
      ),
    );

/// Action réversible (inscription, candidature, suivi, précommande, alerte) : l'enregistre, ou, si elle est déjà active,
/// rappelle son état (date) et propose de l'annuler. Le serveur reste seul juge (doublon refusé, annulation contrôlée).
Future<void> engageOrManage(BuildContext context, WidgetRef ref, String kind, String refKey,
    {Map<String, dynamic> data = const {},
    required String success,
    String need = 'cette action',
    required String activeTitle,
    required String activeBody,
    required String cancelLabel,
    String keepLabel = 'Garder',
    required String cancelled,
    VoidCallback? onCreated}) async {
  if (!await requireLogin(context, ref, need)) return;
  if (!Backend.ready) {
    if (context.mounted) await gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    return;
  }
  final cur = await Backend.myEngagement(kind, refKey);
  if (!context.mounted) return;
  if (cur != null && cur['status'] == 'active') {
    final since = engagementDate(cur['created_at']);
    final go = await _confirm(context, activeTitle, since.isEmpty ? activeBody : '$activeBody\nEnregistré le $since.', keepLabel, cancelLabel);
    if (go == true) {
      final err = await Backend.cancelEngagement(kind, refKey);
      if (context.mounted) err == null ? gToast(context, cancelled) : await gAlert(context, 'Action impossible', err);
    }
  } else {
    final ok = await engageAction(context, ref, kind, refKey, data: data, success: success, need: need);
    if (ok && onCreated != null && context.mounted) onCreated();
  }
  ref.invalidate(engagementProvider('$kind|$refKey'));
}

/// Écran 76 : retire la candidature active la plus récente de la personne connectée (après confirmation).
Future<void> withdrawLatestApplication(BuildContext context, WidgetRef ref) async {
  if (!await requireLogin(context, ref, 'gérer vos candidatures')) return;
  if (!Backend.ready) {
    if (context.mounted) await gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
    return;
  }
  final apps = (await Backend.myEngagements(kind: 'application')).where((e) => e['status'] == 'active').toList();
  if (!context.mounted) return;
  if (apps.isEmpty) {
    await gAlert(context, 'Aucune candidature en cours', 'Vous n’avez pas de candidature active à retirer.');
    return;
  }
  final a = apps.first;
  final go = await _confirm(context, 'Retirer ma candidature ?', 'Candidature envoyée le ${engagementDate(a['created_at'])}. L’entreprise ne la verra plus ; vous pourrez postuler de nouveau.', 'Annuler', 'Retirer');
  if (go != true) return;
  final err = await Backend.cancelEngagement('application', '${a['ref']}');
  if (!context.mounted) return;
  err == null ? gToast(context, 'Candidature retirée.') : await gAlert(context, 'Action impossible', err);
  ref.invalidate(engagementProvider('application|${a['ref']}'));
}

/// Préférences enregistrées (alertes 156, canaux 236) : valeurs affichées par défaut celles de la maquette,
/// remplacées par celles du compte dès qu'elles sont lues sur le serveur.
class Prefs extends Notifier<Map<String, bool>> {
  Prefs(this.kind, this.defaults);
  final String kind;
  final Map<String, bool> defaults;
  bool _loaded = false;

  @override
  Map<String, bool> build() {
    ref.watch(authProvider);
    _loaded = false;
    _load();
    return Map.of(defaults);
  }

  Future<void> _load() async {
    final rows = await Backend.myEngagements(kind: kind);
    if (rows.isEmpty || _loaded) return;
    final d = rows.first['data'];
    if (d is Map) state = {for (final k in defaults.keys) k: d[k] is bool ? d[k] as bool : defaults[k]!};
  }

  void set(String key, bool on) {
    _loaded = true;
    state = {...state, key: on};
  }
}

const alertPrefsDefaults = {'app': true, 'sms': true, 'whatsapp': false, 'email': true, 'dossier': true, 'offres': true, 'echeances': true, 'resultats': true};
const channelPrefsDefaults = {'whatsapp': true, 'sms': true, 'app': true, 'email': false};
final alertPrefsProvider = NotifierProvider<Prefs, Map<String, bool>>(() => Prefs('alert_prefs', alertPrefsDefaults));
final channelPrefsProvider = NotifierProvider<Prefs, Map<String, bool>>(() => Prefs('channel_prefs', channelPrefsDefaults));

/// Enregistre les préférences affichées (une seule ligne par compte, mise à jour à chaque enregistrement).
Future<void> savePrefs(BuildContext context, WidgetRef ref, NotifierProvider<Prefs, Map<String, bool>> p, {Map<String, dynamic> extra = const {}}) async {
  final kind = ref.read(p.notifier).kind;
  final ok = await engageAction(context, ref, kind, 'me', data: {...ref.read(p), ...extra}, success: 'Préférences enregistrées.', need: 'enregistrer vos préférences');
  if (ok) ref.invalidate(engagementProvider('$kind|me'));
}

/// Écran 72 : ajoute une réalisation au portfolio du compte (titre, catégorie, date, description saisis).
Future<void> addPortfolioItem(BuildContext context, WidgetRef ref) async {
  final f = ref.read(formProvider.notifier);
  String v(String k, String d) => f.get(k).trim().isEmpty ? d : f.get(k).trim();
  final title = v('pf_title', 'Application mobile Boutik');
  final ok = await engageAction(context, ref, 'portfolio_item', 'item:${title.toLowerCase()}',
      data: {'title': title, 'category': v('pf_cat', 'Développement'), 'date': v('pf_date', 'Octobre 2026'), 'description': f.get('pf_desc').trim()},
      success: 'Réalisation ajoutée à votre portfolio.', need: 'compléter votre portfolio', already: 'Cette réalisation figure déjà dans votre portfolio.');
  if (ok && context.mounted) gBack(context);
}

/// Écran 39 : la question est envoyée au vendeur du produit consulté, dans la messagerie (conversation réelle).
Future<void> sendProductQuestion(BuildContext context, WidgetRef ref) async {
  final q = ref.read(formProvider.notifier).get('question').trim();
  if (q.length < 5) {
    await gAlert(context, 'Question trop courte', 'Écrivez votre question au vendeur (5 caractères minimum).');
    return;
  }
  final phone = ref.read(formProvider.notifier).get('question_phone').trim();
  await contactSeller(ref, context, viewedProductTitle(ref), message: phone.isEmpty ? q : '$q\n(Téléphone : $phone)');
}

/// Action qui dépend d'un service externe non encore activé : on l'explique, on ne la simule pas.
Future<void> unavailableAction(BuildContext context, String title, String why) => gAlert(context, title, why);

/// Conditions d'utilisation : l'acceptation est mémorisée pour l'inscription et, si un compte est connecté, enregistrée côté serveur.
Future<void> acceptTerms(BuildContext context, WidgetRef ref) async {
  ref.read(termsProvider.notifier).set(true);
  if (Backend.ready && Backend.currentUserId != null) {
    await Backend.engage('terms_accepted', 'cgu-2026-10', {'accepted_at': DateTime.now().toUtc().toIso8601String()});
  }
  if (context.mounted) gBack(context);
}

/// Écran 273 : demande de suppression du compte, après confirmation explicite (traitée par l'équipe, sans effacement immédiat).
Future<void> requestAccountDeletion(BuildContext context, WidgetRef ref) async {
  final ok = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Supprimer mon compte ?', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text('Votre demande est transmise à l’équipe, qui supprime votre compte et vos données personnelles. Vos commandes en cours doivent être terminées au préalable.', style: _st),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer la demande')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await engageAction(context, ref, 'account_deletion_request', 'me', success: 'Demande de suppression envoyée. L’équipe vous répondra par e-mail.', need: 'demander la suppression du compte', already: 'Une demande de suppression est déjà en cours.');
}

/// Écran 241 : invitation partagée par WhatsApp (lien réel wa.me), avec le code de parrainage de la personne.
Future<void> shareViaWhatsApp(BuildContext context, WidgetRef ref) {
  final a = ref.read(profileAccountProvider);
  final code = a.name.trim().isEmpty ? 'iut' : a.name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  final msg = 'Salut ! Rejoins Boutik-École, la marketplace des talents de l’IUT de Douala : https://boutik-ecole.vercel.app/#/s/03 (code $code)';
  return openUrl(context, 'https://wa.me/?text=${Uri.encodeComponent(msg)}');
}

/// Produit actuellement consulté, pour les alertes de disponibilité.
String viewedProductTitle(WidgetRef ref) => ref.read(selectedProductProvider).title;
