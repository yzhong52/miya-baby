import 'package:flutter_test/flutter_test.dart';
import 'package:miya_baby/screens/home_screen.dart';

void main() {
  group('formatElapsed', () {
    test('under an hour shows mm:ss', () {
      expect(formatElapsed(Duration.zero), '00:00');
      expect(formatElapsed(const Duration(minutes: 5, seconds: 7)), '05:07');
      expect(formatElapsed(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('past an hour wraps minutes within the hour', () {
      expect(formatElapsed(const Duration(hours: 1)), '1:00:00');
      expect(
        formatElapsed(const Duration(hours: 1, minutes: 15, seconds: 12)),
        '1:15:12',
      );
      expect(
        formatElapsed(const Duration(hours: 10, minutes: 3, seconds: 9)),
        '10:03:09',
      );
    });
  });
}
