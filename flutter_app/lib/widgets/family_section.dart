/// Settings section for the shared family: members, invite code, sign out.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../data/family_service.dart';
import '../state/session.dart';

final _membersProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).watchMembers(familyId);
});

final _inviteProvider =
    StreamProvider.autoDispose.family<InviteCode?, String>((ref, familyId) {
  return ref.watch(familyServiceProvider).watchInvite(familyId);
});

class FamilySection extends ConsumerWidget {
  const FamilySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final familyId = ref.watch(familyIdProvider).valueOrNull;
    if (user == null || familyId == null) return const SizedBox.shrink();

    final members = ref.watch(_membersProvider(familyId)).valueOrNull;
    final invite = ref.watch(_inviteProvider(familyId)).valueOrNull;
    final expired = invite == null || invite.expiresAt.isBefore(DateTime.now());

    void newCode() =>
        ref.read(familyServiceProvider).createInvite(familyId, user.uid);

    Future<void> share(InviteCode invite) => Share.share(
          'Join our family on Miya Baby with invite code ${invite.code} '
          '(valid until ${_date(invite.expiresAt)}).',
          subject: 'Miya Baby invite',
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Family', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('Members'),
                trailing: Text(members == null ? '…' : '${members.length}'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text(expired ? 'No active invite code' : invite.code),
                subtitle: Text(expired
                    ? 'Create one so another parent can join'
                    : 'Valid until ${_date(invite.expiresAt)}'),
                trailing: expired
                    ? null
                    : IconButton(
                        tooltip: 'Share invite code',
                        icon: const Icon(Icons.ios_share_outlined),
                        onPressed: () => share(invite),
                      ),
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('New invite code'),
                onTap: newCode,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                subtitle: Text(user.email ?? ''),
                onTap: () => ref.read(authServiceProvider).signOut(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
