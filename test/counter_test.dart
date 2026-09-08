import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:bead_tracker/providers/counter_provider.dart';
import 'package:bead_tracker/providers/bead_provider.dart';
import 'package:bead_tracker/models/daily_entry.dart';
import 'package:bead_tracker/models/user_settings.dart';
import 'package:bead_tracker/repositories/bead_repository.dart';

// Fake Repository for testing Provider logic without Isar native libraries
class FakeBeadRepository implements BeadRepository {
  final List<DailyEntry> _entries = [];
  UserSettings _settings = UserSettings();

  @override
  Isar get isar => throw UnimplementedError();

  @override
  Future<List<DailyEntry>> getAllEntries() async => List.from(_entries);

  @override
  Future<DailyEntry?> getEntryForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    try {
      return _entries.firstWhere(
        (e) =>
            e.date.year == normalized.year &&
            e.date.month == normalized.month &&
            e.date.day == normalized.day,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addSession(DateTime date, Session session) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final existing = await getEntryForDate(normalized);
    if (existing != null) {
      existing.sessions = List<Session>.from(existing.sessions)..add(session);
    } else {
      final newEntry = DailyEntry()
        ..date = normalized
        ..sessions = [session];
      _entries.add(newEntry);
    }
  }

  @override
  Future<void> updateSession({
    required DateTime date,
    required DateTime sessionTime,
    required int newCount,
    required String? newNote,
  }) async {}

  @override
  Future<void> deleteSession(DateTime date, DateTime sessionTime) async {}

  @override
  Future<UserSettings> getUserSettings() async => _settings;

  @override
  Future<void> saveUserSettings(UserSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> resetAllData() async {
    _entries.clear();
    _settings = UserSettings();
  }

  @override
  Future<void> restoreBackup(UserSettings settings, List<DailyEntry> entries) async {
    _settings = settings;
    _entries
      ..clear()
      ..addAll(entries);
  }
}

void main() {
  group('CounterProvider Unit Tests', () {
    late ProviderContainer container;
    late FakeBeadRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeBeadRepository();
      container = ProviderContainer(
        overrides: [
          beadRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial counter state should start at 0 beads', () {
      final state = container.read(counterProvider);
      expect(state.currentBeads, equals(0));
    });

    test('Increment should advance bead count 1 by 1', () async {
      final notifier = container.read(counterProvider.notifier);

      final completedMala1 = await notifier.increment();
      expect(completedMala1, isFalse);
      expect(container.read(counterProvider).currentBeads, equals(1));

      final completedMala2 = await notifier.increment();
      expect(completedMala2, isFalse);
      expect(container.read(counterProvider).currentBeads, equals(2));
    });

    test('Decrement should decrease bead count without going below 0', () {
      final notifier = container.read(counterProvider.notifier);

      // Decrement when 0 remains 0
      notifier.decrement();
      expect(container.read(counterProvider).currentBeads, equals(0));

      // Increment twice, then decrement once
      notifier.increment();
      notifier.increment();
      expect(container.read(counterProvider).currentBeads, equals(2));

      notifier.decrement();
      expect(container.read(counterProvider).currentBeads, equals(1));
    });

    test('ResetCurrentRound should set beads back to 0', () async {
      final notifier = container.read(counterProvider.notifier);
      await notifier.increment();
      await notifier.increment();
      await notifier.increment();
      expect(container.read(counterProvider).currentBeads, equals(3));

      notifier.resetCurrentRound();
      expect(container.read(counterProvider).currentBeads, equals(0));
    });

    test('Reaching 108 beads should log 1 completed Mala and reset counter to 0', () async {
      final notifier = container.read(counterProvider.notifier);

      // Increment 107 times
      for (int i = 0; i < 107; i++) {
        final completed = await notifier.increment();
        expect(completed, isFalse);
      }
      expect(container.read(counterProvider).currentBeads, equals(107));

      // 108th tap triggers full mala
      final completed = await notifier.increment();
      expect(completed, isTrue);
      expect(container.read(counterProvider).currentBeads, equals(0));

      // Verify session was added into dailyEntries
      final entriesAsync = container.read(dailyEntriesProvider);
      final entries = entriesAsync.value ?? [];
      expect(entries.length, equals(1));
      expect(entries.first.totalMalaCount, equals(1));
      expect(entries.first.totalMantraCount, equals(108));
    });

    test('todayTotalMantrasWithActiveBeadsProvider should correctly sum completed + in-progress beads', () async {
      final notifier = container.read(counterProvider.notifier);

      // Add 25 beads
      for (int i = 0; i < 25; i++) {
        await notifier.increment();
      }

      final totalMantras = container.read(todayTotalMantrasWithActiveBeadsProvider);
      expect(totalMantras, equals(25));
    });
  });
}
