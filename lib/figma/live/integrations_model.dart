/// Hub d'intégrations (écrans 271, 280, P3, P5) — catalogue des fournisseurs, modèles de données et règles pures (testables sans réseau).
/// Source de vérité côté serveur : table `integration_providers` (migration 20261109000000) ; ce catalogue sert à l'affichage hors connexion.
library;

enum IntFamily {
  reseaux('Réseaux', 'Facebook, Instagram, LinkedIn…'),
  productivite('Productivité', 'Google, OneDrive, Dropbox'),
  collaboration('Collaboration', 'Slack, GitHub, Notion…'),
  telecom('Télécoms & Mobile Money', 'MTN MoMo, Orange Money');

  const IntFamily(this.label, this.hint);
  final String label, hint;
}

/// Un fournisseur du catalogue. [limit] = limite officielle de l'API ; [alternative] = ce qui est proposé à la place.
class IntProvider {
  const IntProvider({
    required this.id,
    required this.family,
    required this.name,
    required this.summary,
    this.canImport = false,
    this.canPublish = false,
    this.hasWebhook = false,
    this.linkOnly = false,
    this.pkce = true,
    this.permissions = const [],
    this.review,
    this.limit,
    this.alternative,
    this.oauth1 = false,
  });

  final String id, name, summary;
  final IntFamily family;
  final bool canImport, canPublish, hasWebhook, linkOnly, pkce, oauth1;

  /// Permissions demandées, en français (affichées avant l'autorisation).
  final List<String> permissions;

  /// Approbation exigée par le fournisseur avant l'usage public (revue d'application, audit…).
  final String? review;
  final String? limit, alternative;

  bool get isMobileMoney => family == IntFamily.telecom;
}

const kProviders = <IntProvider>[
  // A — Réseaux
  IntProvider(
    id: 'facebook', family: IntFamily.reseaux, name: 'Facebook', summary: 'Vos Pages : lecture et publication', canImport: true, canPublish: true, hasWebhook: true, pkce: false,
    permissions: ['Lire le profil public', 'Lister vos Pages', 'Lire les publications de vos Pages', 'Publier sur vos Pages'],
    review: 'Revue d’application Meta et vérification de l’entreprise.',
    limit: 'L’API officielle ne gère que les Pages Facebook, jamais un profil personnel.',
    alternative: 'Profil personnel : copier le texte et le coller sur Facebook.',
  ),
  IntProvider(
    id: 'instagram', family: IntFamily.reseaux, name: 'Instagram', summary: 'Compte professionnel : médias et légendes', canImport: true, canPublish: true, hasWebhook: true, pkce: false,
    permissions: ['Lire le profil professionnel et les médias', 'Publier une image ou une vidéo'],
    review: 'Revue d’application Meta ; compte Business ou Créateur obligatoire.',
    limit: 'Compte professionnel uniquement ; une publication exige une image ou une vidéo.',
    alternative: 'Compte personnel : ajouter le lien du profil et copier la légende.',
  ),
  IntProvider(
    id: 'linkedin', family: IntFamily.reseaux, name: 'LinkedIn', summary: 'Publier sur votre profil', canPublish: true, pkce: false,
    permissions: ['Connexion avec LinkedIn (nom, photo)', 'Publier en votre nom'],
    review: 'Produit « Share on LinkedIn » à activer ; lecture des publications sur approbation LinkedIn.',
    limit: 'La lecture de vos publications n’est pas ouverte sans approbation LinkedIn : import indisponible.',
    alternative: 'Lien du profil + publication par la fenêtre de partage LinkedIn.',
  ),
  IntProvider(
    id: 'tiktok', family: IntFamily.reseaux, name: 'TikTok', summary: 'Importer vos vidéos publiques', canImport: true,
    permissions: ['Lire le profil de base', 'Lister vos vidéos'],
    review: 'Revue de l’application TikTok ; audit obligatoire pour publier.',
    limit: 'Sans audit TikTok, les contenus publiés par une application restent privés : publication non proposée.',
    alternative: 'Import des vidéos ; publication manuelle depuis l’application TikTok.',
  ),
  IntProvider(
    id: 'youtube', family: IntFamily.reseaux, name: 'YouTube', summary: 'Importer votre chaîne et vos vidéos', canImport: true,
    permissions: ['Lire votre chaîne et vos vidéos (lecture seule)'],
    review: 'Vérification Google de l’écran de consentement.',
    limit: 'Quota API de 10 000 unités par jour ; aucune API pour les publications « communauté ».',
    alternative: 'Partager le lien d’une vidéo dans la publication.',
  ),
  IntProvider(
    id: 'behance', family: IntFamily.reseaux, name: 'Behance', summary: 'Portfolio : adresse publique', linkOnly: true,
    limit: 'Adobe n’ouvre plus de nouvelles clés pour l’API Behance.',
    alternative: 'Enregistrez l’adresse publique de votre portfolio : elle s’affiche sur votre profil.',
  ),
  // B — Productivité
  IntProvider(
    id: 'google_drive', family: IntFamily.productivite, name: 'Google Drive', summary: 'Fichiers et dossiers du portfolio', canImport: true,
    permissions: ['Accéder aux fichiers créés ou ouverts avec Boutik-École', 'Lire votre nom'],
    limit: 'Portée limitée : seuls les fichiers que vous partagez avec l’application sont visibles.',
    alternative: 'Coller un lien de partage Drive dans le portfolio.',
  ),
  IntProvider(
    id: 'google_docs', family: IntFamily.productivite, name: 'Google Docs', summary: 'Documents et exports de texte', canImport: true, canPublish: true,
    permissions: ['Créer et ouvrir des documents avec Boutik-École', 'Lire votre nom'],
    limit: 'Seuls les documents créés ou ouverts avec l’application sont accessibles.',
  ),
  IntProvider(
    id: 'google_sheets', family: IntFamily.productivite, name: 'Google Sheets', summary: 'Classeurs et exports de données', canImport: true, canPublish: true,
    permissions: ['Créer et ouvrir des classeurs avec Boutik-École', 'Lire votre nom'],
    limit: 'Seuls les classeurs créés ou ouverts avec l’application sont accessibles.',
  ),
  IntProvider(
    id: 'gmail', family: IntFamily.productivite, name: 'Gmail', summary: 'Envoi de courriels depuis votre adresse',
    permissions: ['Envoyer des courriels en votre nom', 'Lire votre nom et votre adresse'],
    review: 'Vérification Google (portée sensible).',
    limit: 'Envoi seul : la lecture de la boîte de réception exige un audit de sécurité annuel, elle n’est jamais demandée.',
  ),
  IntProvider(
    id: 'google_calendar', family: IntFamily.productivite, name: 'Google Agenda', summary: 'Vos prochains événements', canImport: true,
    permissions: ['Lire et gérer vos événements', 'Lire votre nom et votre adresse'],
    review: 'Vérification Google (portée sensible).',
  ),
  IntProvider(
    id: 'onedrive', family: IntFamily.productivite, name: 'OneDrive', summary: 'Fichiers Microsoft', canImport: true,
    permissions: ['Lire vos fichiers OneDrive', 'Lire votre profil', 'Rester connecté (jeton de rafraîchissement)'],
    limit: 'Un compte professionnel peut exiger l’accord d’un administrateur.',
  ),
  IntProvider(
    id: 'dropbox', family: IntFamily.productivite, name: 'Dropbox', summary: 'Fichiers Dropbox', canImport: true, hasWebhook: true,
    permissions: ['Lire votre nom', 'Lire les métadonnées de vos fichiers'],
    review: 'Passage en production Dropbox après revue au-delà de 50 utilisateurs.',
  ),
  // C — Collaboration
  IntProvider(
    id: 'slack', family: IntFamily.collaboration, name: 'Slack', summary: 'Publier dans vos canaux', canPublish: true, pkce: false,
    permissions: ['Publier des messages', 'Lister les canaux publics'],
    limit: 'L’application doit être installée dans chaque espace de travail.',
    alternative: 'Webhook entrant de votre espace de travail.',
  ),
  IntProvider(
    id: 'discord', family: IntFamily.collaboration, name: 'Discord', summary: 'Publier dans un salon', canPublish: true,
    permissions: ['Lire votre identité Discord', 'Créer un webhook dans le salon que vous choisissez'],
    limit: 'La publication passe par un webhook de salon, jamais par un bot.',
  ),
  IntProvider(
    id: 'github', family: IntFamily.collaboration, name: 'GitHub', summary: 'Vos dépôts publics en portfolio', canImport: true,
    permissions: ['Lire votre profil public'],
    limit: 'Seuls vos dépôts publics sont importés ; aucun accès à vos dépôts privés.',
  ),
  IntProvider(
    id: 'notion', family: IntFamily.collaboration, name: 'Notion', summary: 'Pages partagées', canImport: true, canPublish: true, pkce: false,
    permissions: ['Lire les pages que vous partagez', 'Créer des pages dans les pages partagées'],
    limit: 'Notion ne montre que les pages que vous partagez explicitement à l’autorisation.',
  ),
  IntProvider(
    id: 'trello', family: IntFamily.collaboration, name: 'Trello', summary: 'Vos tableaux', canImport: true, oauth1: true, pkce: false,
    permissions: ['Lire vos tableaux'],
    limit: 'Trello n’offre pas OAuth 2.0 : autorisation OAuth 1.0a officielle, signée côté serveur.',
  ),
  IntProvider(
    id: 'teams', family: IntFamily.collaboration, name: 'Microsoft Teams', summary: 'Publier dans un canal', canPublish: true,
    permissions: ['Lire vos équipes et canaux', 'Envoyer des messages dans un canal'],
    review: 'Consentement d’un administrateur du locataire Microsoft.',
    alternative: 'Webhook ou flux de travail Teams du canal.',
  ),
  // D — Télécoms & Mobile Money
  IntProvider(
    id: 'mtn_momo', family: IntFamily.telecom, name: 'MTN Mobile Money', summary: 'Numéros, envois et historique',
    review: 'Contrat marchand MTN et clés du portail MTN MoMo Developer.',
    limit: 'Sans contrat marchand, les numéros se vérifient mais aucun envoi n’est exécuté.',
  ),
  IntProvider(
    id: 'orange_money', family: IntFamily.telecom, name: 'Orange Money', summary: 'Numéros, envois et historique',
    review: 'Contrat marchand Orange Money et identifiants d’API Orange.',
    limit: 'Sans contrat marchand, les numéros se vérifient mais aucun envoi n’est exécuté.',
  ),
];

IntProvider? providerById(String id) {
  for (final p in kProviders) {
    if (p.id == id) return p;
  }
  return null;
}

/// Recherche insensible à la casse et aux accents sur le nom, le résumé et la famille.
List<IntProvider> filterProviders(String query, {IntFamily? family}) {
  final q = _fold(query.trim());
  return [
    for (final p in kProviders)
      if ((family == null || p.family == family) && (q.isEmpty || _fold('${p.name} ${p.summary} ${p.family.label}').contains(q))) p,
  ];
}

String _fold(String s) {
  const from = 'àâäáãçéèêëíìîïñóòôöõúùûüýÿ';
  const to = 'aaaaaceeeeiiiinooooouuuuyy';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString();
}

// ---------------------------------------------------------------- connexions

enum ConnStatus { connected, expired, revoked, error }

ConnStatus connStatusOf(String s) => switch (s) {
      'expired' => ConnStatus.expired,
      'revoked' => ConnStatus.revoked,
      'error' => ConnStatus.error,
      _ => ConnStatus.connected,
    };

String connStatusLabel(ConnStatus s) => switch (s) {
      ConnStatus.connected => 'Connecté',
      ConnStatus.expired => 'À reconnecter',
      ConnStatus.revoked => 'Déconnecté',
      ConnStatus.error => 'Erreur',
    };

class IntAccount {
  const IntAccount({required this.id, required this.externalId, required this.kind, required this.name, this.url, this.publish = false});
  final String id, externalId, kind, name;
  final String? url;
  final bool publish;

  factory IntAccount.fromJson(Map<String, dynamic> j) => IntAccount(
        id: '${j['id']}', externalId: '${j['external_id']}', kind: '${j['kind'] ?? 'account'}', name: '${j['name'] ?? ''}',
        url: j['url'] as String?, publish: j['publish_enabled'] == true,
      );
}

class IntConnection {
  const IntConnection({
    required this.id,
    required this.provider,
    required this.displayName,
    required this.status,
    this.profileUrl,
    this.lastSync,
    this.nextSync,
    this.expiresAt,
    this.lastError,
    this.accounts = const [],
    this.permissions = const [],
  });

  final String id, provider, displayName;
  final ConnStatus status;
  final String? profileUrl, lastError;
  final DateTime? lastSync, nextSync, expiresAt;
  final List<IntAccount> accounts;
  final List<String> permissions;

  bool get active => status == ConnStatus.connected;

  factory IntConnection.fromJson(Map<String, dynamic> j) => IntConnection(
        id: '${j['id']}', provider: '${j['provider']}', displayName: '${j['display_name'] ?? ''}', status: connStatusOf('${j['status']}'),
        profileUrl: j['profile_url'] as String?, lastError: j['last_error'] as String?,
        lastSync: _date(j['last_sync_at']), nextSync: _date(j['next_sync_at']), expiresAt: _date(j['expires_at']),
        accounts: [for (final a in (j['integration_accounts'] as List? ?? const [])) IntAccount.fromJson(Map<String, dynamic>.from(a as Map))],
        permissions: [for (final p in (j['integration_permissions'] as List? ?? const [])) '${(p as Map)['scope']}'],
      );
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// Contenu importé depuis un fournisseur (espace « Mes contenus connectés »).
class IntItem {
  const IntItem({required this.id, required this.provider, required this.kind, required this.title, required this.visibility, this.url, this.body, this.mediaUrl, this.publishedAt});
  final String id, provider, kind, title, visibility;
  final String? url, body, mediaUrl;
  final DateTime? publishedAt;

  factory IntItem.fromJson(Map<String, dynamic> j) => IntItem(
        id: '${j['id']}', provider: '${j['provider']}', kind: '${j['kind']}', title: '${j['title'] ?? ''}', visibility: '${j['visibility'] ?? 'private'}',
        url: j['url'] as String?, body: j['body'] as String?, mediaUrl: j['media_url'] as String?, publishedAt: _date(j['published_at']),
      );
}

String visibilityLabel(String v) => switch (v) { 'public' => 'Public', 'portfolio' => 'Portfolio', _ => 'Privé' };

String kindLabel(String k) => switch (k) {
      'video' => 'Vidéo',
      'repo' => 'Dépôt',
      'file' => 'Fichier',
      'folder' => 'Dossier',
      'document' => 'Document',
      'spreadsheet' => 'Classeur',
      'event' => 'Événement',
      'page' => 'Page',
      'board' => 'Tableau',
      _ => 'Publication',
    };

/// Résultat d'une publication vers une plateforme.
class PublishResult {
  const PublishResult({required this.provider, required this.status, required this.text, this.url, this.error});
  final String provider, status, text;
  final String? url, error;

  bool get sent => status == 'sent';

  factory PublishResult.fromJson(Map<String, dynamic> j) => PublishResult(
        provider: '${j['provider']}', status: '${j['status']}', text: '${j['adapted_text'] ?? ''}', url: j['result_url'] as String?, error: j['error'] as String?,
      );
}

String publishStatusLabel(String s) => switch (s) { 'sent' => 'Publié', 'failed' => 'Échec', 'unsupported' => 'Non pris en charge', _ => 'En attente' };

// ---------------------------------------------------------------- adaptation du texte (miroir de supabase/functions/_shared/adapt.ts)

const kTextLimits = <String, int>{
  'facebook': 5000, 'instagram': 2200, 'linkedin': 3000, 'discord': 2000, 'slack': 3000, 'teams': 4000,
  'notion': 1900, 'google_docs': 20000, 'google_sheets': 5000,
};

class Adapted {
  const Adapted(this.text, {this.link, this.note});
  final String text;
  final String? link, note;
}

String _clip(String text, int max) {
  if (text.length <= max) return text;
  final cut = text.substring(0, max - 1);
  final sp = cut.lastIndexOf(' ');
  final body = sp > max * 0.6 ? cut.substring(0, sp) : cut;
  return '${body.trimRight()}…';
}

/// Texte adapté à chaque plateforme : limite de longueur, usage des liens. Même règle que le serveur : l'aperçu = le texte envoyé.
Adapted adaptForPlatform(String provider, String content, {String link = ''}) {
  var t = content.replaceAll('\r\n', '\n').replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  final max = kTextLimits[provider] ?? 3000;
  final url = link.trim();
  switch (provider) {
    case 'instagram':
      final suffix = url.isEmpty ? '' : '\n\nLien dans la bio.';
      final tags = RegExp(r'#[\p{L}\p{N}_]+', unicode: true).allMatches(t).map((m) => m.group(0)!).toList();
      if (tags.length > 30) {
        for (final x in tags.skip(30)) {
          t = t.replaceFirst(x, '');
        }
        t = t.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
      }
      return Adapted(_clip(t, max - suffix.length) + suffix, note: url.isEmpty ? null : 'Lien non cliquable sur Instagram : « Lien dans la bio ».');
    case 'facebook':
      return Adapted(_clip(t, max), link: url.isEmpty ? null : url);
    case 'slack':
      t = t.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '*${m[1]}*');
      final suffix = url.isEmpty ? '' : '\n$url';
      return Adapted(_clip(t, max - suffix.length) + suffix);
    default:
      final suffix = url.isEmpty ? '' : '\n\n$url';
      return Adapted(_clip(t, max - suffix.length) + suffix);
  }
}

// ---------------------------------------------------------------- Mobile Money

/// +237 6 •• •• •• 42 : le numéro complet n'est jamais affiché hors de l'écran de détail.
String maskPhone(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length < 12) return p;
  return '+${d.substring(0, 3)} ${d[3]} •• •• •• ${d.substring(d.length - 2)}';
}

/// 237 6XX XX XX XX (affichage complet).
String formatPhone(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  if (d.length != 12) return p;
  return '+${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6, 8)} ${d.substring(8, 10)} ${d.substring(10)}';
}

/// Normalise une saisie (6XXXXXXXX, +237 6XX…) ; null si ce n'est pas un numéro camerounais plausible.
String? normalizePhone(String input) {
  var d = input.replaceAll(RegExp(r'\D'), '');
  if (RegExp(r'^6\d{8}$').hasMatch(d)) d = '237$d';
  return RegExp(r'^2376\d{8}$').hasMatch(d) ? d : null;
}

enum MomoVerif { unverified, pending, verified, failed }

MomoVerif momoVerifOf(String s) => switch (s) { 'verified' => MomoVerif.verified, 'pending' => MomoVerif.pending, 'failed' => MomoVerif.failed, _ => MomoVerif.unverified };

String momoVerifLabel(MomoVerif v) => switch (v) {
      MomoVerif.verified => 'Vérifié',
      MomoVerif.pending => 'Code envoyé',
      MomoVerif.failed => 'Échec de vérification',
      MomoVerif.unverified => 'Non vérifié',
    };

class MomoNumber {
  const MomoNumber({required this.id, required this.operator, required this.phone, required this.label, required this.primary, required this.verif});
  final String id, operator, phone, label;
  final bool primary;
  final MomoVerif verif;

  String get operatorName => operator == 'MTN' ? 'MTN MoMo' : 'Orange Money';
  String get title => label.isEmpty ? operatorName : label;
  bool get verified => verif == MomoVerif.verified;

  factory MomoNumber.fromJson(Map<String, dynamic> j) => MomoNumber(
        id: '${j['id']}', operator: '${j['operator']}', phone: '${j['phone']}', label: '${j['label'] ?? ''}', primary: j['is_primary'] == true, verif: momoVerifOf('${j['verification_status']}'),
      );
}

class MomoTx {
  const MomoTx({
    required this.reference,
    required this.operator,
    required this.direction,
    required this.phone,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.note,
    this.failure,
    this.decidedAt,
    this.confirmedByUserAt,
    this.fee,
    this.currency = 'XAF',
  });

  final String reference, operator, direction, phone, status, currency;
  final int amount;
  final int? fee;
  final String? note, failure;
  final DateTime createdAt;
  final DateTime? decidedAt, confirmedByUserAt;

  bool get outgoing => direction == 'out';
  bool get done => status == 'confirmed';
  String get statusLabel => momoStatusLabel(status);

  factory MomoTx.fromJson(Map<String, dynamic> j) => MomoTx(
        reference: '${j['reference']}', operator: '${j['operator']}', direction: '${j['direction']}', phone: '${j['counterparty_phone']}',
        amount: (j['amount'] as num).toInt(), status: '${j['status']}', createdAt: _date(j['created_at']) ?? DateTime.now(), note: j['note'] as String?,
        failure: j['failure_reason'] as String?, decidedAt: _date(j['decided_at']), confirmedByUserAt: _date(j['confirmed_by_user_at']),
        fee: (j['fee'] as num?)?.toInt(), currency: '${j['currency'] ?? 'XAF'}',
      );
}

String momoStatusLabel(String s) => switch (s) {
      'confirmed' => 'Réussi',
      'pending' => 'En cours',
      'failed' => 'Échoué',
      'cancelled' => 'Annulé',
      _ => 'À confirmer',
    };

class MomoDashboard {
  const MomoDashboard({this.sentMonth = 0, this.receivedMonth = 0, this.pending = 0, this.failedMonth = 0, this.countMonth = 0});
  final int sentMonth, receivedMonth, pending, failedMonth, countMonth;

  factory MomoDashboard.fromJson(Map<String, dynamic> j) => MomoDashboard(
        sentMonth: (j['sent_month'] as num?)?.toInt() ?? 0, receivedMonth: (j['received_month'] as num?)?.toInt() ?? 0, pending: (j['pending'] as num?)?.toInt() ?? 0,
        failedMonth: (j['failed_month'] as num?)?.toInt() ?? 0, countMonth: (j['count_month'] as num?)?.toInt() ?? 0,
      );
}

/// Contrôle de saisie d'un envoi avant même d'appeler le serveur (le serveur revérifie tout). Renvoie un message d'erreur, ou null.
String? validateTransfer({required String to, required String amount, required MomoNumber? from, int max = 500000}) {
  if (from == null) return 'Choisissez le numéro qui envoie.';
  if (!from.verified) return 'Vérifiez ce numéro avant d’envoyer de l’argent.';
  final n = normalizePhone(to);
  if (n == null) return 'Numéro du destinataire invalide (6XX XX XX XX).';
  if (n == from.phone) return 'Le destinataire doit être différent de l’expéditeur.';
  final a = int.tryParse(amount.replaceAll(RegExp(r'[\s.]'), ''));
  if (a == null || a < 1 || a > max) return 'Montant invalide (1 à $max FCFA).';
  return null;
}

/// Texte du reçu (copie / partage). Ne contient jamais de PIN ni de numéro complet de l'expéditeur.
String receiptText(MomoTx t, {String? fromLabel}) {
  final b = StringBuffer()
    ..writeln('Reçu Boutik-École · ${t.operator == 'MTN' ? 'MTN MoMo' : 'Orange Money'}')
    ..writeln('Référence : ${t.reference}')
    ..writeln('${t.outgoing ? 'Destinataire' : 'Expéditeur'} : ${maskPhone(t.phone)}');
  if (fromLabel != null) b.writeln('Compte : $fromLabel');
  b
    ..writeln('Montant : ${t.amount} ${t.currency == 'XAF' ? 'FCFA' : t.currency}')
    ..writeln('État : ${t.statusLabel}')
    ..writeln('Date : ${t.createdAt.day.toString().padLeft(2, '0')}/${t.createdAt.month.toString().padLeft(2, '0')}/${t.createdAt.year}');
  if (t.note != null && t.note!.isNotEmpty) b.writeln('Note : ${t.note}');
  return b.toString().trimRight();
}

// ---------------------------------------------------------------- exigences à fournir par le propriétaire (affichées à l'administration, écran 280)

/// Ce que chaque fournisseur exige avant de fonctionner réellement. Aucune clé n'est inventée : tant que ces éléments manquent, le connecteur reste « en attente ».
List<String> ownerRequirements(IntProvider p) {
  if (p.isMobileMoney) {
    return p.id == 'mtn_momo'
        ? ['Contrat marchand MTN MoMo (Disbursement)', 'MTN_MOMO_SUBSCRIPTION_KEY, MTN_MOMO_API_USER, MTN_MOMO_API_KEY', 'MTN_MOMO_TARGET_ENV, MTN_MOMO_CURRENCY, MTN_MOMO_CALLBACK_SECRET']
        : ['Contrat marchand Orange Money', 'Identifiants et documentation d’API fournis par Orange'];
  }
  if (p.linkOnly) return ['Aucun : adresse publique saisie par l’utilisateur'];
  final env = switch (p.id) {
    'youtube' || 'google_drive' || 'google_docs' || 'google_sheets' || 'gmail' || 'google_calendar' => 'GOOGLE',
    'onedrive' || 'teams' => 'MICROSOFT',
    _ => p.id.toUpperCase(),
  };
  return [
    if (p.review != null) p.review!,
    '${env}_CLIENT_ID et ${env}_CLIENT_SECRET (application développeur)',
    'URI de redirection : …/functions/v1/integrations-oauth/callback',
  ];
}
