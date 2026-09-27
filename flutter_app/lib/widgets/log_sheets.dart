/// Bottom-sheet pickers used by the quick-log buttons.
library;

import 'package:flutter/material.dart';

import '../models/activity_event.dart';

Future<DiaperKind?> showDiaperSheet(BuildContext context) {
  return showModalBottomSheet<DiaperKind>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Diaper',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          for (final kind in DiaperKind.values)
            ListTile(
              leading: Icon(switch (kind) {
                DiaperKind.wet => Icons.water_drop_outlined,
                DiaperKind.dirty => Icons.cloud_outlined,
                DiaperKind.mixed => Icons.invert_colors_outlined,
              }),
              title: Text(kind.label),
              onTap: () => Navigator.pop(c, kind),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<double?> showBottleSheet(BuildContext context,
    {required bool metric}) {
  double amount = metric ? 120 : 118.3; // 120 ml ≈ 4 oz
  return showModalBottomSheet<double>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bottle',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(
                metric
                    ? '${amount.toStringAsFixed(0)} ml'
                    : '${(amount / 29.5735).toStringAsFixed(1)} oz',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Slider(
                min: metric ? 30 : 29.6,
                max: metric ? 300 : 266,
                divisions: 54,
                value: amount.clamp(
                    metric ? 30 : 29.6, metric ? 300 : 266),
                label: metric
                    ? '${amount.toStringAsFixed(0)} ml'
                    : '${(amount / 29.5735).toStringAsFixed(1)} oz',
                onChanged: (v) => setState(() => amount = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(c, amount),
                child: const Text('Log bottle'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<String?> showSolidsSheet(BuildContext context) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Solids',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'What did they eat?',
                hintText: 'e.g. oatmeal + banana',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) =>
                  Navigator.pop(c, controller.text.trim()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(c, controller.text.trim()),
              child: const Text('Log solids'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<String?> showNursingSideSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nursing — which side?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_circle_left_outlined),
            title: const Text('Left'),
            onTap: () => Navigator.pop(c, 'left'),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_circle_right_outlined),
            title: const Text('Right'),
            onTap: () => Navigator.pop(c, 'right'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<String?> showNoteSheet(BuildContext context) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Note',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Anything worth remembering…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(c, controller.text),
              child: const Text('Save note'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<Map<String, double>?> showGrowthSheet(BuildContext context,
    {required bool metric}) {
  final weightCtrl = TextEditingController();
  final heightCtrl = TextEditingController();
  final headCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String? numberValidator(String? v) {
    if (v == null || v.trim().isEmpty) return null; // all fields optional
    return double.tryParse(v.trim()) == null ? 'Enter a number' : null;
  }

  return showModalBottomSheet<Map<String, double>>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(c).viewInsets.bottom + 24,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Log growth',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: weightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: numberValidator,
                decoration: InputDecoration(
                  labelText: metric ? 'Weight (kg)' : 'Weight (lb)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: heightCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: numberValidator,
                decoration: InputDecoration(
                  labelText: metric ? 'Height (cm)' : 'Height (in)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: headCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: numberValidator,
                decoration: InputDecoration(
                  labelText:
                      metric ? 'Head circumference (cm)' : 'Head (in)',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  double? parse(TextEditingController t) =>
                      t.text.trim().isEmpty
                          ? null
                          : double.parse(t.text.trim());
                  var w = parse(weightCtrl);
                  var h = parse(heightCtrl);
                  var hc = parse(headCtrl);
                  if (!metric) {
                    if (w != null) w = w / 2.20462;
                    if (h != null) h = h * 2.54;
                    if (hc != null) hc = hc * 2.54;
                  }
                  Navigator.pop(c, {
                    if (w != null) 'weightKg': w,
                    if (h != null) 'heightCm': h,
                    if (hc != null) 'headCm': hc,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
