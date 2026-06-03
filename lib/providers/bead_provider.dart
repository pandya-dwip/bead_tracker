import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_entry.dart';
import '../models/user_settings.dart';
import '../repositories/bead_repository.dart';
import '../services/database_service.dart';

// Base database provider (to be overridden in main.dart)
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('databaseServiceProvider has not been initialized');
});

// Repository provider
final beadRepositoryProvider = Provider<BeadRepository>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return BeadRepository(db.isar);
});

// Settings notifier and provider
class UserSettingsNotifier extends StateNotifier<AsyncValue<UserSettings>> {
  final BeadRepository _repository;

  UserSettingsNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    state = const AsyncValue.loading();
    try {
      final settings = await _repository.getUserSettings();
      state = AsyncValue.data(settings);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSettings({
    int? dailyGoal,
    int? monthlyGoal,
    int? totalGoal,
    int? totalOffset,
    bool? isDarkMode,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = UserSettings()
      ..dailyGoal = dailyGoal ?? current.dailyGoal
      ..monthlyGoal = monthlyGoal ?? current.monthlyGoal
      ..totalGoal = totalGoal ?? current.totalGoal
      ..totalOffset = totalOffset ?? current.totalOffset
      ..isDarkMode = isDarkMode ?? current.isDarkMode;

    try {
      await _repository.saveUserSettings(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final userSettingsProvider = StateNotifierProvider<UserSettingsNotifier, AsyncValue<UserSettings>>((ref) {
  final repo = ref.watch(beadRepositoryProvider);
  return UserSettingsNotifier(repo);
});

// Daily entries notifier and provider
class DailyEntriesNotifier extends StateNotifier<AsyncValue<List<DailyEntry>>> {
  final BeadRepository _repository;

  DailyEntriesNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadEntries();
  }

  Future<void> loadEntries() async {
    state = const AsyncValue.loading();
    try {
      final entries = await _repository.getAllEntries();
      state = AsyncValue.data(entries);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addSession(DateTime date, int count, String? note) async {
    final session = Session()
      ..time = DateTime.now()
      ..count = count
      ..note = note;
    await _repository.addSession(date, session);
    await loadEntries();
  }

  Future<void> updateSession({
    required DateTime date,
    required DateTime sessionTime,
    required int count,
    required String? note,
  }) async {
    await _repository.updateSession(
      date: date,
      sessionTime: sessionTime,
      newCount: count,
      newNote: note,
    );
    await loadEntries();
  }

  Future<void> deleteSession(DateTime date, DateTime sessionTime) async {
    await _repository.deleteSession(date, sessionTime);
    await loadEntries();
  }

  Future<void> resetAll() async {
    await _repository.resetAllData();
    await loadEntries();
  }

  Future<void> restoreBackup(UserSettings settings, List<DailyEntry> entries) async {
    await _repository.restoreBackup(settings, entries);
    await loadEntries();
  }
}

final dailyEntriesProvider = StateNotifierProvider<DailyEntriesNotifier, AsyncValue<List<DailyEntry>>>((ref) {
  final repo = ref.watch(beadRepositoryProvider);
  return DailyEntriesNotifier(repo);
});

// Today's entry provider
final todayEntryProvider = Provider<AsyncValue<DailyEntry?>>((ref) {
  final entriesAsync = ref.watch(dailyEntriesProvider);
  return entriesAsync.when(
    data: (entries) {
      final today = DateTime.now();
      final todayEntry = entries.cast<DailyEntry?>().firstWhere(
        (e) => e != null &&
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day,
        orElse: () => null,
      );
      return AsyncValue.data(todayEntry);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// Streak provider
final streakProvider = Provider<AsyncValue<int>>((ref) {
  final entriesAsync = ref.watch(dailyEntriesProvider);
  return entriesAsync.when(
    data: (entries) {
      final loggedDates = entries
          .where((e) => e.totalCount > 0)
          .map((e) => e.date)
          .toList();
      final streak = _calculateStreak(loggedDates, DateTime.now());
      return AsyncValue.data(streak);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

int _calculateStreak(List<DateTime> loggedDays, DateTime today) {
  if (loggedDays.isEmpty) return 0;

  // Normalize loggedDays to unique date strings (yyyy-MM-dd) in local time
  final Set<String> uniqueDays = loggedDays
      .map((d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}")
      .toSet();

  final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
  final yesterday = today.subtract(const Duration(days: 1));
  final yesterdayStr = "${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}";

  String currentCheckStr;
  if (uniqueDays.contains(todayStr)) {
    currentCheckStr = todayStr;
  } else if (uniqueDays.contains(yesterdayStr)) {
    currentCheckStr = yesterdayStr;
  } else {
    return 0; // Streak is broken
  }

  int streak = 0;
  DateTime checkDate = currentCheckStr == todayStr ? today : yesterday;

  while (true) {
    final checkStr = "${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}";
    if (uniqueDays.contains(checkStr)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  return streak;
}

// Calculations model
class BeadCalculations {
  final int currentTotalMantras;
  final double currentTotalMalas;
  final int currentMonthMantras;
  final double currentMonthMalas;
  final double totalPercentage;
  final double monthlyPercentage;
  final int remainingMantraGoal;
  final double remainingMalaGoal;
  final double averageDailyMantras;
  final double averageDailyMalas;
  final int estimatedDays;
  final DateTime? estimatedCompletionDate;

  BeadCalculations({
    required this.currentTotalMantras,
    required this.currentTotalMalas,
    required this.currentMonthMantras,
    required this.currentMonthMalas,
    required this.totalPercentage,
    required this.monthlyPercentage,
    required this.remainingMantraGoal,
    required this.remainingMalaGoal,
    required this.averageDailyMantras,
    required this.averageDailyMalas,
    required this.estimatedDays,
    this.estimatedCompletionDate,
  });
}

// Computed calculations provider
final calculationsProvider = Provider<AsyncValue<BeadCalculations>>((ref) {
  final entriesAsync = ref.watch(dailyEntriesProvider);
  final settingsAsync = ref.watch(userSettingsProvider);

  if (entriesAsync is AsyncLoading || settingsAsync is AsyncLoading) {
    return const AsyncValue.loading();
  }
  if (entriesAsync is AsyncError || settingsAsync is AsyncError) {
    final err = entriesAsync.error ?? settingsAsync.error!;
    final st = entriesAsync.stackTrace ?? settingsAsync.stackTrace!;
    return AsyncValue.error(err, st);
  }

  final entries = entriesAsync.value ?? [];
  final settings = settingsAsync.value ?? UserSettings();

  // 1. Current total mantras = (sessions malas * 108) + offset mantras
  final sessionsTotalMalas = entries.fold(0, (sum, e) => sum + e.totalMalaCount);
  final currentTotalMantras = (sessionsTotalMalas * 108) + settings.totalOffset;
  final currentTotalMalas = currentTotalMantras / 108.0;

  // 2. Current Month count
  final now = DateTime.now();
  final currentMonthMalas = entries
      .where((e) => e.date.year == now.year && e.date.month == now.month)
      .fold(0, (sum, e) => sum + e.totalMalaCount).toDouble();
  final currentMonthMantras = (currentMonthMalas * 108).toInt();

  // 3. Goals in mantras (read directly from database)
  final totalGoalMantras = settings.totalGoal;
  final monthlyGoalMantras = settings.monthlyGoal;

  // 4. Percentages
  final totalPercent = totalGoalMantras > 0
      ? (currentTotalMantras / totalGoalMantras * 100).clamp(0.0, 100.0)
      : 0.0;

  final monthlyPercent = monthlyGoalMantras > 0
      ? (currentMonthMantras / monthlyGoalMantras * 100).clamp(0.0, 100.0)
      : 0.0;

  // 5. Remaining Goals
  final remainingMantras = (totalGoalMantras - currentTotalMantras).clamp(0, 99999999);
  final remainingMalas = remainingMantras / 108.0;

  // 6. Average Daily Count
  final loggedDaysWithCounts = entries.where((e) => e.totalMalaCount > 0).toList();
  final double avgDailyMalas;
  if (loggedDaysWithCounts.isEmpty) {
    avgDailyMalas = settings.dailyGoal.toDouble() > 0 ? (settings.dailyGoal / 108.0) : 2.0;
  } else {
    final totalLoggedMalas = loggedDaysWithCounts.fold(0, (sum, e) => sum + e.totalMalaCount);
    avgDailyMalas = totalLoggedMalas / loggedDaysWithCounts.length;
  }
  final avgDailyMantras = avgDailyMalas * 108;

  // 7. Estimated Completion
  final int estDays;
  if (remainingMantras <= 0) {
    estDays = 0;
  } else if (avgDailyMantras <= 0) {
    estDays = 9999;
  } else {
    estDays = (remainingMantras / avgDailyMantras).ceil();
  }

  final DateTime? estCompletionDate = estDays > 0 && estDays < 9999
      ? now.add(Duration(days: estDays))
      : null;

  return AsyncValue.data(BeadCalculations(
    currentTotalMantras: currentTotalMantras,
    currentTotalMalas: currentTotalMalas,
    currentMonthMantras: currentMonthMantras,
    currentMonthMalas: currentMonthMalas,
    totalPercentage: totalPercent,
    monthlyPercentage: monthlyPercent,
    remainingMantraGoal: remainingMantras,
    remainingMalaGoal: remainingMalas,
    averageDailyMantras: avgDailyMantras,
    averageDailyMalas: avgDailyMalas,
    estimatedDays: estDays,
    estimatedCompletionDate: estCompletionDate,
  ));
});
