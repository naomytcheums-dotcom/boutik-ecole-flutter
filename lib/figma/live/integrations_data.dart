import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth.dart';
import 'backend.dart';
import 'integrations_model.dart';

/// Données du hub d'intégrations. Rien n'est simulé : sans serveur ou sans compte, les listes restent vides.
/// Les jetons OAuth ne transitent JAMAIS par ici : les Edge Functions les chiffrent et ne renvoient que des états.
class IntegrationsState {
  const IntegrationsState({
    this.connections = const [],
    this.items = const [],
    this.numbers = const [],
    this.transactions = const [],
    this.dashboard = const MomoDashboard(),
    this.ready = const {},
    this.momoReady = const (mtn: false, orange: false, sms: false),
    this.encryption = false,
    this.catalogKnown = false,
    this.loading = false,
    this.loaded = false,
    this.error,
  });

  final List<IntConnection> connections;
  final List<IntItem> items;
  final List<MomoNumber> numbers;
  final List<MomoTx> transactions;
  final MomoDashboard dashboard;

  /// Fournisseurs dont l'application développeur est enregistrée côté serveur (booléens, aucun secret).
  final Map<String, bool> ready;
  final ({bool mtn, bool orange, bool sms}) momoReady;
  final bool encryption, catalogKnown, loading, loaded;
  final String? error;

  List<IntConnection> connectionsOf(String provider) => [for (final c in connections) if (c.provider == provider) c];
  IntConnection? activeOf(String provider) {
    for (final c in connections) {
      if (c.provider == provider && c.status != ConnStatus.revoked) return c;
    }
    return null;
  }

  bool isReady(IntProvider p) => p.linkOnly || p.isMobileMoney ? true : (ready[p.id] ?? false) && encryption;

  IntegrationsState copy({
    List<IntConnection>? connections,
    List<IntItem>? items,
    List<MomoNumber>? numbers,
    List<MomoTx>? transactions,
    MomoDashboard? dashboard,
    Map<String, bool>? ready,
    ({bool mtn, bool orange, bool sms})? momoReady,
    bool? encryption,
    bool? catalogKnown,
    bool? loading,
    bool? loaded,
    String? error,
    bool clearError = false,
  }) =>
      IntegrationsState(
        connections: connections ?? this.connections,
        items: items ?? this.items,
        numbers: numbers ?? this.numbers,
        transactions: transactions ?? this.transactions,
        dashboard: dashboard ?? this.dashboard,
        ready: ready ?? this.ready,
        momoReady: momoReady ?? this.momoReady,
        encryption: encryption ?? this.encryption,
        catalogKnown: catalogKnown ?? this.catalogKnown,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded,
        error: clearError ? null : (error ?? this.error),
      );
}

typedef FnResult = ({Map<String, dynamic> data, String? error});

/// Appel d'une Edge Function ; l'erreur est un message lisible (jamais un corps brut).
Future<FnResult> callFunction(String name, Map<String, dynamic> body) async {
  if (!Backend.ready) return (data: const <String, dynamic>{}, error: 'Connexion au serveur requise.');
  try {
    final r = await Supabase.instance.client.functions.invoke(name, body: body);
    final d = r.data;
    return (data: d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{}, error: null);
  } on FunctionException catch (e) {
    final d = e.details;
    final m = d is Map ? d['message'] : null;
    return (data: d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{}, error: m is String && m.isNotEmpty ? m : 'Le service a répondu avec une erreur (${e.status}).');
  } catch (_) {
    return (data: const <String, dynamic>{}, error: 'Le service est injoignable. Réessayez.');
  }
}

class IntNotifier extends Notifier<IntegrationsState> {
  @override
  IntegrationsState build() {
    if (!Backend.ready) return const IntegrationsState();
    final uid = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    if (uid.isNotEmpty) Future.microtask(refresh);
    return const IntegrationsState();
  }

  Future<void> refresh() async {
    if (!Backend.ready) return;
    state = state.copy(loading: true, clearError: true);
    final res = await Future.wait([
      Backend.rows('integration_connections', '*,integration_accounts(*),integration_permissions(scope)', order: 'connected_at', limit: 200),
      Backend.rows('integration_imported_items', '*', order: 'imported_at', limit: 200, eq: {'user_id': _uid}),
      Backend.rows('momo_numbers', '*', order: 'created_at', ascending: true),
      Backend.rows('momo_transactions', '*', order: 'created_at', limit: 100),
      Backend.rpc('momo_dashboard', const {}),
      callFunction('integrations-oauth', {'action': 'catalog'}),
    ]);
    if (!ref.mounted) return;
    final conns = res[0] as ({List<Map<String, dynamic>> rows, String? error});
    final items = res[1] as ({List<Map<String, dynamic>> rows, String? error});
    final nums = res[2] as ({List<Map<String, dynamic>> rows, String? error});
    final txs = res[3] as ({List<Map<String, dynamic>> rows, String? error});
    final dash = res[4] as ({Object? data, String? error});
    final cat = res[5] as FnResult;
    final provs = (cat.data['providers'] as Map?) ?? const {};
    final momo = (cat.data['momo'] as Map?) ?? const {};
    state = state.copy(
      connections: [for (final r in conns.rows) IntConnection.fromJson(r)],
      items: [for (final r in items.rows) IntItem.fromJson(r)],
      numbers: [for (final r in nums.rows) MomoNumber.fromJson(r)],
      transactions: [for (final r in txs.rows) MomoTx.fromJson(r)],
      dashboard: dash.data is Map ? MomoDashboard.fromJson(Map<String, dynamic>.from(dash.data as Map)) : const MomoDashboard(),
      ready: {for (final e in provs.entries) '${e.key}': e.value == true},
      momoReady: (mtn: momo['mtn'] == true, orange: momo['orange'] == true, sms: momo['sms'] == true),
      encryption: cat.data['encryption'] == true,
      catalogKnown: cat.error == null,
      loading: false,
      loaded: true,
      error: conns.error,
    );
  }

  String get _uid => ref.read(authProvider).current?.serverId ?? '';

  // ------------------------------------------------------------ connexions

  /// Adresse d'autorisation du fournisseur ; l'application l'ouvre dans le même onglet puis le fournisseur revient sur `/s/P5?connexion=ok`.
  Future<String?> connect(String provider) async {
    final r = await callFunction('integrations-oauth', {'action': 'start', 'provider': provider, 'return_to': 'https://boutik-ecole.vercel.app/s/P5'});
    if (r.error != null) return r.error;
    final url = r.data['url'];
    if (url is! String || !url.startsWith('https://')) return 'Adresse d’autorisation invalide.';
    final ok = await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
    return ok ? null : 'Impossible d’ouvrir la page d’autorisation.';
  }

  /// Renvoie (message d'erreur, révoqué chez le fournisseur ?).
  Future<(String?, bool)> disconnect(String connectionId, {bool purge = false}) async {
    final r = await callFunction('integrations-oauth', {'action': 'disconnect', 'connection_id': connectionId, 'purge': purge});
    if (r.error != null) return (r.error, false);
    await refresh();
    return (null, r.data['revoked_at_provider'] == true);
  }

  /// Message affichable pour le résultat d'une synchronisation.
  Future<(bool, String)> sync(String connectionId) async {
    final r = await callFunction('integrations-sync', {'connection_id': connectionId});
    if (r.error != null) return (false, r.error!);
    await refresh();
    final status = '${r.data['status']}';
    final imp = (r.data['imported'] as num?)?.toInt() ?? 0;
    final skip = (r.data['skipped'] as num?)?.toInt() ?? 0;
    return switch (status) {
      'ok' => (true, imp == 0 ? 'À jour : aucun nouveau contenu ($skip déjà importé${skip > 1 ? 's' : ''}).' : '$imp nouveau${imp > 1 ? 'x' : ''} contenu${imp > 1 ? 's' : ''} importé${imp > 1 ? 's' : ''}.'),
      'throttled' => (false, '${r.data['message'] ?? 'Quota atteint'} Réessayez plus tard.'),
      _ => (false, '${r.data['message'] ?? 'Synchronisation impossible.'}'),
    };
  }

  Future<String?> setPublishAccount(String accountId, bool enabled) async {
    final r = await Backend.rpc('integrations_set_account_publish', {'p_account': accountId, 'p_enabled': enabled});
    if (r.error == null) await refresh();
    return r.error;
  }

  Future<String?> saveLink(String provider, String url) async {
    final r = await Backend.rpc('integrations_save_link', {'p_provider': provider, 'p_url': url});
    if (r.error == null) await refresh();
    return r.error;
  }

  Future<String?> setVisibility(String itemId, String visibility) async {
    final r = await Backend.rpc('integrations_set_item_visibility', {'p_item': itemId, 'p_visibility': visibility});
    if (r.error == null) await refresh();
    return r.error;
  }

  Future<String?> deleteItem(String itemId) async {
    final r = await Backend.rpc('integrations_delete_item', {'p_item': itemId});
    if (r.error == null) await refresh();
    return r.error;
  }

  // ------------------------------------------------------------ publication

  Future<({List<PublishResult> results, String? error})> publish({
    required String content,
    required String idempotencyKey,
    required List<({String connectionId, String? accountId})> targets,
    String link = '',
    String media = '',
  }) async {
    final r = await callFunction('integrations-publish', {
      'content': content,
      'idempotency_key': idempotencyKey,
      if (link.isNotEmpty) 'link_url': link,
      if (media.isNotEmpty) 'media_url': media,
      'targets': [for (final t in targets) {'connection_id': t.connectionId, if (t.accountId != null) 'account_id': t.accountId}],
    });
    if (r.error != null) return (results: const <PublishResult>[], error: r.error);
    return (results: [for (final x in (r.data['results'] as List? ?? const [])) PublishResult.fromJson(Map<String, dynamic>.from(x as Map))], error: null);
  }

  // ------------------------------------------------------------ Mobile Money

  Future<String?> addNumber(String operator, String phone, String label) async {
    final r = await Backend.rpc('momo_add_number', {'p_operator': operator, 'p_phone': phone, 'p_label': label});
    if (r.error == null) await refresh();
    return r.error;
  }

  Future<String?> setPrimary(String id) => _numberRpc('momo_set_primary', {'p_id': id});
  Future<String?> renameNumber(String id, String label) => _numberRpc('momo_rename_number', {'p_id': id, 'p_label': label});
  Future<String?> removeNumber(String id) => _numberRpc('momo_remove_number', {'p_id': id});

  Future<String?> _numberRpc(String fn, Map<String, dynamic> p) async {
    final r = await Backend.rpc(fn, p);
    if (r.error == null) await refresh();
    return r.error;
  }

  Future<String?> requestVerification(String numberId) async {
    final r = await callFunction('momo', {'action': 'request_verification', 'number_id': numberId});
    if (r.error == null) await refresh();
    return r.error;
  }

  /// (vérifié ?, erreur)
  Future<(bool, String?)> confirmVerification(String numberId, String code) async {
    final r = await Backend.rpc('momo_confirm_verification', {'p_id': numberId, 'p_code': code});
    if (r.error != null) return (false, r.error);
    await refresh();
    return (r.data == true, null);
  }

  /// Prépare l'envoi (aucun débit) ; renvoie la référence.
  Future<({String? reference, String? error})> prepareTransfer({required String numberId, required String to, required int amount, required String note, required String idempotencyKey}) async {
    final r = await Backend.rpc('momo_prepare_transfer', {'p_number': numberId, 'p_to': to, 'p_amount': amount, 'p_note': note, 'p_idem': idempotencyKey});
    if (r.error != null) return (reference: null, error: r.error);
    await refresh();
    return (reference: '${r.data}', error: null);
  }

  /// Engage l'envoi : uniquement après l'écran de confirmation explicite.
  Future<(String status, String message)> confirmTransfer(String reference) async {
    final r = await callFunction('momo', {'action': 'confirm_transfer', 'reference': reference, 'confirm': true});
    await refresh();
    if (r.error != null) return ('error', r.error!);
    return ('${r.data['status']}', '${r.data['message'] ?? ''}');
  }

  Future<String?> cancelTransfer(String reference) async {
    final r = await Backend.rpc('momo_cancel_transfer', {'p_ref': reference});
    if (r.error == null) await refresh();
    return r.error;
  }

  Future<String> refreshTransfer(String reference) async {
    final r = await callFunction('momo', {'action': 'refresh_status', 'reference': reference});
    await refresh();
    return r.error == null ? '${r.data['status']}' : 'error';
  }
}

final integrationsProvider = NotifierProvider<IntNotifier, IntegrationsState>(IntNotifier.new);
