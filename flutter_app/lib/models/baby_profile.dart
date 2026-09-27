/// Baby profile model.
library;

class BabyProfile {
  final String name;
  final DateTime? birthDate;
  final String? photoPath;
  final bool metricUnits;

  const BabyProfile({
    this.name = 'Anya',
    this.birthDate,
    this.photoPath,
    this.metricUnits = true,
  });

  /// Age as a friendly string, e.g. "10 months", "1 year 2 months".
  String ageString({DateTime? now}) {
    if (birthDate == null) return '';
    final ref = now ?? DateTime.now();
    var months =
        (ref.year - birthDate!.year) * 12 + ref.month - birthDate!.month;
    if (ref.day < birthDate!.day) months -= 1;
    if (months < 0) return '';
    if (months < 1) {
      final days = ref.difference(birthDate!).inDays;
      return '$days day${days == 1 ? '' : 's'} old';
    }
    if (months < 24) return '$months month${months == 1 ? '' : 's'} old';
    final years = months ~/ 12;
    final rem = months % 12;
    return rem == 0
        ? '$years year${years == 1 ? '' : 's'} old'
        : '$years year${years == 1 ? '' : 's'} $rem month${rem == 1 ? '' : 's'} old';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'birthDate': birthDate?.toIso8601String(),
        'photoPath': photoPath,
        'metricUnits': metricUnits,
      };

  factory BabyProfile.fromJson(Map<String, dynamic> json) => BabyProfile(
        name: json['name'] as String? ?? 'Anya',
        birthDate: json['birthDate'] != null
            ? DateTime.tryParse(json['birthDate'] as String)
            : null,
        photoPath: json['photoPath'] as String?,
        metricUnits: json['metricUnits'] as bool? ?? true,
      );

  BabyProfile copyWith({
    String? name,
    DateTime? birthDate,
    String? photoPath,
    bool? metricUnits,
  }) =>
      BabyProfile(
        name: name ?? this.name,
        birthDate: birthDate ?? this.birthDate,
        photoPath: photoPath ?? this.photoPath,
        metricUnits: metricUnits ?? this.metricUnits,
      );
}
