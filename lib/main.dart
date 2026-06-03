import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'models/daily_entry.dart';
import 'models/user_settings.dart';
import 'services/database_service.dart';
import 'providers/bead_provider.dart';
import 'routes/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database service
  final dbService = DatabaseService();
  await dbService.init();

  // Clean launch - no database seeding
  // await _seedSampleData(dbService.isar);

  runApp(
    ProviderScope(
      overrides: [
        databaseServiceProvider.overrideWithValue(dbService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(userSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        return MaterialApp.router(
          title: 'Bead Tracker',
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          routerConfig: goRouter,
          debugShowCheckedModeBanner: false,
        );
      },
      loading: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (err, st) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text('Error initializing settings: $err'),
          ),
        ),
      ),
    );
  }
}

/// Seeds historical sample data to demonstrate features (streaks, charts, heatmap).
Future<void> _seedSampleData(Isar isar) async {
  final count = await isar.dailyEntrys.count();
  if (count > 0) return; // Has data already

  final today = DateTime.now();
  final List<Map<String, dynamic>> seedSchema = [
    {'daysAgo': 9, 'count': 2, 'note': 'Morning meditation'},
    {'daysAgo': 8, 'count': 3, 'note': 'Deep focus session'},
    {'daysAgo': 7, 'count': 1, 'note': 'Short evening practice'},
    // Day 6 ago is left empty to create a natural break in the historical streak
    {'daysAgo': 5, 'count': 2, 'note': 'Chanting and breathing'},
    {'daysAgo': 4, 'count': 3, 'note': 'Midday reflection'},
    {'daysAgo': 3, 'count': 1, 'note': 'Afternoon walk'},
    {'daysAgo': 2, 'count': 4, 'note': 'Evening mala rounds'},
    {'daysAgo': 1, 'count': 2, 'note': 'Focused breathwork'},
    {'daysAgo': 0, 'count': 1, 'note': 'Morning chanting'}, // Today starts with 1 mala
  ];

  await isar.writeTxn(() async {
    for (final item in seedSchema) {
      final daysAgo = item['daysAgo'] as int;
      final totalCount = item['count'] as int;
      final note = item['note'] as String;

      final targetDate = today.subtract(Duration(days: daysAgo));
      final midnightDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

      // Split the daily count into morning and evening sessions for realistic log history
      final morningCount = (totalCount / 2).floor();
      final eveningCount = totalCount - morningCount;

      final sessions = <Session>[];
      if (morningCount > 0) {
        sessions.add(
          Session()
            ..time = midnightDate.add(const Duration(hours: 8, minutes: 15))
            ..count = morningCount
            ..note = note,
        );
      }
      if (eveningCount > 0) {
        sessions.add(
          Session()
            ..time = midnightDate.add(const Duration(hours: 20, minutes: 30))
            ..count = eveningCount
            ..note = 'Evening practice',
        );
      }

      final entry = DailyEntry()
        ..date = midnightDate
        ..sessions = sessions;

      await isar.dailyEntrys.put(entry);
    }

    // Seed default settings containing goal targets and starting offset
    final settingsCount = await isar.userSettings.count();
    if (settingsCount == 0) {
      await isar.userSettings.put(
        UserSettings()
          ..dailyGoal = 2
          ..monthlyGoal = 60
          ..totalGoal = 1000
          ..totalOffset = 50 // Seed starting offset of 50 malas (5,400 mantras)
          ..isDarkMode = true,
      );
    }
  });
}
