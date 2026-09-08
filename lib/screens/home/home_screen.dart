import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../models/daily_entry.dart';
import '../../models/user_settings.dart';
import '../../providers/bead_provider.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/add_entry_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Listen to providers
    final settingsAsync = ref.watch(userSettingsProvider);
    final entriesAsync = ref.watch(dailyEntriesProvider);
    final streakAsync = ref.watch(streakProvider);
    final calculationsAsync = ref.watch(calculationsProvider);
    final todayEntryAsync = ref.watch(todayEntryProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(userSettingsProvider.notifier).loadSettings();
            ref.read(dailyEntriesProvider.notifier).loadEntries();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header (Date, Greeting, and Streak Badge)
                _buildHeader(context, streakAsync),
                const SizedBox(height: 28),

                // Main Progress Ring Showcase Card
                Center(
                  child: calculationsAsync.when(
                    data: (calc) {
                      final totalGoalMantras = settingsAsync.valueOrNull?.totalGoal ?? 150000;
                      final totalGoalMalasStr =
                          (totalGoalMantras / 108.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
                      final currentTotalMalasStr =
                          calc.currentTotalMalas.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
                      return ProgressRing(
                        progress: calc.totalPercentage / 100,
                        title: NumberFormat('#,###').format(calc.currentTotalMantras),
                        subtitle:
                            'of ${NumberFormat('#,###').format(totalGoalMantras)} mantras\n($currentTotalMalasStr / $totalGoalMalasStr malas)',
                      );
                    },
                    loading: () => const ProgressRing(progress: 0.0, title: '0', subtitle: 'Loading...'),
                    error: (e, s) => const ProgressRing(progress: 0.0, title: 'Error', subtitle: 'Check logs'),
                  ),
                ),
                const SizedBox(height: 36),

                // Progress Cards Section (Daily & Monthly)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily Progress Card
                    Expanded(
                      child: _buildDailyCard(context, todayEntryAsync, settingsAsync),
                    ),
                    const SizedBox(width: 14),
                    // Monthly Progress Card
                    Expanded(
                      child: _buildMonthlyCard(context, calculationsAsync, settingsAsync),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Completion Prediction Card
                _buildPredictionCard(context, calculationsAsync),
                const SizedBox(height: 16),

                // Weekly Trend Chart Card
                _buildWeeklyTrendCard(context, entriesAsync),
                const SizedBox(height: 80), // Padding for FAB
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEntrySheet(context),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Log Malas',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.2),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  // Header Builder (Matching Counter Screen)
  Widget _buildHeader(BuildContext context, AsyncValue<int> streakAsync) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, MMM d').format(DateTime.now()),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
                fontSize: 22,
              ),
            ),
            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '24h Cycle (12 AM – 12 AM)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        streakAsync.when(
          data: (streak) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: theme.colorScheme.primary,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  // Daily Card Builder
  Widget _buildDailyCard(
    BuildContext context,
    AsyncValue<DailyEntry?> todayEntryAsync,
    AsyncValue<UserSettings> settingsAsync,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: todayEntryAsync.when(
          data: (entry) {
            final todayMala = entry?.totalMalaCount ?? 0;
            final todayMantra = entry?.totalMantraCount ?? 0;
            final dailyGoalMantra = settingsAsync.valueOrNull?.dailyGoal ?? 216;
            final dailyGoalMala = dailyGoalMantra / 108.0;

            final remainingMantra = (dailyGoalMantra - todayMantra).clamp(0, dailyGoalMantra);
            final double percent = dailyGoalMantra > 0 ? (todayMantra / dailyGoalMantra).clamp(0.0, 1.0) : 0.0;

            final dailyGoalMalaStr = dailyGoalMala.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
            final remainingMalaStr = (remainingMantra / 108.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Today',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.today_rounded, size: 16, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  NumberFormat('#,###').format(todayMantra),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'of ${NumberFormat('#,###').format(dailyGoalMantra)} mantras',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$todayMala of $dailyGoalMalaStr malas',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remainingMantra <= 0 ? 'Goal accomplished ✨' : '$remainingMalaStr malas left',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: remainingMantra <= 0
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    fontWeight: remainingMantra <= 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 5,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, s) => const Center(child: Text('Error loading')),
        ),
      ),
    );
  }

  // Monthly Card Builder
  Widget _buildMonthlyCard(
    BuildContext context,
    AsyncValue<BeadCalculations> calculationsAsync,
    AsyncValue<UserSettings> settingsAsync,
  ) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: calculationsAsync.when(
          data: (calc) {
            final monthlyGoalMantra = settingsAsync.valueOrNull?.monthlyGoal ?? 5400;
            final monthlyGoalMala = monthlyGoalMantra / 108.0;
            final percent = calc.monthlyPercentage;

            final monthlyGoalMalaStr = monthlyGoalMala.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
            final currentMonthMalasStr = calc.currentMonthMalas.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monthly',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_month_rounded, size: 16, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  NumberFormat('#,###').format(calc.currentMonthMantras),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'of ${NumberFormat('#,###').format(monthlyGoalMantra)} mantras',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$currentMonthMalasStr of $monthlyGoalMalaStr malas',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${percent.toStringAsFixed(0)}% complete',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: percent >= 100
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                    fontWeight: percent >= 100 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent / 100,
                    minHeight: 5,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, s) => const Center(child: Text('Error loading')),
        ),
      ),
    );
  }

  // Prediction Card Builder
  Widget _buildPredictionCard(BuildContext context, AsyncValue<BeadCalculations> calculationsAsync) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: calculationsAsync.when(
          data: (calc) {
            final dateStr = calc.estimatedCompletionDate != null
                ? DateFormat('MMMM d, yyyy').format(calc.estimatedCompletionDate!)
                : 'Goal reached';
            final remainingText = calc.remainingMantraGoal > 0
                ? 'Est. ${calc.estimatedDays} days remaining'
                : 'Total goal accomplished!';
            final subText = calc.remainingMantraGoal > 0
                ? 'Requires ${calc.remainingMalaGoal.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} malas at current pace'
                : 'Congratulations on completing your practice!';

            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.primary, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Completion Forecast',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dateStr,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        remainingText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, s) => const Center(child: Text('Error computing predictions')),
        ),
      ),
    );
  }

  // Weekly Trend Chart Card Builder
  Widget _buildWeeklyTrendCard(BuildContext context, AsyncValue<List<DailyEntry>> entriesAsync) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Trend',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daily mantra counts over last 7 days',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.show_chart_rounded, size: 18, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 160,
              child: entriesAsync.when(
                data: (entries) => _buildChart(context, entries),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => const Center(child: Text('Error loading chart')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Render Line Chart using fl_chart
  Widget _buildChart(BuildContext context, List<DailyEntry> entries) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    // Generate last 7 days (including today)
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final last7Days = List.generate(7, (i) {
      return todayMidnight.subtract(Duration(days: 6 - i));
    });

    // Match counts
    final List<FlSpot> spots = [];
    double maxMantraY = 216; // Default minimum Y-axis max height (2 malas)

    for (int i = 0; i < 7; i++) {
      final day = last7Days[i];
      final match = entries.cast<DailyEntry?>().firstWhere(
            (e) =>
                e != null &&
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day,
            orElse: () => null,
          );
      final count = match?.totalMantraCount.toDouble() ?? 0.0;
      spots.add(FlSpot(i.toDouble(), count));
      if (count > maxMantraY) {
        maxMantraY = count;
      }
    }

    // Set height slightly above maxMantraY for aesthetic padding
    maxMantraY = (maxMantraY * 1.18).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: maxMantraY,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= 7) return const SizedBox.shrink();
                final day = last7Days[index];
                final label = DateFormat('E').format(day).substring(0, 1);
                final isToday = index == 6;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Container(
                    padding: isToday ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2) : EdgeInsets.zero,
                    decoration: isToday
                        ? BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isToday
                            ? accent
                            : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => theme.cardColor,
            tooltipBorder: BorderSide(color: theme.dividerColor, width: 1),
            tooltipRoundedRadius: 12,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final day = last7Days[spot.x.toInt()];
                final dateLabel = DateFormat('MMM d').format(day);
                final malasCount = spot.y / 108.0;
                return LineTooltipItem(
                  '$dateLabel\n${spot.y.toInt()} mantras\n(${malasCount.toStringAsFixed(1)} malas)',
                  TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: accent,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: index == 6 ? 5 : 3.5,
                  color: accent,
                  strokeWidth: 2,
                  strokeColor: theme.cardColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.28),
                  accent.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Open add entry bottom sheet
  void _showAddEntrySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddEntrySheet(selectedDate: DateTime.now()),
    );
  }
}
