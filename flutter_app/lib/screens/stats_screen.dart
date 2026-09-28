/// Stats screen: last 7 days of feeds, sleep, and diapers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../services/stats.dart';
import '../state/providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final profile = ref.watch(profileProvider);

    final stats = computeDayStats(events);
    final days = stats.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(
            title: 'Feedings per day',
            days: days,
            values: days.map((d) => stats[d]!.feeds.toDouble()).toList(),
            format: (v) => v.toStringAsFixed(0),
          ),
          _StatCard(
            title: profile.metricUnits
                ? 'Bottle volume per day (ml)'
                : 'Bottle volume per day (oz)',
            days: days,
            values: days
                .map((d) => profile.metricUnits
                    ? stats[d]!.bottleMl
                    : stats[d]!.bottleMl / 29.5735)
                .toList(),
            format: (v) => v.toStringAsFixed(0),
          ),
          _StatCard(
            title: 'Sleep per day (hours)',
            days: days,
            values: days.map((d) => stats[d]!.sleepMin / 60.0).toList(),
            format: (v) => v.toStringAsFixed(1),
          ),
          _StatCard(
            title: 'Diapers per day',
            days: days,
            values: days.map((d) => stats[d]!.diapers.toDouble()).toList(),
            format: (v) => v.toStringAsFixed(0),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final List<DateTime> days;
  final List<double> values;
  final String Function(double) format;

  const _StatCard({
    required this.title,
    required this.days,
    required this.values,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    // Bars are normalized against the week's max so the tallest day fills
    // the card; the floor keeps zero/low days as a visible sliver.
    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(format(values[i]),
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 2),
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: maxV > 0
                                      ? (values[i] / maxV).clamp(0.04, 1.0)
                                      : 0.04,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(DateFormat.E().format(days[i]),
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
