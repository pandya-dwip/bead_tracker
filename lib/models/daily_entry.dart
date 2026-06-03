import 'package:isar/isar.dart';

part 'daily_entry.g.dart';

@collection
class DailyEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late DateTime date; // Store as date part only (midnight in local timezone)

  List<Session> sessions = [];

  // Helper getter to sum counts (malas) of all sessions for this day
  int get totalCount => sessions.fold(0, (sum, s) => sum + s.count);

  int get totalMalaCount => totalCount;
  int get totalMantraCount => totalMalaCount * 108;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  static DailyEntry fromJson(Map<String, dynamic> json) {
    final entry = DailyEntry()..date = DateTime.parse(json['date'] as String);
    if (json['sessions'] != null) {
      entry.sessions = (json['sessions'] as List)
          .map((s) => Session.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    return entry;
  }
}

@embedded
class Session {
  late DateTime time; // Full timestamp of when the session was logged
  late int count;      // Number of mala repetitions in this session
  String? note;       // Optional journal note

  int get mantraCount => count * 108;

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'count': count,
        'note': note,
      };

  static Session fromJson(Map<String, dynamic> json) {
    return Session()
      ..time = DateTime.parse(json['time'] as String)
      ..count = json['count'] as int
      ..note = json['note'] as String?;
  }
}
