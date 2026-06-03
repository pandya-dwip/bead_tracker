import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/daily_entry.dart';
import '../models/user_settings.dart';

class DatabaseService {
  late final Isar isar;

  /// Initializes the Isar database.
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = await Isar.open(
      [
        DailyEntrySchema,
        UserSettingsSchema,
      ],
      directory: dir.path,
    );

    // Seed default user settings if none exist
    final count = await isar.userSettings.count();
    if (count == 0) {
      await isar.writeTxn(() async {
        await isar.userSettings.put(UserSettings());
      });
    }
  }
}
