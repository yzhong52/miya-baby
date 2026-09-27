/// Home screen: greeting, active timers, quick-log grid, today's timeline.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity_event.dart';
import '../state/providers.dart';
import '../widgets/event_tile.dart';
import '../widgets/log_sheets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final today = DateTime.now();
    final events = ref.watch(eventsForDayProvider(today));
    final notifier = ref.read(eventsProvider.notifier);
    final activeSleep = notifier.activeTimer(EventType.sleep);
    final activeNursing = notifier.activeTimer(EventType.feeding);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${profile.name}\'s Day',
                style: Theme.of(context).textTheme.titleLarge),
            if (profile.ageString().isNotEmpty)
              Text(profile.ageString(),
                  style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (activeSleep != null)
            _TimerCard(
              icon: Icons.bedtime,
              label: 'Sleeping',
              event: activeSleep,
              onStop: () => notifier.stopTimer(EventType.sleep),
            ),
          if (activeNursing != null)
            _TimerCard(
              icon: Icons.child_care,
              label: 'Nursing',
              event: activeNursing,
              onStop: () => notifier.stopTimer(EventType.feeding),
            ),
          Text('Quick log', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _QuickLogGrid(),
          const SizedBox(height: 16),
          Text('Today', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Nothing logged yet today.')),
            )
          else
            ...events.map((e) => EventTile(
                  event: e,
                  metric: profile.metricUnits,
                  onDelete: () => notifier.remove(e.id),
                )),
        ],
      ),
    );
  }
}

class _TimerCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final ActivityEvent event;
  final VoidCallback onStop;

  const _TimerCard({
    required this.icon,
    required this.label,
    required this.event,
    required this.onStop,
  });

  @override
  State<_TimerCard> createState() => _TimerCardState();
}

class _TimerCardState extends State<_TimerCard> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.event.startTime);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final hh = elapsed.inHours;
    final timeStr = hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(widget.icon, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      'Started ${DateFormat.jm().format(widget.event.startTime)} · $timeStr',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            FilledButton(onPressed: widget.onStop, child: const Text('Stop')),
          ],
        ),
      ),
    );
  }
}

class _QuickLogGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(eventsProvider.notifier);
    final profile = ref.watch(profileProvider);

    Future<void> logDiaper() async {
      final kind = await showDiaperSheet(context);
      if (kind != null && context.mounted) {
        await notifier.logInstant(
          type: EventType.diaper,
          data: {'diaperKind': kind.name},
        );
      }
    }

    Future<void> logBottle() async {
      final ml = await showBottleSheet(context, metric: profile.metricUnits);
      if (ml != null && context.mounted) {
        await notifier.logInstant(
          type: EventType.feeding,
          data: {'feedKind': FeedKind.bottle.name, 'amountMl': ml},
        );
      }
    }

    Future<void> logSolids() async {
      final food = await showSolidsSheet(context);
      if (food != null && context.mounted) {
        await notifier.logInstant(
          type: EventType.feeding,
          data: {'feedKind': FeedKind.solids.name, 'food': food},
        );
      }
    }

    Future<void> startNursing() async {
      final side = await showNursingSideSheet(context);
      if (side != null && context.mounted) {
        await notifier.startTimer(
          type: EventType.feeding,
          data: {'feedKind': FeedKind.nursing.name, 'side': side},
        );
      }
    }

    Future<void> toggleSleep() async {
      final active = notifier.activeTimer(EventType.sleep);
      if (active != null) {
        await notifier.stopTimer(EventType.sleep);
      } else {
        await notifier.startTimer(type: EventType.sleep);
      }
    }

    Future<void> logNote() async {
      final text = await showNoteSheet(context);
      if (text != null && text.trim().isNotEmpty && context.mounted) {
        await notifier.logInstant(type: EventType.note, note: text.trim());
      }
    }

    final buttons = [
      _QuickButton(icon: Icons.child_care, label: 'Nurse', onTap: startNursing),
      _QuickButton(
          icon: Icons.local_drink_outlined, label: 'Bottle', onTap: logBottle),
      _QuickButton(
          icon: Icons.restaurant_outlined, label: 'Solids', onTap: logSolids),
      _QuickButton(
          icon: Icons.baby_changing_station_outlined,
          label: 'Diaper',
          onTap: logDiaper),
      _QuickButton(
          icon: Icons.bedtime_outlined, label: 'Sleep', onTap: toggleSleep),
      _QuickButton(
          icon: Icons.note_add_outlined, label: 'Note', onTap: logNote),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.4,
      children: buttons,
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
