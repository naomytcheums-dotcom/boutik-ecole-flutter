import 'package:flutter/material.dart' hide Text;
import '../i18n.dart' show Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'notif_client.dart';
import 'backend.dart';
import 'messages.dart' show conversationsProvider, selectedConversationProvider;
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

/// Préférences enregistrées (alertes 156, canaux 236). Les canaux (e-mail, SMS, WhatsApp, application) sont relus sur le serveur
/// (table des consentements) : un canal jamais activé s'affiche désactivé, aucun consentement n'est présumé.
class Prefs extends Notifier<Map<String, bool>> {
  Prefs(this.kind, this.defaults);
  final String kind;
  final Map<String, bool> defaults;
  bool _loaded = false;

  /// Canaux modifiés par la personne depuis l'ouverture de l'écran : seuls ceux-là sont envoyés au serveur à l'enregistrement.
  final Set<String> touched = {};

  static const _channels = {'email': 'email', 'sms': 'sms', 'whatsapp': 'whatsapp', 'app': 'push'};

  @override
  Map<String, bool> build() {
    ref.watch(authProvider);
    _loaded = false;
    touched.clear();
    _load();
    return Map.of(defaults);
  }

  Future<void> _load() async {
    final rows = await Backend.myEngagements(kind: kind);
    final srv = await Backend.rows('notification_preferences', 'channel,enabled', eq: const {'kind': '*'}, limit: 10);
    // « Offres » et « Résultats » sont les seuls types lus par les notifications : ils viennent du serveur, pas de l'engagement.
    final types = kind == 'alert_prefs' ? await Backend.rpc('alert_prefs_get', const {}) : null;
    if (_loaded || !ref.mounted) return;
    final d = rows.isNotEmpty && rows.first['data'] is Map ? rows.first['data'] as Map : const {};
    final channels = srv.error == null ? {for (final r in srv.rows) '${r['channel']}': r['enabled'] == true} : const <String, bool>{};
    final serverTypes = types != null && types.error == null && types.data is Map ? types.data as Map : const {};
    bool typeValue(String k) {
      final s = serverTypes[const {'offres': 'offers', 'resultats': 'results', 'dossier': 'documents'}[k]];
      return s is bool ? s : (d[k] is bool ? d[k] as bool : defaults[k]!);
    }

    final next = {
      for (final k in defaults.keys)
        // Le serveur envoie l'application (push) par défaut : sans ligne enregistrée, ce canal s'affiche donc activé.
        k: _channels.containsKey(k)
            ? (srv.error == null ? (channels[_channels[k]] ?? (k == 'app')) : defaults[k]!)
            : (k == 'offres' || k == 'resultats' || k == 'dossier') && kind == 'alert_prefs' ? typeValue(k) : (d[k] is bool ? d[k] as bool : defaults[k]!),
    };
    if (next.entries.any((e) => state[e.key] != e.value)) state = next;
  }

  void set(String key, bool on) {
    _loaded = true;
    touched.add(key);
    state = {...state, key: on};
  }
}

const alertPrefsDefaults = {'app': false, 'sms': false, 'whatsapp': false, 'email': false, 'dossier': true, 'offres': true, 'echeances': true, 'resultats': true};
const channelPrefsDefaults = {'whatsapp': false, 'sms': false, 'app': false, 'email': false};
final alertPrefsProvider = NotifierProvider<Prefs, Map<String, bool>>(() => Prefs('alert_prefs', alertPrefsDefaults));
final channelPrefsProvider = NotifierProvider<Prefs, Map<String, bool>>(() => Prefs('channel_prefs', channelPrefsDefaults));

/// Enregistre les préférences affichées (une seule ligne par compte, mise à jour à chaque enregistrement).
/// Les canaux touchés sont enregistrés d'abord sur le serveur : un refus (numéro absent, adresse invalide) est annoncé.
Future<void> savePrefs(BuildContext context, WidgetRef ref, NotifierProvider<Prefs, Map<String, bool>> p, {Map<String, dynamic> extra = const {}}) async {
  final kind = ref.read(p.notifier).kind;
  if (kind == 'channel_prefs' || kind == 'alert_prefs') {
    if (!await requireLogin(context, ref, 'enregistrer vos préférences') || !context.mounted) return;
    final err = await syncChannelPrefs(ref.read(p), only: ref.read(p.notifier).touched);
    if (!context.mounted) return;
    if (err != null) return gAlert(context, 'Préférences non enregistrées', err);
    ref.invalidate(notifSettingsProvider);
  }
  if (kind == 'alert_prefs' && Backend.ready) {
    final v = ref.read(p);
    final r = await Backend.rpc('alert_prefs_set', {'p_offers': v['offres'] ?? true, 'p_results': v['resultats'] ?? true, 'p_documents': v['dossier'] ?? true});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Préférences non enregistrées', Backend.userMessage(r.error!));
    if (v['offres'] ?? true) {
      final g = await Backend.rpc('alert_prefs_get', const {});
      if (!context.mounted) return;
      if (g.error == null && g.data is Map && (g.data as Map)['needs_department'] == true) {
        await gAlert(context, 'Filière manquante', 'Les alertes d’offres reposent sur la filière de votre profil. Renseignez votre filière pour les recevoir.');
        if (!context.mounted) return;
      }
    }
  }
  final ok = await engageAction(context, ref, kind, 'me', data: {...ref.read(p), ...extra}, success: 'Préférences enregistrées.', need: 'enregistrer vos préférences');
  if (ok) {
    ref.read(p.notifier).touched.clear();
    ref.invalidate(engagementProvider('$kind|me'));
  }
}

/// Écran 236 : enregistre le numéro WhatsApp saisi (validé et normalisé par le serveur) puis les canaux choisis ; aucun consentement par défaut.
Future<void> saveChannelPrefs(BuildContext context, WidgetRef ref, String typedNumber) async {
  if (!await requireLogin(context, ref, 'enregistrer vos canaux') || !context.mounted) return;
  if (!Backend.ready) return gAlert(context, 'Hors connexion', 'Cette action nécessite la connexion au serveur.');
  final n = ref.read(channelPrefsProvider.notifier);
  final prefs = ref.read(channelPrefsProvider);
  final stored = ref.read(notifSettingsProvider).value?.whatsappNumber ?? '';
  final number = typedNumber.trim();
  if (prefs['whatsapp'] == true && n.touched.contains('whatsapp') && number.isEmpty && stored.isEmpty) {
    return gAlert(context, 'Numéro WhatsApp manquant', 'Saisissez votre numéro WhatsApp avant d’activer ce canal.');
  }
  if (number != stored) {
    final r = await Backend.rpc('set_whatsapp_number', {'p_number': number});
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Numéro WhatsApp non enregistré', Backend.userMessage(r.error!));
    // Sans numéro de téléphone au profil, celui-ci sert aussi aux SMS ; un numéro déjà enregistré ne se remplace pas (le serveur le refuse).
    if (number.isNotEmpty && (ref.read(authProvider).current?.phone ?? '').trim().isEmpty) {
      final p = await Backend.rpc('profile_set_phone', {'p_phone': number});
      final acc = ref.read(authProvider).current;
      if (p.error == null && acc != null) ref.read(authProvider.notifier).update(acc.copyWith(phone: number));
      if (!context.mounted) return;
    }
  }
  final err = await syncChannelPrefs(prefs, only: n.touched);
  if (!context.mounted) return;
  ref.invalidate(notifSettingsProvider);
  if (err != null) return gAlert(context, 'Canal non activé', err);
  n.touched.clear();
  gToast(context, 'Préférences enregistrées.');
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

/// Thèmes proposés sous le titre de l'écran 39 ; le thème choisi ouvre le message envoyé au vendeur.
const questionTopics = ['Disponibilité', 'Délai', 'Personnalisation', 'Livraison'];
final questionTopicProvider = NotifierProvider<IntV, int>(IntV.new);

/// Incrémenté après un envoi : les champs de l'écran 39 repartent vides.
final questionResetProvider = NotifierProvider<IntV, int>(IntV.new);

/// Envois récents (titre du produit, heure) : au plus 3 questions par produit et 8 au total par heure depuis cet appareil.
class QuestionLog extends Notifier<List<({String title, DateTime at})>> {
  @override
  List<({String title, DateTime at})> build() => const [];

  List<({String title, DateTime at})> recent() {
    final from = DateTime.now().subtract(const Duration(hours: 1));
    return [for (final e in state) if (e.at.isAfter(from)) e];
  }

  void add(String title) => state = [...recent(), (title: title, at: DateTime.now())];
}

final questionLogProvider = NotifierProvider<QuestionLog, List<({String title, DateTime at})>>(QuestionLog.new);

/// Écran 39 : la question est envoyée au vendeur du produit consulté, dans la messagerie (conversation réelle).
Future<void> sendProductQuestion(BuildContext context, WidgetRef ref) async {
  if (Backend.ready && !ref.read(selectedProductProvider.notifier).chosen) {
    return gAlert(context, 'Aucun produit choisi', 'Ouvrez la fiche d’un produit puis touchez « Contacter » pour poser une question à son vendeur.');
  }
  final q = ref.read(formProvider.notifier).get('question').trim();
  if (q.length < 5) {
    await gAlert(context, 'Question trop courte', 'Écrivez votre question au vendeur (5 caractères minimum).');
    return;
  }
  final phone = ref.read(formProvider.notifier).get('question_phone').trim();
  if (phone.isNotEmpty && !RegExp(r'^\+?[0-9 .-]{8,18}$').hasMatch(phone)) {
    await gAlert(context, 'Téléphone invalide', 'Saisissez un numéro valide (8 à 15 chiffres, par exemple +237 6 12 34 56 78) ou laissez ce champ vide.');
    return;
  }
  final title = viewedProductTitle(ref);
  final recent = ref.read(questionLogProvider.notifier).recent();
  if (recent.where((e) => e.title == title).length >= 3 || recent.length >= 8) {
    await gAlert(context, 'Trop de messages', 'Vous avez déjà posé plusieurs questions. Attendez la réponse du vendeur dans la messagerie ou réessayez dans une heure.');
    return;
  }
  final topic = questionTopics[ref.read(questionTopicProvider).clamp(0, questionTopics.length - 1)];
  final body = 'À propos de « $title » ($topic) : $q${phone.isEmpty ? '' : '\n(Téléphone : $phone)'}';
  if (!Backend.ready) return gToast(context, 'La messagerie nécessite la connexion au serveur.');
  if (!await requireLogin(context, ref, 'écrire au vendeur') || !context.mounted) return;
  final info = await Backend.listingContact(title);
  if (!context.mounted) return;
  if (info == null) return gAlert(context, 'Annonce introuvable', 'Ce produit n’est plus disponible à la vente.');
  if (!info.hasSeller) return gAlert(context, 'Produit de la plateforme', 'Ce produit est vendu directement par Boutik-École : il n’a pas de vendeur étudiant à qui écrire.');
  final r = await Backend.startConversation(info.listingId, body);
  if (r.error != null) {
    if (context.mounted) await gAlert(context, 'Message non envoyé', r.error!);
    return;
  }
  ref.read(questionLogProvider.notifier).add(title);
  ref.read(formProvider.notifier).clear(const ['question', 'question_phone']);
  ref.read(questionResetProvider.notifier).set(ref.read(questionResetProvider) + 1);
  ref.read(selectedConversationProvider.notifier).set(r.id!);
  await ref.read(conversationsProvider.notifier).refresh();
  if (context.mounted) gOpen(context, '53');
}

/// Action qui dépend d'un service externe non encore activé : on l'explique, on ne la simule pas.
Future<void> unavailableAction(BuildContext context, String title, String why) => gAlert(context, title, why);

/// Conditions d'utilisation : l'acceptation est mémorisée pour l'inscription et, si un compte est connecté, enregistrée côté serveur.
/// L'écran n'est quitté qu'après la confirmation du serveur : sans elle, la personne est prévenue et peut réessayer.
/// [confirmed] : faux tant que les cases à cocher de l'écran (274) ne sont pas toutes cochées.
Future<void> acceptTerms(BuildContext context, WidgetRef ref, {bool confirmed = true}) async {
  if (!confirmed) {
    gToast(context, 'Cochez les deux cases pour accepter les conditions.');
    return;
  }
  if (Backend.ready && Backend.currentUserId != null) {
    final err = await Backend.acceptTerms(kTermsVersion) ?? await Backend.acceptTerms(kSalesTermsVersion);
    if (err != null) {
      if (context.mounted) await gAlert(context, 'Acceptation non enregistrée', err);
      return;
    }
  }
  ref.read(termsProvider.notifier).set(true);
  if (!context.mounted) return;
  gToast(context, 'Conditions acceptées.');
  gBack(context);
}

/// Demande de suppression en cours (état, date de dépôt et date d'effet), lue sur le serveur ; null si aucune.
final myDeletionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  if (!Backend.ready || Backend.currentUserId == null) return null;
  final r = await Backend.rpc('my_account_deletion', const {});
  if (r.error != null) throw StateError('my_account_deletion');
  return r.data is Map ? Map<String, dynamic>.from(r.data as Map) : null;
}, retry: (_, _) => null);

String _fr(Object? iso) => deletionDate(iso);

/// Date « JJ/MM/AAAA » d'un horodatage serveur (heure locale).
String deletionDate(Object? iso) {
  final d = DateTime.tryParse('$iso')?.toLocal();
  return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Écran 273 : demande de suppression du compte. Délai de rétractation de 30 jours pendant lequel la demande s'annule depuis le même écran ;
/// l'administration est prévenue par le serveur. Une demande déjà en cours se transforme en bouton « Annuler la demande ».
Future<void> requestAccountDeletion(BuildContext context, WidgetRef ref) async {
  if (!Backend.ready) {
    await _demoDeletion(context, ref);
    return;
  }
  if (!await requireLogin(context, ref, 'demander la suppression du compte') || !context.mounted) return;
  final current = await ref.read(myDeletionProvider.future).catchError((_) => null);
  if (!context.mounted) return;
  if (current != null) {
    final cancel = await gDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Annuler la demande de suppression ?', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('Votre compte est programmé pour être supprimé à partir du ${_fr(current['scheduled_for'])}.${current['blocked'] == true ? ' Cette suppression est suspendue tant que : ${current['blocked_reason']}.' : ''} En annulant, il reste ouvert et rien n’est supprimé.', style: _st),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Garder la demande')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Annuler la demande')),
        ],
      ),
    );
    if (cancel != true || !context.mounted) return;
    final r = await Backend.rpc('cancel_account_deletion', const {});
    if (!context.mounted) return;
    if (r.error != null || r.data != 'cancelled') {
      await gAlert(context, 'Annulation non confirmée', r.error ?? 'Le serveur n’a pas confirmé l’annulation. Réessayez.');
      return;
    }
    ref.invalidate(myDeletionProvider);
    gToast(context, 'Demande annulée : votre compte reste ouvert.');
    return;
  }
  final ok = await gDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Supprimer mon compte ?', style: _st.copyWith(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Text('Votre demande est transmise à l’administration. Après un délai de rétractation de 30 jours (vous pouvez annuler depuis cet écran), votre compte est désactivé et vos données personnelles sont anonymisées : nom, e-mail, téléphone, adresses, pièces et profil sont effacés. Les commandes, paiements, factures et certificats émis sont conservés (obligation légale), sans votre identité. La demande est refusée, puis reste en attente, tant que vous avez des commandes en cours, de l’argent gardé en séquestre, un solde ou un retrait non réglé, ou une réclamation ou un litige ouvert : terminez-les d’abord. Vos annonces sont retirées et votre boutique est fermée.', style: _st),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer la demande')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final r = await Backend.rpc('request_account_deletion', const {});
  if (!context.mounted) return;
  final d = r.data;
  if (r.error != null || d is! Map || d['status'] != 'pending') {
    await gAlert(context, 'Demande non enregistrée', r.error ?? 'Le serveur n’a pas confirmé la demande. Réessayez.');
    return;
  }
  ref.invalidate(myDeletionProvider);
  gToast(context, d['already'] == true ? 'Une demande de suppression est déjà en cours (effet le ${_fr(d['scheduled_for'])}).' : 'Demande enregistrée : suppression à partir du ${_fr(d['scheduled_for'])}. Vous pouvez l’annuler d’ici là.');
}

Future<void> _demoDeletion(BuildContext context, WidgetRef ref) async {
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
