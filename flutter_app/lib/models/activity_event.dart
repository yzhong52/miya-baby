/// Core event model for Anya Baby.
///
/// Every logged activity (feeding, diaper, sleep, growth, note) is an
/// [ActivityEvent]. Type-specific details live in [data] so the storage
/// layer can stay a simple JSON map.
library;

enum EventType { feeding, diaper, sleep, growth, note }

extension EventTypeX on EventType {
  String get label => switch (this) {
        EventType.feeding => 'Feeding',
        EventType.diaper => 'Diaper',
        EventType.sleep => 'Sleep',
        EventType.growth => 'Growth',
        EventType.note => 'Note',
      };

  static EventType fromName(String name) =>
      EventType.values.firstWhere((e) => e.name == name);
}

/// Feeding sub-types.
enum FeedKind { nursing, bottle, solids }

extension FeedKindX on FeedKind {
  String get label => switch (this) {
        FeedKind.nursing => 'Nursing',
        FeedKind.bottle => 'Bottle',
        FeedKind.solids => 'Solids',
      };

  static FeedKind fromName(String name) =>
      FeedKind.values.firstWhere((e) => e.name == name);
}

enum DiaperKind { wet, dirty, mixed }

extension DiaperKindX on DiaperKind {
  String get label => switch (this) {
        DiaperKind.wet => 'Wet',
        DiaperKind.dirty => 'Dirty',
        DiaperKind.mixed => 'Mixed',
      };

  static DiaperKind fromName(String name) =>
      DiaperKind.values.firstWhere((e) => e.name == name);
}

class ActivityEvent {
  final String id;
  final EventType type;
  final DateTime startTime;
  final DateTime? endTime;
  final Map<String, dynamic> data;
  final String? note;
  final DateTime createdAt;

  const ActivityEvent({
    required this.id,
    required this.type,
    required this.startTime,
    this.endTime,
    this.data = const {},
    this.note,
    required this.createdAt,
  });

  /// An event with an endTime in the future (or null endTime + [isActive])
  /// represents a running timer (nursing / sleep).
  bool get isActive => endTime == null && data['active'] == true;

  Duration? get duration =>
      endTime != null ? endTime!.difference(startTime) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime?.toIso8601String(),
        'data': data,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        id: json['id'] as String,
        type: EventTypeX.fromName(json['type'] as String),
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
        data: Map<String, dynamic>.from(json['data'] as Map? ?? {}),
        note: json['note'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  ActivityEvent copyWith({
    String? id,
    EventType? type,
    DateTime? startTime,
    DateTime? endTime,
    Map<String, dynamic>? data,
    String? note,
    DateTime? createdAt,
  }) =>
      ActivityEvent(
        id: id ?? this.id,
        type: type ?? this.type,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        data: data ?? this.data,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Human-readable one-line summary, e.g. "Nursing · Left · 12 min".
  String summary({bool metric = true}) {
    switch (type) {
      case EventType.feeding:
        final kind =
            FeedKindX.fromName(data['feedKind'] as String? ?? 'nursing');
        switch (kind) {
          case FeedKind.nursing:
            final side = (data['side'] as String? ?? 'left');
            final mins = duration != null ? '${duration!.inMinutes} min' : '…';
            return 'Nursing · ${side[0].toUpperCase()}${side.substring(1)} · $mins';
          case FeedKind.bottle:
            final ml = (data['amountMl'] as num?)?.toDouble() ?? 0;
            final amt = metric
                ? '${ml.toStringAsFixed(0)} ml'
                : '${(ml / 29.5735).toStringAsFixed(1)} oz';
            return 'Bottle · $amt';
          case FeedKind.solids:
            final food = (data['food'] as String?)?.trim();
            return food == null || food.isEmpty
                ? 'Solids'
                : 'Solids · $food';
        }
      case EventType.diaper:
        final kind =
            DiaperKindX.fromName(data['diaperKind'] as String? ?? 'wet');
        return 'Diaper · ${kind.label}';
      case EventType.sleep:
        final mins = duration != null ? '${duration!.inMinutes} min' : 'ongoing';
        return 'Sleep · $mins';
      case EventType.growth:
        final parts = <String>[];
        final w = (data['weightKg'] as num?)?.toDouble();
        final h = (data['heightCm'] as num?)?.toDouble();
        final hc = (data['headCm'] as num?)?.toDouble();
        if (w != null) {
          parts.add(metric
              ? '${w.toStringAsFixed(2)} kg'
              : '${(w * 2.20462).toStringAsFixed(1)} lb');
        }
        if (h != null) {
          parts.add(metric
              ? '${h.toStringAsFixed(1)} cm'
              : '${(h / 2.54).toStringAsFixed(1)} in');
        }
        if (hc != null) {
          parts.add(metric
              ? 'head ${hc.toStringAsFixed(1)} cm'
              : 'head ${(hc / 2.54).toStringAsFixed(1)} in');
        }
        return parts.isEmpty ? 'Growth' : 'Growth · ${parts.join(' · ')}';
      case EventType.note:
        final n = (note ?? '').trim();
        return n.isEmpty ? 'Note' : n;
    }
  }
}
