import 'package:isar/isar.dart';

part 'user_settings.g.dart';

@collection
class UserSettings {
  Id id = 0; // We only store a single configuration row, so id is fixed to 0

  int dailyGoal = 216;      // Default daily goal: 216 mantras (2 malas)
  int monthlyGoal = 5400;   // Default monthly goal: 5,400 mantras (50 malas)
  int totalGoal = 150000;   // Default total goal: 150,000 mantras (~1388.9 malas)

  int totalOffset = 0;      // Offset to adjust the total count manually (in mantras)

  bool isDarkMode = true;   // Default theme mode is dark mode

  Map<String, dynamic> toJson() => {
        'dailyGoal': dailyGoal,
        'monthlyGoal': monthlyGoal,
        'totalGoal': totalGoal,
        'totalOffset': totalOffset,
        'isDarkMode': isDarkMode,
      };

  static UserSettings fromJson(Map<String, dynamic> json) {
    return UserSettings()
      ..dailyGoal = json['dailyGoal'] as int
      ..monthlyGoal = json['monthlyGoal'] as int
      ..totalGoal = json['totalGoal'] as int
      ..totalOffset = json['totalOffset'] as int
      ..isDarkMode = json['isDarkMode'] as bool;
  }
}
