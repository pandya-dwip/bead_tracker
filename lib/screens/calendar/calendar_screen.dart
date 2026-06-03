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
    // Normalize selected day
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
            (e) => e != null &&
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
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Calendar Card
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
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
                    titleTextStyle: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
                    leftChevronIcon: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.primary),
                    rightChevronIcon: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
                  ),
                  daysOfWeekStyle: DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontWeight: FontWeight.w600),
                    weekendStyle: TextStyle(color: theme.colorScheme.primary.withOpacity(0.6), fontWeight: FontWeight.w600),
                  ),
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false),
                    todayBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, true),
                    selectedBuilder: (context, day, focusedDay) => _buildCalendarCell(context, day, false, isSelected: true),
                    outsideBuilder: (context, day, focusedDay) => Center(
                      child: Text(
                        day.day.toString(),
                        style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.2)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selection Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM d, yyyy').format(_selectedDay),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (totalDayMala > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: totalDayMala >= dailyGoalMala
                            ? theme.colorScheme.primary.withOpacity(0.12)
                            : theme.dividerColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: totalDayMala >= dailyGoalMala
                              ? theme.colorScheme.primary.withOpacity(0.3)
                              : theme.dividerColor.withOpacity(0.8),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${NumberFormat('#,###').format(totalDayMantra)} mantras (${totalDayMala.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} ${totalDayMala == 1 ? "mala" : "malas"})',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: totalDayMala >= dailyGoalMala ? theme.colorScheme.primary : theme.textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
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
          (e) => e != null &&
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
      bgColor = theme.colorScheme.primary.withOpacity(0.24);
      textColor = theme.colorScheme.primary;
    }

    BoxDecoration decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: bgColor ?? Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: theme.colorScheme.primary, width: 2.2),
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
        color: theme.dividerColor.withOpacity(0.6),
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
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // Session details list builder
  Widget _buildDetailsList(DailyEntry? entry, ThemeData theme) {
    if (entry == null || entry.sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spa_outlined, size: 48, color: theme.dividerColor),
            const SizedBox(height: 12),
            Text(
              'No practice sessions logged',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap below to record your counts for this day.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showAddEntrySheet(_selectedDay),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Entry'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 80),
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
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }

        final session = sortedSessions[index];
        final timeStr = DateFormat('h:mm a').format(session.time.toLocal());

        return Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${session.count}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              title: Text(
                session.note ?? 'Meditation Session',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: session.note == null ? theme.textTheme.bodyLarge?.color?.withOpacity(0.5) : theme.textTheme.bodyLarge?.color,
                  fontStyle: session.note == null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              subtitle: Text(
                '$timeStr • ${NumberFormat('#,###').format(session.mantraCount)} mantras',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                size: 20,
              ),
              onTap: () => _showEditEntrySheet(_selectedDay, session),
            ),
            if (index < sortedSessions.length - 1)
              Divider(height: 1, indent: 56, color: theme.dividerColor.withOpacity(0.4)),
          ],
        );
      },
    );
  }
}
