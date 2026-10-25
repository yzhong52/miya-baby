/// Who is signed in, and which family they share data with.
///
/// Like the providers in `providers.dart`, the base providers here are
/// overridden in main() (only when `kFirebaseSync` is on).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/family_service.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  throw UnimplementedError('authServiceProvider must be overridden');
});

final familyServiceProvider = Provider<FamilyService>((ref) {
  throw UnimplementedError('familyServiceProvider must be overridden');
});

final preferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('preferencesProvider must be overridden');
});

/// The signed-in parent, or null when signed out.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authServiceProvider).userChanges();
});

/// The signed-in user's family id: loading while it's looked up, then null
/// until they create or join one.
///
/// The id is saved on this device per user, so later launches (offline
/// ones too) don't need the server. On a new device it is looked up from
/// the family's member list.
class FamilyIdNotifier extends StateNotifier<AsyncValue<String?>> {
  final String? _uid;
  final FamilyService _families;
  final SharedPreferences _prefs;

  FamilyIdNotifier(this._uid, this._families, this._prefs)
      : super(const AsyncLoading()) {
    load();
  }

  String get _key => 'familyId.$_uid';

  /// Look the family up again, e.g. to retry after an error.
  Future<void> load() async {
    final uid = _uid;
    if (uid == null) {
      state = const AsyncData(null);
      return;
    }
    final saved = _prefs.getString(_key);
    if (saved != null) {
      state = AsyncData(saved);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final found = await _families.findFamilyFor(uid);
      if (found != null) await _prefs.setString(_key, found);
      return found;
    });
  }

  /// Start a new family with this user as its only member.
  Future<void> create() async {
    await _set(_families.createFamily(_requireUid()));
  }

  /// Join the family [code] invites to. Throws [JoinException] with a
  /// message for the user when the code is wrong or expired.
  Future<void> join(String code) async {
    await _set(await _families.join(_requireUid(), code));
  }

  Future<void> _set(String familyId) async {
    await _prefs.setString(_key, familyId);
    state = AsyncData(familyId);
  }

  String _requireUid() {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }
}

final familyIdProvider =
    StateNotifierProvider<FamilyIdNotifier, AsyncValue<String?>>((ref) {
  return FamilyIdNotifier(
    ref.watch(currentUserProvider.select((u) => u.valueOrNull?.uid)),
    ref.watch(familyServiceProvider),
    ref.watch(preferencesProvider),
  );
});
