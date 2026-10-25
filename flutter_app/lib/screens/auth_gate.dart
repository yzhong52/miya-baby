/// Sign-in and family onboarding, shown in front of the app when
/// `kFirebaseSync` is on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/family_service.dart';
import '../state/session.dart';

/// Shows [child] once the user is signed in and has a family; otherwise
/// the sign-in or family setup screen.
class AuthGate extends ConsumerWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return user.when(
      loading: () => const _Loading(),
      error: (e, _) => _Problem(
        message: "Couldn't check who's signed in.",
        onRetry: () => ref.invalidate(currentUserProvider),
      ),
      data: (user) {
        if (user == null) return const SignInScreen();
        final family = ref.watch(familyIdProvider);
        return family.when(
          loading: () => const _Loading(),
          error: (e, _) => _Problem(
            message: "Couldn't find your family. Check your connection.",
            onRetry: () => ref.read(familyIdProvider.notifier).load(),
          ),
          data: (familyId) =>
              familyId == null ? const FamilySetupScreen() : child,
        );
      },
    );
  }
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = "Couldn't sign in. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset('assets/icon/app_icon.png', width: 120),
                ),
                const SizedBox(height: 24),
                Text('Miya Baby', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Track feeds, diapers and sleep together.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Continue with Google'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Create a family, or join one with an invite code.
class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(FamilyIdNotifier) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(ref.read(familyIdProvider.notifier));
    } on JoinException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your family'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authServiceProvider).signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (user?.email != null)
            Text('Signed in as ${user!.email}',
                style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('New here?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text("Start a family, then share its invite code so others can "
              'log with you.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : () => _run((n) => n.create()),
            child: const Text('Start a new family'),
          ),
          const SizedBox(height: 32),
          Text('Have an invite code?', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _code,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              hintText: 'e.g. K7QM2XPA',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _join(),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _join,
            child: const Text('Join family'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  void _join() => _run((n) => n.join(_code.text));
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Problem extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Problem({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
}
