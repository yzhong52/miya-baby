/// History screen: all events grouped by day, with delete.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity_event.dart';
import '../state/providers.dart';
import '../widgets/event_tile.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(eventsProvider.notifier);

    final byDay = <DateTime, List<ActivityEvent>>{};
    for (final e in events) {
      final day =
          DateTime(e.startTime.year, e.startTime.month, e.startTime.day);
      byDay.putIfAbsent(day, () => []).add(e);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: days.isEmpty
          ? const Center(child: Text('No entries yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: days.length,
              itemBuilder: (context, i) {
                final day = days[i];
                final label = _dayLabel(day);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Text(label,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ...byDay[day]!.map((e) => EventTile(
                          event: e,
                          metric: profile.metricUnits,
                          onDelete: () => notifier.remove(e.id),
                        )),
                  ],
                );
              },
            ),
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return DateFormat.yMMMd().format(day);
  }
}
