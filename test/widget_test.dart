import 'package:flutter_test/flutter_test.dart';
import 'package:bead_tracker/models/user_settings.dart';
import 'package:bead_tracker/models/daily_entry.dart';

void main() {
  group('Bead Tracker Model Unit Tests', () {
    test('UserSettings default values should match specification', () {
      final settings = UserSettings();
      expect(settings.dailyGoal, equals(216));
      expect(settings.monthlyGoal, equals(5400));
      expect(settings.totalGoal, equals(150000));
      expect(settings.totalOffset, equals(0));
      expect(settings.isDarkMode, isTrue);
    });

    test('DailyEntry totalCount should correctly sum all session counts', () {
      final entry = DailyEntry()..date = DateTime.now();
      expect(entry.totalCount, equals(0));
      expect(entry.totalMalaCount, equals(0));
      expect(entry.totalMantraCount, equals(0));

      final session1 = Session()
        ..time = DateTime.now()
        ..count = 3
        ..note = 'Morning session';

      final session2 = Session()
        ..time = DateTime.now()
        ..count = 5
        ..note = 'Night session';

      entry.sessions = [session1, session2];
      expect(entry.totalCount, equals(8));
      expect(entry.totalMalaCount, equals(8));
      expect(entry.totalMantraCount, equals(864)); // 8 * 108 = 864
    });
  });
}
