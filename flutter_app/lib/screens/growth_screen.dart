/// Growth screen: log weight/height/head + simple trend chart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity_event.dart';
import '../state/providers.dart';
import '../widgets/log_sheets.dart';

class GrowthScreen extends ConsumerWidget {
  const GrowthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    final profile = ref.watch(profileProvider);
    final notifier = ref.read(eventsProvider.notifier);

    final growth = events.where((e) => e.type == EventType.growth).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    return Scaffold(
      appBar: AppBar(title: const Text('Growth')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final data =
              await showGrowthSheet(context, metric: profile.metricUnits);
          if (data != null && data.isNotEmpty && context.mounted) {
            await notifier.logInstant(type: EventType.growth, data: data);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Log'),
      ),
      body: growth.isEmpty
          ? const Center(
              child: Text('No growth entries yet.\nTap Log to add one.',
                  textAlign: TextAlign.center))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _TrendCard(
                  title: profile.metricUnits ? 'Weight (kg)' : 'Weight (lb)',
                  points: [
                    for (final e in growth)
                      if (e.data['weightKg'] != null)
                        _Point(
                            e.startTime,
                            profile.metricUnits
                                ? (e.data['weightKg'] as num).toDouble()
                                : (e.data['weightKg'] as num).toDouble() *
                                    2.20462)
                  ],
                ),
                _TrendCard(
                  title: profile.metricUnits ? 'Height (cm)' : 'Height (in)',
                  points: [
                    for (final e in growth)
                      if (e.data['heightCm'] != null)
                        _Point(
                            e.startTime,
                            profile.metricUnits
                                ? (e.data['heightCm'] as num).toDouble()
                                : (e.data['heightCm'] as num).toDouble() / 2.54)
                  ],
                ),
                const SizedBox(height: 8),
                Text('Entries', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final e in growth.reversed)
                  Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                          child: Icon(Icons.straighten, size: 20)),
                      title: Text(e.summary(metric: profile.metricUnits)),
                      subtitle: Text(DateFormat.yMMMd().format(e.startTime)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => notifier.remove(e.id),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Point {
  final DateTime time;
  final double value;
  const _Point(this.time, this.value);
}

class _TrendCard extends StatelessWidget {
  final String title;
  final List<_Point> points;

  const _TrendCard({required this.title, required this.points});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: points.length < 2
                  ? Center(
                      child: Text(
                          points.isEmpty
                              ? 'No data'
                              : 'Log one more to see the trend',
                          style: Theme.of(context).textTheme.bodySmall))
                  : CustomPaint(
                      painter: _LinePainter(
                          points, Theme.of(context).colorScheme.primary),
                      size: Size.infinite,
                    ),
            ),
            if (points.isNotEmpty)
              Text(
                'Latest: ${points.last.value.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<_Point> points;
  final Color color;

  _LinePainter(this.points, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final values = points.map((p) => p.value).toList();
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final span = (maxV - minV) == 0 ? 1.0 : (maxV - minV);

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()..color = color;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height -
          ((points[i].value - minV) / span) * (size.height - 16) -
          8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.points != points || old.color != color;
}
