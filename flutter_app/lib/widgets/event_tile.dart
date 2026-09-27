/// Reusable tile rendering one logged event in timelines / history.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/activity_event.dart';

class EventTile extends StatelessWidget {
  final ActivityEvent event;
  final bool metric;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const EventTile({
    super.key,
    required this.event,
    required this.metric,
    this.onDelete,
    this.onTap,
  });

  IconData get _icon => switch (event.type) {
        EventType.feeding => switch (
            FeedKindX.fromName(event.data['feedKind'] as String? ?? 'nursing')) {
              FeedKind.nursing => Icons.child_care,
              FeedKind.bottle => Icons.local_drink,
              FeedKind.solids => Icons.restaurant,
            },
        EventType.diaper => Icons.baby_changing_station,
        EventType.sleep => Icons.bedtime,
        EventType.growth => Icons.straighten,
        EventType.note => Icons.note,
      };

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(event.startTime);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_icon, size: 20)),
        title: Text(event.summary(metric: metric)),
        subtitle: event.note != null && event.note!.trim().isNotEmpty
            ? Text(event.note!.trim(),
                maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(time, style: Theme.of(context).textTheme.bodySmall),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Delete entry?'),
                      content:
                          Text('Delete "${event.summary(metric: metric)}"?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true) onDelete!();
                },
              ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
