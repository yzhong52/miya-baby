/// Families and invite codes in Firestore.
///
/// A family is the unit of sharing: its members all see the same events.
/// Data model and security rules: `firestore.rules`.
///
///   families/{familyId}             members: [uid], createdBy, createdAt
///   families/{familyId}/meta/invite code, expiresAt (the current code)
///   inviteCodes/{code}              familyId, createdBy, expiresAt
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'background_write.dart';

class InviteCode {
  final String code;
  final DateTime expiresAt;

  const InviteCode(this.code, this.expiresAt);
}

/// Why a join failed, worded for the user.
class JoinException implements Exception {
  final String message;
  const JoinException(this.message);

  @override
  String toString() => 'JoinException: $message';
}

class FamilyService {
  final FirebaseFirestore _db;
  final DateTime Function() _now;
  final Random _random;

  FamilyService(
    this._db, {
    DateTime Function()? now,
    Random? random,
  })  : _now = now ?? DateTime.now,
        _random = random ?? Random.secure();

  static const inviteLifetime = Duration(days: 7);
  static const codeLength = 8;

  /// Uppercase letters and digits minus look-alikes (I, L, O, 0, 1), so a
  /// code read aloud or off a screen is typed correctly.
  static const codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  CollectionReference<Map<String, dynamic>> get _families =>
      _db.collection('families');

  DocumentReference<Map<String, dynamic>> _inviteMeta(String familyId) =>
      _families.doc(familyId).collection('meta').doc('invite');

  /// Create a family with [uid] as its only member, plus a first invite
  /// code, and return the family id. Doesn't wait for the server, so it
  /// also works offline.
  String createFamily(String uid) {
    final family = _families.doc();
    backgroundWrite(
      family.set({
        'members': [uid],
        'createdBy': uid,
        'createdAt': Timestamp.fromDate(_now()),
      }),
      'creating family ${family.id}',
    );
    createInvite(family.id, uid);
    return family.id;
  }

  /// A new invite code for [familyId], valid for [inviteLifetime]. It
  /// replaces the family's current code in Settings; older codes keep
  /// working until they expire. Doesn't wait for the server.
  InviteCode createInvite(String familyId, String uid) {
    // 31^8 ≈ 8.5e11 codes, so a collision is vanishingly unlikely; if one
    // happened, the rules reject the write (codes can't be overwritten).
    final code = String.fromCharCodes(List.generate(
      codeLength,
      (_) => codeAlphabet.codeUnitAt(_random.nextInt(codeAlphabet.length)),
    ));
    final expiresAt = Timestamp.fromDate(_now().add(inviteLifetime));
    backgroundWrite(
      _db.collection('inviteCodes').doc(code).set({
        'familyId': familyId,
        'createdBy': uid,
        'expiresAt': expiresAt,
      }),
      'creating invite code',
    );
    backgroundWrite(
      _inviteMeta(familyId).set({'code': code, 'expiresAt': expiresAt}),
      'saving the current invite code',
    );
    return InviteCode(code, expiresAt.toDate());
  }

  /// The family's current invite code, if any, then every change.
  Stream<InviteCode?> watchInvite(String familyId) =>
      _inviteMeta(familyId).snapshots().map((snap) {
        final data = snap.data();
        if (data == null) return null;
        return InviteCode(
          data['code'] as String,
          (data['expiresAt'] as Timestamp).toDate(),
        );
      });

  /// The uids of the family's members, then every change.
  Stream<List<String>> watchMembers(String familyId) =>
      _families.doc(familyId).snapshots().map(
            (snap) =>
                List<String>.from(snap.data()?['members'] as List? ?? const []),
          );

  /// The family [uid] belongs to, if any, e.g. after signing in on a new
  /// phone. With several, the oldest wins.
  Future<String?> findFamilyFor(String uid) async {
    final snap = await _families.where('members', arrayContains: uid).get();
    if (snap.docs.isEmpty) return null;
    final docs = snap.docs.toList()
      ..sort((a, b) => (a.data()['createdAt'] as Timestamp)
          .compareTo(b.data()['createdAt'] as Timestamp));
    return docs.first.id;
  }

  /// Join the family that [code] invites to, and return its id.
  ///
  /// Needs a connection: the code is checked on the server. Throws a
  /// [JoinException] for an unknown or expired code.
  Future<String> join(String uid, String code) async {
    final normalized = normalizeCode(code);
    if (normalized.length != codeLength) {
      throw const JoinException('Invite codes are 8 letters and digits.');
    }

    final DocumentSnapshot<Map<String, dynamic>> invite;
    try {
      invite = await _db
          .collection('inviteCodes')
          .doc(normalized)
          .get(const GetOptions(source: Source.server));
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') {
        throw const JoinException(
            'You need to be online to join a family. Try again.');
      }
      rethrow;
    }
    final data = invite.data();
    if (data == null) {
      throw const JoinException("That code doesn't match any family.");
    }
    if ((data['expiresAt'] as Timestamp).toDate().isBefore(_now())) {
      throw const JoinException(
          'That code has expired. Ask for a new one in Settings.');
    }

    final familyId = data['familyId'] as String;
    final family = _families.doc(familyId);
    if (await _isMember(family, uid)) return familyId;
    // The rules allow exactly this change: our uid appended to members,
    // with the code that let us in.
    await family.update({
      'members': FieldValue.arrayUnion([uid]),
      'joinCode': normalized,
    });
    return familyId;
  }

  /// Whether [uid] already belongs to [family]. Non-members can't read a
  /// family at all, so a permission error means no.
  Future<bool> _isMember(
    DocumentReference<Map<String, dynamic>> family,
    String uid,
  ) async {
    try {
      final snap = await family.get(const GetOptions(source: Source.server));
      return (snap.data()?['members'] as List?)?.contains(uid) ?? false;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// Uppercase, without the spaces and dashes people add when typing.
  static String normalizeCode(String code) =>
      code.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
}
