import 'package:boutik_ecole/figma/live/social_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profil public : champs lus sans donnée privée, compteurs et note', () {
    final p = SocialProfile.fromJson({
      'id': '7ba7711e-b66f-4fd6-8693-14eac6f10e3a',
      'name': 'Brice Recette',
      'role': 'student',
      'city': 'Douala',
      'institution': 'IUT de Douala',
      'department': 'Informatique',
      'bio': 'Je fabrique des kits solaires.',
      'skills': 'soudure, énergie',
      'avatar_url': 'https://example.test/avatar.png',
      'certified': true,
      'posts_count': 2,
      'followers_count': 12,
      'following_count': 3,
      'rating': 4.75,
      'rating_count': 8,
      'phone': '+237600000000',
    });

    expect(p.id, '7ba7711e-b66f-4fd6-8693-14eac6f10e3a');
    expect(p.name, 'Brice Recette');
    expect(p.certified, isTrue);
    expect(p.postsCount, 2);
    expect(p.followersCount, 12);
    expect(p.followingCount, 3);
    expect(p.rating, 4.75);
    expect(p.ratingCount, 8);
    expect(profileSubtitle(p), 'Étudiant · Informatique · IUT de Douala');
  });

  test('profil public : valeurs absentes ou nulles ne sont pas inventées', () {
    final p = SocialProfile.fromJson({
      'id': 'x',
      'certified': false,
      'rating': null,
      'posts_count': null,
    });

    expect(p.name, isEmpty);
    expect(p.bio, isEmpty);
    expect(p.avatarUrl, isEmpty);
    expect(p.certified, isFalse);
    expect(p.postsCount, 0);
    expect(p.rating, 0);
    expect(p.ratingCount, 0);
    expect(profileSubtitle(p), 'Membre de Boutik-École');
    expect(roleLabel('company'), 'Entreprise');
    expect(roleLabel('inconnu'), 'Membre');
  });
}
