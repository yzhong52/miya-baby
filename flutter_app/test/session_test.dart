import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/data/family_service.dart';
import 'package:miya_baby/screens/auth_gate.dart';
import 'package:miya_baby/services/auth_service.dart';
import 'package:miya_baby/state/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const alice = AppUser(uid: 'alice', email: 'alice@example.com');

void main() {
  late FakeAuthService auth;
  late FakeFirebaseFirestore db;
  late FamilyService families;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    auth = FakeAuthService();
    db = FakeFirebaseFirestore();
    families = FamilyService(db);
  });

  List<Override> overrides() => [
        authServiceProvider.overrideWithValue(auth),
        familyServiceProvider.overrideWithValue(families),
        preferencesProvider.overrideWithValue(prefs),
      ];

  ProviderContainer container() {
    final c = ProviderContainer(overrides: overrides());
    addTearDown(c.dispose);
    // Keep the providers alive the way a watching widget would.
    c.listen(familyIdProvider, (_, __) {});
    return c;
  }

  group('FamilyIdNotifier', () {
    test('is null while signed out', () async {
      final c = container();
      await pumpEventQueue();
      expect(c.read(familyIdProvider), const AsyncData<String?>(null));
    });

    test('uses the family id saved on this device', () async {
      await prefs.setString('familyId.alice', 'saved');
      auth.setUser(alice);
      final c = container();
      await pumpEventQueue();
      expect(c.read(familyIdProvider).value, 'saved');
    });

    test('finds and saves the family on a new device', () async {
      final id = families.createFamily('alice');
      await pumpEventQueue();
      auth.setUser(alice);
      final c = container();
      await pumpEventQueue();
      expect(c.read(familyIdProvider).value, id);
      expect(prefs.getString('familyId.alice'), id);
    });

    test('create starts a family and saves its id', () async {
      auth.setUser(alice);
      final c = container();
      await pumpEventQueue();
      expect(c.read(familyIdProvider).value, isNull);

      await c.read(familyIdProvider.notifier).create();
      final id = c.read(familyIdProvider).value;
      expect(id, isNotNull);
      expect(prefs.getString('familyId.alice'), id);
    });

    test('join adds the user and saves the family id', () async {
      final id = families.createFamily('carol');
      final code = families.createInvite(id, 'carol').code;
      await pumpEventQueue();
      auth.setUser(alice);
      final c = container();
      await pumpEventQueue();

      await c.read(familyIdProvider.notifier).join(code);
      expect(c.read(familyIdProvider).value, id);
      expect(prefs.getString('familyId.alice'), id);
    });

    test('signing out clears the family; signing back in restores it',
        () async {
      await prefs.setString('familyId.alice', 'saved');
      auth.setUser(alice);
      final c = container();
      await pumpEventQueue();
      expect(c.read(familyIdProvider).value, 'saved');

      auth.setUser(null);
      await pumpEventQueue();
      expect(c.read(familyIdProvider).value, isNull);

      auth.setUser(alice);
      await pumpEventQueue();
      expect(c.read(familyIdProvider).value, 'saved');
    });
  });

  group('AuthGate', () {
    Widget app() => ProviderScope(
          overrides: overrides(),
          child: const MaterialApp(
            home: AuthGate(child: Text('HOME')),
          ),
        );

    testWidgets('signed out: shows sign-in, and signing in moves on',
        (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(auth.signIns, 1);
      expect(find.text('Set up your family'), findsOneWidget);
    });

    testWidgets('no family: starting one shows the app', (tester) async {
      auth.setUser(alice);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Set up your family'), findsOneWidget);

      await tester.tap(find.text('Start a new family'));
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('a bad invite code shows why', (tester) async {
      auth.setUser(alice);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ABCDEFGH');
      await tester.tap(find.text('Join family'));
      await tester.pumpAndSettle();
      expect(find.text("That code doesn't match any family."), findsOneWidget);
      expect(find.text('HOME'), findsNothing);
    });

    testWidgets('with a saved family, goes straight to the app',
        (tester) async {
      await prefs.setString('familyId.alice', 'saved');
      auth.setUser(alice);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });
  });
}
