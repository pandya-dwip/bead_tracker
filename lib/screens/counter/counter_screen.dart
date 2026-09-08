import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/bead_provider.dart';
import '../../providers/counter_provider.dart';

class CounterScreen extends ConsumerStatefulWidget {
  const CounterScreen({super.key});

  @override
  ConsumerState<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends ConsumerState<CounterScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 75),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutQuad,
    );

    // Check 24-hour date rollover whenever screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(counterProvider.notifier).checkDateRollover();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Non-blocking quick scale animation
    _scaleController.reverse().then((_) {
      if (mounted) _scaleController.forward();
    });

    // Instant haptic feedback on touch down
    HapticFeedback.lightImpact();

    // Immediate non-blocking state increment (instantly processes double/rapid taps)
    ref.read(counterProvider.notifier).increment().then((completedMala) {
      if (completedMala && mounted) {
        // Stronger celebration haptic
        HapticFeedback.heavyImpact();

        // Show celebration banner
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.stars_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🎉 1 Mala Completed! (+108 mantras saved to today\'s history)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _handleDecrement() {
    HapticFeedback.selectionClick();
    ref.read(counterProvider.notifier).decrement();
  }

  Future<void> _handleResetRound() async {
    final counter = ref.read(counterProvider);
    if (counter.currentBeads == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Current Mala?'),
        content: Text(
          'This will reset the active round\'s in-progress count (${counter.currentBeads}/108) back to 0. Completed malas will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.mediumImpact();
      ref.read(counterProvider.notifier).resetCurrentRound();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final counterState = ref.watch(counterProvider);
    final todayEntryAsync = ref.watch(todayEntryProvider);
    final settingsAsync = ref.watch(userSettingsProvider);
    final streakAsync = ref.watch(streakProvider);

    final todayMalas = todayEntryAsync.valueOrNull?.totalMalaCount ?? 0;
    final todayCompletedMantras = todayEntryAsync.valueOrNull?.totalMantraCount ?? 0;
    final totalMantrasToday = todayCompletedMantras + counterState.currentBeads;
    final dailyGoalMantras = settingsAsync.valueOrNull?.dailyGoal ?? 216;
    final dailyGoalMalas = (dailyGoalMantras / 108.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    final goalProgress = dailyGoalMantras > 0 ? (totalMantrasToday / dailyGoalMantras).clamp(0.0, 1.0) : 0.0;

    final currentBead = counterState.currentBeads;
    final progress = currentBead / 108.0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Date, Streak & 24h reset notice
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Row(
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
              ),
            ),

            const Spacer(flex: 1),

            // Interactive Center Bead Chanting Area (Ultra-responsive onTapDown)
            Center(
              child: GestureDetector(
                onTapDown: (_) => _handleTap(),
                behavior: HitTestBehavior.opaque,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: 270,
                    height: 270,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Custom Bead Radial Progress Painter
                        CustomPaint(
                          size: const Size(270, 270),
                          painter: _BeadCounterPainter(
                            progress: progress,
                            primaryColor: theme.colorScheme.primary,
                            trackColor: theme.brightness == Brightness.dark
                                ? theme.dividerColor.withValues(alpha: 0.35)
                                : const Color(0xFFE8E8EE),
                            beadCount: currentBead,
                          ),
                        ),
                        // Center Information Display
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'BEAD',
                              style: theme.textTheme.labelLarge?.copyWith(
                                letterSpacing: 2.0,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$currentBead',
                                  style: theme.textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.w300,
                                    fontSize: 68,
                                    letterSpacing: -2.0,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  '/108',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Tap to Count',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Controls Bar: Decrement (-1) and Reset Round
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Decrement Button
                  OutlinedButton.icon(
                    onPressed: currentBead > 0 ? _handleDecrement : null,
                    icon: const Icon(Icons.remove_rounded, size: 18),
                    label: const Text('-1 Bead'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  // Reset Round Button
                  OutlinedButton.icon(
                    onPressed: currentBead > 0 ? _handleResetRound : null,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reset Mala'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Bottom Summary Card (Today's Malas, Mantras, and Goal)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today\'s Progress',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$todayMalas ${todayMalas == 1 ? "mala" : "malas"} completed today ($dailyGoalMalas target)',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  '$todayMalas Malas',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Mantra numbers & progress bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${NumberFormat('#,###').format(totalMantrasToday)} mantras chanted',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(goalProgress * 100).toStringAsFixed(0)}% of daily goal',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: goalProgress >= 1.0
                                  ? theme.colorScheme.primary
                                  : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: goalProgress,
                          minHeight: 6,
                          backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _BeadCounterPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color trackColor;
  final int beadCount;

  _BeadCounterPainter({
    required this.progress,
    required this.primaryColor,
    required this.trackColor,
    required this.beadCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 16;
    const strokeWidth = 12.0;

    // Background track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // Start at 12 o'clock
        progress * 2 * pi,
        false,
        progressPaint,
      );

      // Current bead active head marker
      final angle = -pi / 2 + (progress * 2 * pi);
      final headX = center.dx + radius * cos(angle);
      final headY = center.dy + radius * sin(angle);

      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), 10, glowPaint);

      final beadDotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(headX, headY), 5, beadDotPaint);
    }
  }

  @override
  bool shouldRepaint(_BeadCounterPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.beadCount != beadCount;
  }
}
