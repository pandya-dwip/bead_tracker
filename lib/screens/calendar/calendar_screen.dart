import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/daily_entry.dart';
import '../../providers/bead_provider.dart';
import '../../widgets/add_entry_sheet.dart';
import '../../widgets/edit_entry_sheet.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _focusedDay = _selectedDay;
  }

  void _showAddEntrySheet(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddEntrySheet(selectedDate: date),
    );
  }

  void _showEditEntrySheet(DateTime date, Session session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EditEntrySheet(date: date, session: session),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final settingsAsync = ref.watch(userSettingsProvider);

    // Compute details for the selected day
    final selectedEntry = entriesAsync.when(
      data: (entries) => entries.cast<DailyEntry?>().firstWhere(
            (e) =>
                e != null &&
                e.date.year == _selectedDay.year &&
                e.date.month == _selectedDay.month &&
                e.date.day == _selectedDay.day,
            orElse: () => null,
          ),
      loading: () => null,
      error: (e, s) => null,
    );

    final dailyGoalMantra = settingsAsync.valueOrNull?.dailyGoal ?? 216;
    final dailyGoalMala = dailyGoalMantra / 108.0;
    final totalDayMantra = selectedEntry?.totalMantraCount ?? 0;
    final totalDayMala = selectedEntry?.totalMalaCount ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today_rounded),
            tooltip: 'Go to Today',
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                _selectedDay = DateTime(now.year, now.month, now.day);
                _focusedDay = _selectedDay;
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Calendar Container Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 14),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2025, 1, 1),
                    lastDay: DateTime.utc(2035, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarFormat: CalendarFormat.month,
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      leftChevronIcon: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.primary),
                      rightChevronIcon: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      weekendStyle: TextStyle(
                        color: theme.colorScheme.primary.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false),
                      todayBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, true),
                      selectedBuilder: (context, day, focusedDay) =>
                          _buildCalendarCell(context, day, false, isSelected: true),
                      outsideBuilder: (context, day, focusedDay) => Center(
                        child: Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.2),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Selection Header & Badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d').format(_selectedDay),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        totalDayMala > 0 ? '$totalDayMala malas recorded' : 'No practice recorded',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  if (totalDayMala > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: totalDayMala >= dailyGoalMala
                            ? theme.colorScheme.primary.withValues(alpha: 0.14)
                            : theme.dividerColor.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: totalDayMala >= dailyGoalMala
                              ? theme.colorScheme.primary.withValues(alpha: 0.4)
                              : theme.dividerColor,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${NumberFormat('#,###').format(totalDayMantra)} mantras',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: totalDayMala >= dailyGoalMala
                              ? theme.colorScheme.primary
                              : theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details List
            Expanded(
              child: _buildDetailsList(selectedEntry, theme),
            ),
          ],
        ),
      ),
    );
  }

  // Calendar Cell Builder with heatmap rules based on daily goal
  Widget _buildCalendarCell(BuildContext context, DateTime day, bool isToday, {bool isSelected = false}) {
    final theme = Theme.of(context);
    final entries = ref.watch(dailyEntriesProvider).valueOrNull ?? [];
    final dailyGoalMantra = ref.watch(userSettingsProvider).valueOrNull?.dailyGoal ?? 216;
    final dailyGoalMala = dailyGoalMantra / 108.0;

    final dayMidnight = DateTime(day.year, day.month, day.day);
    final match = entries.cast<DailyEntry?>().firstWhere(
          (e) =>
              e != null &&
              e.date.year == dayMidnight.year &&
              e.date.month == dayMidnight.month &&
              e.date.day == dayMidnight.day,
          orElse: () => null,
        );

    final countMala = match?.totalMalaCount ?? 0;
    Color? bgColor;
    Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    if (countMala >= dailyGoalMala && dailyGoalMala > 0) {
      bgColor = theme.colorScheme.primary;
      textColor = theme.colorScheme.onPrimary;
    } else if (countMala > 0) {
      bgColor = theme.colorScheme.primary.withValues(alpha: 0.22);
      textColor = theme.colorScheme.primary;
    }

    BoxDecoration decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: bgColor ?? Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.primary, width: 2.2),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      );
      if (bgColor == null) {
        textColor = theme.colorScheme.primary;
      }
    } else if (bgColor != null) {
      decoration = BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        color: theme.dividerColor.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      );
    } else {
      decoration = const BoxDecoration(shape: BoxShape.circle);
    }

    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: decoration,
        alignment: Alignment.center,
        child: Text(
          day.day.toString(),
          style: TextStyle(
            color: textColor,
            fontWeight: isToday || isSelected || countMala > 0 ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // Session details list builder
  Widget _buildDetailsList(DailyEntry? entry, ThemeData theme) {
    if (entry == null || entry.sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.self_improvement_rounded, size: 48, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              'No practice logged on this day',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap below to record completed malas for this date.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _showAddEntrySheet(_selectedDay),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Entry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    // Sort sessions by timestamp descending (newest first)
    final sortedSessions = List<Session>.from(entry.sessions)
      ..sort((a, b) => b.time.compareTo(a.time));

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 80),
      itemCount: sortedSessions.length + 1,
      itemBuilder: (context, index) {
        if (index == sortedSessions.length) {
          // Add Session row at bottom
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: TextButton.icon(
                onPressed: () => _showAddEntrySheet(_selectedDay),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Log another session for this day'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        }

        final session = sortedSessions[index];
        final timeStr = DateFormat('h:mm a').format(session.time.toLocal());

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '+${session.count}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            title: Text(
              session.note ?? 'Meditation Session',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: session.note == null
                    ? theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5)
                    : theme.textTheme.bodyLarge?.color,
                fontStyle: session.note == null ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            subtitle: Text(
              '$timeStr • ${NumberFormat('#,###').format(session.mantraCount)} mantras (${session.count} ${session.count == 1 ? "mala" : "malas"})',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.35),
              size: 20,
            ),
            onTap: () => _showEditEntrySheet(_selectedDay, session),
          ),
        );
      },
    );
  }
}
