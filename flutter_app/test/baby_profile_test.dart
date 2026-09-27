import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/models/baby_profile.dart';

void main() {
  group('ageString', () {
    test('days old for under a month', () {
      final p = BabyProfile(birthDate: DateTime(2026, 9, 20));
      expect(p.ageString(now: DateTime(2026, 9, 27)), '7 days old');
    });

    test('singular day', () {
      final p = BabyProfile(birthDate: DateTime(2026, 9, 26));
      expect(p.ageString(now: DateTime(2026, 9, 27)), '1 day old');
    });

    test('months old under two years', () {
      final p = BabyProfile(birthDate: DateTime(2025, 11, 12));
      expect(p.ageString(now: DateTime(2026, 9, 27)), '10 months old');
    });

    test('singular month', () {
      final p = BabyProfile(birthDate: DateTime(2026, 8, 27));
      expect(p.ageString(now: DateTime(2026, 9, 27)), '1 month old');
    });

    test('years and months', () {
      final p = BabyProfile(birthDate: DateTime(2024, 7, 27));
      expect(p.ageString(now: DateTime(2026, 9, 27)), '2 years 2 months old');
    });

    test('exact years', () {
      final p = BabyProfile(birthDate: DateTime(2024, 9, 27));
      expect(p.ageString(now: DateTime(2026, 9, 27)), '2 years old');
    });

    test('empty when no birth date', () {
      expect(const BabyProfile().ageString(), '');
    });

    test('adjusts when day-of-month not yet reached', () {
      final p = BabyProfile(birthDate: DateTime(2025, 11, 28));
      // Sep 27: 10 full months, not 11.
      expect(p.ageString(now: DateTime(2026, 9, 27)), '9 months old');
    });
  });

  group('JSON', () {
    test('round-trip preserves fields', () {
      const p = BabyProfile(
        name: 'Miya',
        birthDate: null,
        metricUnits: false,
      );
      final restored =
          BabyProfile.fromJson(Map<String, dynamic>.from(p.toJson()));
      expect(restored.name, 'Miya');
      expect(restored.birthDate, isNull);
      expect(restored.metricUnits, isFalse);
    });

    test('defaults when keys missing', () {
      final restored = BabyProfile.fromJson({});
      expect(restored.name, 'Miya');
      expect(restored.metricUnits, isTrue);
    });

    test('copyWith replaces provided fields', () {
      const p = BabyProfile(name: 'Miya');
      final c = p.copyWith(name: 'Boo', metricUnits: false);
      expect(c.name, 'Boo');
      expect(c.metricUnits, isFalse);
      expect(c.birthDate, isNull);
    });
  });
}
