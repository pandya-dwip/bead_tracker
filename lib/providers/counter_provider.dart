import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bead_provider.dart';

class CounterState {
  final int currentBeads; // 0 to 107
  final DateTime lastActiveDate;

  const CounterState({
    required this.currentBeads,
    required this.lastActiveDate,
  });

  CounterState copyWith({
    int? currentBeads,
    DateTime? lastActiveDate,
  }) {
    return CounterState(
      currentBeads: currentBeads ?? this.currentBeads,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
    );
  }
}

class CounterNotifier extends StateNotifier<CounterState> {
  final Ref _ref;

  CounterNotifier(this._ref)
      : super(
          CounterState(
            currentBeads: 0,
            lastActiveDate: _normalizeDate(DateTime.now()),
          ),
        );

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Checks if the day has changed past midnight (12:00 AM) and resets the current bead count.
  void checkDateRollover() {
    final today = _normalizeDate(DateTime.now());
    if (today.isAfter(state.lastActiveDate)) {
      state = CounterState(
        currentBeads: 0,
        lastActiveDate: today,
      );
    }
  }

  /// Increments the mantra counter by 1.
  /// When reaching 108 mantras (1 full mala):
  /// - Resets the active bead counter to 0
  /// - Automatically adds 1 completed Mala to today's daily entry in the database
  /// Returns `true` if a full mala was completed on this tap.
  Future<bool> increment() async {
    checkDateRollover();

    final nextBeads = state.currentBeads + 1;
    if (nextBeads >= 108) {
      // 1 full mala reached!
      state = state.copyWith(currentBeads: 0);

      // Log 1 Mala session into today's record in Isar database
      final today = DateTime.now();
      await _ref.read(dailyEntriesProvider.notifier).addSession(
            today,
            1,
            'Chanted via Counter',
          );
      return true; // Completed 1 Mala
    } else {
      state = state.copyWith(currentBeads: nextBeads);
      return false;
    }
  }

  /// Decrements the bead count by 1 to rectify accidental double taps.
  void decrement() {
    checkDateRollover();
    if (state.currentBeads > 0) {
      state = state.copyWith(currentBeads: state.currentBeads - 1);
    }
  }

  /// Resets the active round's bead count back to 0.
  void resetCurrentRound() {
    state = state.copyWith(currentBeads: 0);
  }
}

final counterProvider = StateNotifierProvider<CounterNotifier, CounterState>((ref) {
  return CounterNotifier(ref);
});

/// Convenience provider for total mantras chanted today (completed malas * 108 + current in-progress beads)
final todayTotalMantrasWithActiveBeadsProvider = Provider<int>((ref) {
  final todayEntry = ref.watch(todayEntryProvider).valueOrNull;
  final counter = ref.watch(counterProvider);
  final completedMantras = todayEntry?.totalMantraCount ?? 0;
  return completedMantras + counter.currentBeads;
});
