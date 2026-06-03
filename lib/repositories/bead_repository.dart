import 'package:isar/isar.dart';
import '../models/daily_entry.dart';
import '../models/user_settings.dart';

class BeadRepository {
  final Isar isar;

  BeadRepository(this.isar);

  /// Helper to strip time information and return midnight of local date
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Get all daily entries, sorted by date ascending
  Future<List<DailyEntry>> getAllEntries() async {
    return await isar.dailyEntrys.where().sortByDate().findAll();
  }

  /// Get daily entry for a specific date
  Future<DailyEntry?> getEntryForDate(DateTime date) async {
    final normalized = _normalizeDate(date);
    return await isar.dailyEntrys.filter().dateEqualTo(normalized).findFirst();
  }

  /// Add a new session count to a specific date
  Future<void> addSession(DateTime date, Session session) async {
    final normalized = _normalizeDate(date);
    await isar.writeTxn(() async {
      final existingEntry = await isar.dailyEntrys.filter().dateEqualTo(normalized).findFirst();
      
      if (existingEntry != null) {
        // Add to existing entry's list of sessions
        // Note: Isar lists require creating a new list or re-assigning for dirty tracking
        final updatedSessions = List<Session>.from(existingEntry.sessions)..add(session);
        existingEntry.sessions = updatedSessions;
        await isar.dailyEntrys.put(existingEntry);
      } else {
        // Create new daily entry
        final newEntry = DailyEntry()
          ..date = normalized
          ..sessions = [session];
        await isar.dailyEntrys.put(newEntry);
      }
    });
  }

  /// Update an existing session count and note
  Future<void> updateSession({
    required DateTime date,
    required DateTime sessionTime,
    required int newCount,
    required String? newNote,
  }) async {
    final normalized = _normalizeDate(date);
    await isar.writeTxn(() async {
      final entry = await isar.dailyEntrys.filter().dateEqualTo(normalized).findFirst();
      if (entry != null) {
        final sessions = List<Session>.from(entry.sessions);
        final index = sessions.indexWhere((s) => s.time.isAtSameMomentAs(sessionTime));
        if (index != -1) {
          sessions[index] = Session()
            ..time = sessionTime
            ..count = newCount
            ..note = newNote;
          entry.sessions = sessions;
          await isar.dailyEntrys.put(entry);
        }
      }
    });
  }

  /// Delete a session. If the entry contains no sessions left, deletes the DailyEntry entirely.
  Future<void> deleteSession(DateTime date, DateTime sessionTime) async {
    final normalized = _normalizeDate(date);
    await isar.writeTxn(() async {
      final entry = await isar.dailyEntrys.filter().dateEqualTo(normalized).findFirst();
      if (entry != null) {
        final sessions = List<Session>.from(entry.sessions);
        sessions.removeWhere((s) => s.time.isAtSameMomentAs(sessionTime));
        
        if (sessions.isEmpty) {
          await isar.dailyEntrys.delete(entry.id);
        } else {
          entry.sessions = sessions;
          await isar.dailyEntrys.put(entry);
        }
      }
    });
  }

  /// Retrieve the single UserSettings record
  Future<UserSettings> getUserSettings() async {
    final settings = await isar.userSettings.get(0);
    if (settings != null) {
      return settings;
    }
    // Fallback if not seeded
    final defaults = UserSettings();
    await isar.writeTxn(() async {
      await isar.userSettings.put(defaults);
    });
    return defaults;
  }

  /// Save/Update the UserSettings record
  Future<void> saveUserSettings(UserSettings settings) async {
    settings.id = 0; // Force key to 0
    await isar.writeTxn(() async {
      await isar.userSettings.put(settings);
    });
  }

  /// Reset all data (wipes daily entries and restores default settings)
  Future<void> resetAllData() async {
    await isar.writeTxn(() async {
      await isar.dailyEntrys.clear();
      await isar.userSettings.clear();
      await isar.userSettings.put(UserSettings());
    });
  }

  /// Restore settings and entries from imported data
  Future<void> restoreBackup(UserSettings settings, List<DailyEntry> entries) async {
    await isar.writeTxn(() async {
      await isar.dailyEntrys.clear();
      await isar.userSettings.clear();

      settings.id = 0; // Force key to 0
      await isar.userSettings.put(settings);

      for (final entry in entries) {
        // Clear any ID to let Isar auto-increment if needed, or put them as-is
        entry.id = Isar.autoIncrement;
        await isar.dailyEntrys.put(entry);
      }
    });
  }
}
