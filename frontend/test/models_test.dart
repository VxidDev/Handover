import 'package:flutter_test/flutter_test.dart';

import 'package:handover/models/help_request.dart';
import 'package:handover/models/neighbor_skill.dart';
import 'package:handover/models/skill.dart';
import 'package:handover/models/user_profile.dart';

void main() {
  group('Skill.fromJson', () {
    test('parses a skill', () {
      final skill = Skill.fromJson({
        'id': 1,
        'name': 'Plumbing',
        'blurb': 'Fixes',
      });

      expect(skill.id, 1);
      expect(skill.name, 'Plumbing');
      expect(skill.blurb, 'Fixes');
    });

    test('defaults a missing blurb to an empty string', () {
      final skill = Skill.fromJson({'id': 2, 'name': 'Cooking'});

      expect(skill.blurb, '');
    });
  });

  group('UserProfile.fromJson', () {
    test('parses a full profile', () {
      final profile = UserProfile.fromJson({
        'id': 7,
        'email': 'sam@example.com',
        'name': 'Sam',
        'is_available': true,
        'karma': 4,
        'grid': 'D4',
        'phone': '555-0100',
        'created_at': '2026-08-18T12:00:00Z',
        'skills': [
          {'id': 1, 'name': 'Plumbing', 'blurb': 'Fixes'},
          {'id': 2, 'name': 'Cooking', 'blurb': ''},
        ],
      });

      expect(profile.id, 7);
      expect(profile.email, 'sam@example.com');
      expect(profile.name, 'Sam');
      expect(profile.isAvailable, isTrue);
      expect(profile.karma, 4);
      expect(profile.grid, 'D4');
      expect(profile.phone, '555-0100');
      expect(profile.createdAt.isUtc, isTrue);
      expect(profile.skills, hasLength(2));
      expect(profile.skills.first.name, 'Plumbing');
    });

    test('applies defaults for optional fields', () {
      final profile = UserProfile.fromJson({
        'id': 8,
        'email': 'a@example.com',
        'name': 'A',
        'created_at': '2026-08-18T12:00:00Z',
      });

      expect(profile.isAvailable, isTrue);
      expect(profile.karma, 0);
      expect(profile.grid, isNull);
      expect(profile.phone, isNull);
      expect(profile.skills, isEmpty);
    });
  });

  group('HelpRequest.fromJson', () {
    test('parses a request', () {
      final request = HelpRequest.fromJson({
        'id': 11,
        'status': 'pending',
        'requester_id': 1,
        'requester_name': 'Sam',
        'provider_id': 2,
        'provider_name': 'Maya',
        'skill_name': 'Plumbing',
        'message': 'Sink is dripping',
        'created_at': '2026-08-18T12:00:00Z',
      });

      expect(request.id, 11);
      expect(request.status, 'pending');
      expect(request.requesterId, 1);
      expect(request.requesterName, 'Sam');
      expect(request.providerId, 2);
      expect(request.providerName, 'Maya');
      expect(request.skillName, 'Plumbing');
      expect(request.message, 'Sink is dripping');
      expect(request.createdAt, isNotNull);
    });

    test('handles missing optional fields', () {
      final request = HelpRequest.fromJson({
        'id': 12,
        'status': 'cancelled',
        'requester_id': 1,
        'requester_name': 'Sam',
        'provider_id': 2,
        'provider_name': 'Maya',
        'skill_name': 'Cooking',
      });

      expect(request.message, isNull);
      expect(request.createdAt, isNull);
    });
  });

  group('NeighborSkill.fromSearchResult', () {
    test('parses a search result', () {
      final skill = NeighborSkill.fromSearchResult({
        'skill_id': 5,
        'owner_id': 3,
        'skill_name': 'Bread baking',
        'blurb': 'Sourdough',
        'owner_name': 'Priya',
        'distance_km': 1.2,
        'grid': 'D5',
        'available': false,
        'karma': 9,
        'images': ['/uploads/a.png'],
      });

      expect(skill.skillId, 5);
      expect(skill.ownerId, 3);
      expect(skill.skill, 'Bread baking');
      expect(skill.name, 'Priya');
      expect(skill.km, 1.2);
      expect(skill.grid, 'D5');
      expect(skill.available, isFalse);
      expect(skill.karma, 9);
      expect(skill.images, ['/uploads/a.png']);
      expect(skill.initial, 'P');
    });

    test('applies defaults for optional fields', () {
      final skill = NeighborSkill.fromSearchResult({
        'owner_id': 4,
        'skill_name': 'Yoga',
        'owner_name': '',
      });

      expect(skill.skillId, isNull);
      expect(skill.blurb, '');
      expect(skill.km, isNull);
      expect(skill.grid, isNull);
      expect(skill.available, isTrue);
      expect(skill.karma, 0);
      expect(skill.images, isEmpty);
      expect(skill.initial, '?');
    });
  });
}
