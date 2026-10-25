import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/data/family_service.dart';

void main() {
  final now = DateTime(2026, 10, 24, 9);
  late FakeFirebaseFirestore db;
  late FamilyService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = FamilyService(db, now: () => now, random: Random(7));
  });

  Future<Map<String, dynamic>?> read(String path) async =>
      (await db.doc(path).get()).data();

  group('createFamily', () {
    test('writes the family with its creator as the only member', () async {
      final id = service.createFamily('alice');
      await pumpEventQueue();

      final family = await read('families/$id');
      expect(family!['members'], ['alice']);
      expect(family['createdBy'], 'alice');
      expect((family['createdAt'] as Timestamp).toDate(), now);
    });

    test('creates a first invite code, saved on the family too', () async {
      final id = service.createFamily('alice');
      await pumpEventQueue();

      final meta = await read('families/$id/meta/invite');
      final code = meta!['code'] as String;
      final invite = await read('inviteCodes/$code');
      expect(invite!['familyId'], id);
      expect(invite['createdBy'], 'alice');
      expect((invite['expiresAt'] as Timestamp).toDate(),
          now.add(FamilyService.inviteLifetime));
    });
  });

  test('invite codes are 8 characters with no look-alikes', () {
    for (var i = 0; i < 200; i++) {
      final code = service.createInvite('f1', 'alice').code;
      expect(code, hasLength(FamilyService.codeLength));
      expect(code, matches(RegExp(r'^[A-HJKMNP-Z2-9]+$')));
    }
  });

  test('watchInvite follows the current code', () async {
    final id = service.createFamily('alice');
    await pumpEventQueue();
    final first = await service.watchInvite(id).first;
    final second = service.createInvite(id, 'alice');
    await pumpEventQueue();
    final current = await service.watchInvite(id).first;

    expect(first!.code, isNot(second.code));
    expect(current!.code, second.code);
  });

  group('join', () {
    late String familyId;
    late String code;

    setUp(() async {
      familyId = service.createFamily('alice');
      await pumpEventQueue();
      code = (await read('families/$familyId/meta/invite'))!['code'];
    });

    test('adds the user to the family', () async {
      expect(await service.join('bob', code), familyId);
      expect((await read('families/$familyId'))!['members'], ['alice', 'bob']);
      expect((await read('families/$familyId'))!['joinCode'], code);
    });

    test('accepts lowercase codes with spaces or dashes', () async {
      final typed =
          '${code.substring(0, 4).toLowerCase()} - ${code.substring(4)}';
      expect(await service.join('bob', typed), familyId);
    });

    test('more than two members can join', () async {
      await service.join('bob', code);
      await service.join('dan', code);
      expect((await read('families/$familyId'))!['members'],
          ['alice', 'bob', 'dan']);
    });

    test('joining again is a no-op', () async {
      await service.join('bob', code);
      expect(await service.join('bob', code), familyId);
      expect((await read('families/$familyId'))!['members'], ['alice', 'bob']);
    });

    test('rejects unknown, malformed and expired codes', () async {
      await expectLater(
          service.join('bob', 'ABCDEFGH'), throwsA(isA<JoinException>()));
      await expectLater(
          service.join('bob', 'ABC'), throwsA(isA<JoinException>()));

      final later = FamilyService(db,
          now: () => now
              .add(FamilyService.inviteLifetime)
              .add(const Duration(minutes: 1)));
      await expectLater(
          later.join('bob', code),
          throwsA(isA<JoinException>()
              .having((e) => e.message, 'message', contains('expired'))));
      expect((await read('families/$familyId'))!['members'], ['alice']);
    });
  });

  group('findFamilyFor', () {
    test('finds the family a user belongs to', () async {
      final id = service.createFamily('alice');
      await pumpEventQueue();
      expect(await service.findFamilyFor('alice'), id);
      expect(await service.findFamilyFor('bob'), isNull);
    });

    test('picks the oldest when there are several', () async {
      final older =
          FamilyService(db, now: () => now.subtract(const Duration(days: 30)))
              .createFamily('alice');
      service.createFamily('alice');
      await pumpEventQueue();
      expect(await service.findFamilyFor('alice'), older);
    });
  });

  test('watchMembers lists member uids', () async {
    final id = service.createFamily('alice');
    await pumpEventQueue();
    expect(await service.watchMembers(id).first, ['alice']);
  });
}
