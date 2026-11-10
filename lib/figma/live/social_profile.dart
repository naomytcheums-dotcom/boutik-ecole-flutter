import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../gen.dart';
import '../nav.dart';
import 'auth.dart';
import 'backend.dart';
import 'messages.dart';
import 'reels.dart';
import 'social_posts.dart' show VerifiedBadge;
import 'stories.dart' show ProfileStoryRing;
import 'talents.dart' show askText;

/// Profil public (écran 247) : identité, compteurs et publications lus sur le serveur.
/// Aucune donnée privée (téléphone, e-mail) n'est demandée ni affichée ; hors serveur, la maquette reste visible.

SocialProfile _profile(Map raw) => SocialProfile.fromJson(raw);

/// Profil public d'une personne, ou profil personnel (`userId` vide).
final publicProfileProvider = FutureProvider.autoDispose
    .family<SocialProfile, String>((ref, userId) async {
      final r = await Backend.rpc('public_profile', {'p_user': userId});
      if (r.error != null) throw Exception(Backend.userMessage(r.error!));
      if (r.data is! Map) throw Exception('Ce profil est introuvable.');
      return _profile(Map<String, dynamic>.from(r.data as Map));
    });

/// Publications média publiées d'une personne, dans la même forme que le fil.
final authorPostsProvider = FutureProvider.autoDispose
    .family<List<Reel>, String>((ref, userId) async {
      final r = await Backend.rpc('author_posts', {
        'p_author': userId,
        'p_limit': 60,
      });
      if (r.error != null) throw Exception(Backend.userMessage(r.error!));
      if (r.data is! List) return const [];
      return [
        for (final x in r.data as List)
          Reel.fromRow(x as Map, Backend.postMediaUrl),
      ];
    });

class SocialProfile {
  const SocialProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.city,
    required this.institution,
    required this.department,
    required this.bio,
    required this.skills,
    required this.avatarUrl,
    required this.certified,
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.rating,
    required this.ratingCount,
  });

  final String id,
      name,
      role,
      city,
      institution,
      department,
      bio,
      skills,
      avatarUrl;
  final bool certified;
  final int postsCount, followersCount, followingCount, ratingCount;
  final double rating;

  static SocialProfile fromJson(Map x) => SocialProfile(
    id: '${x['id'] ?? ''}',
    name: '${x['name'] ?? ''}'.trim(),
    role: '${x['role'] ?? ''}',
    city: '${x['city'] ?? ''}',
    institution: '${x['institution'] ?? ''}',
    department: '${x['department'] ?? ''}',
    bio: '${x['bio'] ?? ''}',
    skills: '${x['skills'] ?? ''}',
    avatarUrl: '${x['avatar_url'] ?? ''}',
    certified: x['certified'] == true,
    postsCount: (x['posts_count'] as num?)?.toInt() ?? 0,
    followersCount: (x['followers_count'] as num?)?.toInt() ?? 0,
    followingCount: (x['following_count'] as num?)?.toInt() ?? 0,
    rating: (x['rating'] as num?)?.toDouble() ?? 0,
    ratingCount: (x['rating_count'] as num?)?.toInt() ?? 0,
  );
}

String roleLabel(String role) => switch (role) {
  'student' => 'Étudiant',
  'client' => 'Client',
  'company' => 'Entreprise',
  'department' => 'Département',
  'admin' => 'Administration',
  'direction' => 'Direction',
  'support' => 'Support',
  _ => 'Membre',
};

String profileSubtitle(SocialProfile p) {
  final parts = [
    if (p.role.trim().isNotEmpty) roleLabel(p.role),
    p.department,
    p.institution,
  ].map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  return parts.isEmpty ? 'Membre de Boutik-École' : parts.join(' · ');
}

/// Panneau plein écran du profil public, utilisé à la place de la maquette quand le serveur est disponible.
class SocialProfilePanel extends ConsumerWidget {
  const SocialProfilePanel({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authProvider.select((a) => a.current?.serverId ?? ''));
    final id = userId.trim().isNotEmpty ? userId.trim() : me;
    if (id.isEmpty) return _signedOut(context, ref);
    final own = id == me;
    final profile = ref.watch(publicProfileProvider(id));
    final posts = ref.watch(authorPostsProvider(id));
    final following = ref.watch(followingIdsProvider);

    return Container(
      key: const Key('social-profile-panel'),
      color: const Color(0xFFF7F5FA),
      child: Column(
        children: [
          _topBar(context, own),
          Expanded(
            child: profile.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _error(context, ref, id, e),
              data: (p) => _body(context, ref, p, posts, following, own),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar(BuildContext context, bool own) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
    child: Row(
      children: [
        _roundButton(Icons.arrow_back, () => gBack(context)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            own ? 'Mon profil' : 'Profil',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _t(18, FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    SocialProfile p,
    AsyncValue<List<Reel>> posts,
    Set<String>? following,
    bool own,
  ) {
    final followed = following?.contains(p.id) ?? false;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileStoryRing(userId: p.id, child: _avatar(p, 86)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p.name.isEmpty ? 'Membre' : p.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _t(21, FontWeight.w700),
                                ),
                              ),
                              if (p.certified) ...[
                                const SizedBox(width: 6),
                                const VerifiedBadge(size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profileSubtitle(p),
                            style: _t(
                              12,
                              FontWeight.w400,
                              const Color(0xFF57545F),
                            ),
                          ),
                          if (p.city.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              p.city,
                              style: _t(
                                12,
                                FontWeight.w400,
                                const Color(0xFF57545F),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (own)
                  _pill(
                    const Key('social-own-badge'),
                    'Votre profil',
                    const Color(0xFFEEE9FF),
                    const Color(0xFF5A3FE0),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _action(
                          key: const Key('social-follow'),
                          label: followed ? 'Suivi' : "S'abonner",
                          filled: !followed,
                          onTap: following == null
                              ? null
                              : () => _toggleFollow(context, ref, p, followed),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _action(
                          key: const Key('social-message'),
                          label: 'Écrire',
                          filled: false,
                          onTap: () => _message(context, ref, p),
                        ),
                      ),
                    ],
                  ),
                if (p.bio.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    p.bio.trim(),
                    style: _t(
                      12.5,
                      FontWeight.w400,
                      const Color(0xFF5B5963),
                    ).copyWith(height: 1.45),
                  ),
                ],
                if (p.skills.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in p.skills.split(RegExp(r'[,;•\n]')))
                        if (s.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9F6),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              s.trim(),
                              style: _t(
                                11,
                                FontWeight.w600,
                                const Color(0xFF4A4854),
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    _stat(p.postsCount, 'Publications'),
                    _stat(p.followersCount, 'Abonnés'),
                    _stat(p.followingCount, 'Suivis'),
                    _statText(
                      p.ratingCount == 0 ? '—' : p.rating.toStringAsFixed(1),
                      'Note',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(height: 1, color: Color(0xFFE9E5EF)),
                const SizedBox(height: 14),
                Text('Publications', style: _t(13, FontWeight.w700)),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: posts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _postsError(context, ref, p.id, e),
            data: (list) => list.isEmpty
                ? Center(
                    child: Text(
                      'Aucune publication pour le moment.',
                      style: _t(12, FontWeight.w400, const Color(0xFF57545F)),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                        ),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _tile(context, ref, list[i]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _avatar(SocialProfile p, double size) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEDE9F6),
      ),
      child: Text(
        _initials(p.name),
        style: _t(24, FontWeight.w700, const Color(0xFF4A4854)),
      ),
    );
    return Container(
      width: size + 6,
      height: size + 6,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF111015),
      ),
      child: ClipOval(
        child: p.avatarUrl.isEmpty
            ? fallback
            : Image.network(
                p.avatarUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }

  Widget _stat(int value, String label) =>
      _statText(compactCount(value), label);

  Widget _statText(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: _t(16, FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: _t(9.5, FontWeight.w400, const Color(0xFF57545F))),
      ],
    ),
  );

  /// Vignette d'une publication du profil : un appui ouvre la publication dans l'écran Reels (lecture, cœur, commentaires, partage).
  Widget _tile(BuildContext context, WidgetRef ref, Reel r) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      ref.read(reelsProvider.notifier).ensure(r);
      final all = ref.read(reelsProvider) ?? const <Reel>[];
      ref.read(reelIndexProvider.notifier).set(all.indexWhere((x) => x.id == r.id).clamp(0, all.length));
      gOpen(context, '245');
    },
    child: _tileBody(r),
  );

  Widget _tileBody(Reel r) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (r.video || r.mediaUrl.isEmpty)
          const ColoredBox(
            color: Color(0xFF18171F),
            child: Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 34,
              ),
            ),
          )
        else
          Image.network(
            r.mediaUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(
              color: Color(0xFFEDE9F6),
              child: Center(
                child: Icon(Icons.image_outlined, color: Color(0xFF57545F)),
              ),
            ),
          ),
        Positioned(
          left: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xB2111015),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, size: 10, color: Colors.white),
                const SizedBox(width: 3),
                Text(
                  compactCount(r.likes),
                  style: _t(9, FontWeight.w600, Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _error(BuildContext context, WidgetRef ref, String id, Object e) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Profil indisponible', style: _t(16, FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                _messageOf(e),
                textAlign: TextAlign.center,
                style: _t(12, FontWeight.w400, const Color(0xFF57545F)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(publicProfileProvider(id)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );

  Widget _postsError(
    BuildContext context,
    WidgetRef ref,
    String id,
    Object e,
  ) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _messageOf(e),
            textAlign: TextAlign.center,
            style: _t(12, FontWeight.w400, const Color(0xFF57545F)),
          ),
          TextButton(
            onPressed: () => ref.invalidate(authorPostsProvider(id)),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );

  Widget _signedOut(BuildContext context, WidgetRef ref) => Container(
    key: const Key('social-profile-signed-out'),
    color: const Color(0xFFF7F5FA),
    child: Column(
      children: [
        _topBar(context, true),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 44,
                    color: Color(0xFF57545F),
                  ),
                  const SizedBox(height: 10),
                  Text('Votre profil', style: _t(18, FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Connectez-vous pour voir votre profil et vos publications.',
                    textAlign: TextAlign.center,
                    style: _t(12, FontWeight.w400, const Color(0xFF57545F)),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () =>
                        requireLogin(context, ref, 'voir votre profil'),
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _roundButton(IconData icon, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE9E5EF)),
      ),
      child: Icon(icon, size: 21, color: const Color(0xFF111015)),
    ),
  );

  Widget _pill(Key key, String label, Color bg, Color fg) => Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(label, style: _t(12, FontWeight.w600, fg)),
  );

  Widget _action({
    required Key key,
    required String label,
    required bool filled,
    required VoidCallback? onTap,
  }) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF111015) : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: filled ? null : Border.all(color: const Color(0xFFE1DCEA)),
        ),
        child: Text(
          label,
          style: _t(
            12,
            FontWeight.w600,
            filled ? Colors.white : const Color(0xFF111015),
          ),
        ),
      ),
    ),
  );

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    SocialProfile p,
    bool followed,
  ) async {
    if (!await requireLogin(context, ref, 'suivre une personne') ||
        !context.mounted) {
      return;
    }
    final err = followed
        ? await Backend.cancelEngagement('follow', p.id)
        : await Backend.engage('follow', p.id, const {});
    if (!context.mounted) return;
    if (err != null) {
      return gAlert(context, 'Action impossible', Backend.userMessage(err));
    }
    ref.invalidate(followingIdsProvider);
    ref.invalidate(publicProfileProvider(p.id));
    if (context.mounted) {
      gToast(
        context,
        followed ? 'Vous ne suivez plus ${p.name}' : 'Vous suivez ${p.name}',
      );
    }
  }

  Future<void> _message(
    BuildContext context,
    WidgetRef ref,
    SocialProfile p,
  ) async {
    if (!await requireLogin(context, ref, 'écrire à une personne') ||
        !context.mounted) {
      return;
    }
    final text = await askText(
      context,
      title: 'Écrire à ${p.name}',
      body: 'Votre message ouvre une conversation directe.',
      hint: 'Bonjour…',
      ok: 'Envoyer',
      min: 1,
    );
    if (text == null || !context.mounted) return;
    final r = await Backend.startDirectConversation(p.id, text.trim());
    if (!context.mounted) return;
    if (r.error != null) return gAlert(context, 'Message non envoyé', r.error!);
    ref.read(selectedConversationProvider.notifier).set(r.id!);
    await ref.read(conversationsProvider.notifier).refresh();
    if (context.mounted) gOpen(context, '53');
  }
}

TextStyle _t(
  double size,
  FontWeight weight, [
  Color color = const Color(0xFF111015),
]) => TextStyle(
  inherit: false,
  fontFamily: 'PlusJakartaSans',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: 1.2,
);

String _initials(String name) {
  final p = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (p.isEmpty) return '?';
  return '${p.first.characters.first}${p.length > 1 ? p.last.characters.first : ''}'
      .toUpperCase();
}

String _messageOf(Object e) => e is Exception
    ? e.toString().replaceFirst('Exception: ', '')
    : 'Le profil ne peut pas être chargé pour le moment.';
