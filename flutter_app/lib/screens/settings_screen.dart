/// Settings screen: baby profile, units, data export.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final profileNotifier = ref.read(profileProvider.notifier);
    final repo = ref.read(repositoryProvider);

    Future<void> editName() async {
      final controller = TextEditingController(text: profile.name);
      final name = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Baby\'s name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (_) =>
                Navigator.pop(c, controller.text.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () =>
                    Navigator.pop(c, controller.text.trim()),
                child: const Text('Save')),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) {
        await profileNotifier.update(profile.copyWith(name: name));
      }
    }

    Future<void> editBirthDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: profile.birthDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
      if (picked != null) {
        await profileNotifier.update(profile.copyWith(birthDate: picked));
      }
    }

    Future<void> exportData() async {
      final json = repo.exportJson(profile);
      final text =
          const JsonEncoder.withIndent('  ').convert(json);
      await Share.share(text, subject: 'Anya Baby export');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Baby', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.child_care_outlined),
                  title: const Text('Name'),
                  trailing: Text(profile.name),
                  onTap: editName,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: const Text('Birth date'),
                  trailing: Text(profile.birthDate != null
                      ? '${profile.birthDate!.year}-${profile.birthDate!.month.toString().padLeft(2, '0')}-${profile.birthDate!.day.toString().padLeft(2, '0')}'
                      : 'Not set'),
                  onTap: editBirthDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Preferences',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.straighten_outlined),
              title: const Text('Metric units'),
              subtitle:
                  const Text('Off = imperial (oz, lb, in)'),
              value: profile.metricUnits,
              onChanged: (v) async =>
                  profileNotifier.update(profile.copyWith(metricUnits: v)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Data', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Export data (JSON)'),
              subtitle:
                  const Text('Share a backup of all logged events'),
              onTap: exportData,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Anya Baby v0.1.0 · data stays on this device',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
