import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import '../../models/user_settings.dart';
import '../../models/daily_entry.dart';
import '../../providers/bead_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showEditGoalDialog(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int currentValueMantras,
    required Function(int newValueMantras) onSave,
  }) {
    final malasController = TextEditingController(
      text: (currentValueMantras / 108.0).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), ''),
    );
    final mantrasController = TextEditingController(
      text: currentValueMantras.toString(),
    );
    final formKey = GlobalKey<FormState>();
    bool isSyncing = false;

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Edit $title', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set target goals using rounds or repetitions. Changing either field automatically calculates the other (1 mala = 108 mantras).',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                // Mala Field
                TextFormField(
                  controller: malasController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Mala Rounds',
                    suffixText: 'rounds',
                    prefixIcon: Icon(Icons.refresh_rounded),
                  ),
                  onChanged: (val) {
                    if (isSyncing) return;
                    isSyncing = true;
                    final parsed = double.tryParse(val) ?? 0.0;
                    mantrasController.text = (parsed * 108).round().toString();
                    isSyncing = false;
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter mala count';
                    }
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed < 0) {
                      return 'Must be a non-negative number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Mantra Field
                TextFormField(
                  controller: mantrasController,
                  keyboardType: TextInputType.number,
                  style: theme.textTheme.bodyLarge,
                  decoration: const InputDecoration(
                    labelText: 'Mantra Repetitions',
                    suffixText: 'mantras',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  onChanged: (val) {
                    if (isSyncing) return;
                    isSyncing = true;
                    final parsed = int.tryParse(val) ?? 0;
                    final computedMalas = parsed / 108.0;
                    malasController.text = computedMalas.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
                    isSyncing = false;
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter mantra count';
                    }
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed < 0) {
                      return 'Must be a non-negative integer';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final finalMantras = int.parse(mantrasController.text);
                  onSave(finalMantras);
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Save Target', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final settingsAsync = ref.read(userSettingsProvider);
      final entriesAsync = ref.read(dailyEntriesProvider);

      if (settingsAsync.valueOrNull == null || entriesAsync.valueOrNull == null) {
        throw Exception('Data is not fully loaded. Please try again.');
      }

      final settings = settingsAsync.value!;
      final entries = entriesAsync.value!;

      // 1. Generate JSON
      final Map<String, dynamic> backupData = {
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };
      final String jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final Uint8List bytes = Uint8List.fromList(utf8.encode(jsonString));

      // 2. Save directly to system Downloads
      final String path = await FileSaver.instance.saveFile(
        name: 'bead_tracker_backup',
        bytes: bytes,
        fileExtension: 'json',
        mimeType: MimeType.json,
      );

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                SizedBox(width: 10),
                Text('Export Complete'),
              ],
            ),
            content: Text('Backup file successfully saved to your Downloads folder:\n\n$path'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Export Failed'),
              ],
            ),
            content: Text('Could not create backup: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    try {
      final FilePickerResult? result = await FilePicker.pickFiles(
        dialogTitle: 'Select bead_tracker_backup.json file',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User cancelled
      }

      final path = result.files.single.path!;
      final file = File(path);
      final content = await file.readAsString();

      final Map<String, dynamic> backupData = jsonDecode(content) as Map<String, dynamic>;

      if (backupData['settings'] == null || backupData['entries'] == null) {
        throw const FormatException('Invalid backup file structure: missing settings or entries.');
      }

      final settingsJson = backupData['settings'] as Map<String, dynamic>;
      final entriesJson = backupData['entries'] as List<dynamic>;

      final importedSettings = UserSettings.fromJson(settingsJson);
      final importedEntries = entriesJson.map((e) => DailyEntry.fromJson(e as Map<String, dynamic>)).toList();

      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Confirm Import?'),
            content: const Text(
              'Importing this backup will overwrite all current daily logs, sessions, offsets, and restore goal configurations from the backup file. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Restore Data', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Restoring backup...'),
              ],
            ),
          ),
        );
      }

      await ref.read(dailyEntriesProvider.notifier).restoreBackup(importedSettings, importedEntries);
      await ref.read(userSettingsProvider.notifier).loadSettings();

      if (context.mounted) {
        Navigator.of(context).pop();

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                SizedBox(width: 10),
                Text('Import Complete'),
              ],
            ),
            content: const Text('All configurations, offsets, and session entries have been restored successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Import Failed'),
              ],
            ),
            content: Text('Could not restore backup: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // Reset verification
  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will permanently delete all daily logs, sessions, offsets, and restore goals to default. This action cannot be reversed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Reset Everything', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(dailyEntriesProvider.notifier).resetAll();
      await ref.read(userSettingsProvider.notifier).updateSettings(
            dailyGoal: 216,
            monthlyGoal: 5400,
            totalGoal: 150000,
            totalOffset: 0,
            isDarkMode: true,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('App data reset successfully'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(userSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: settingsAsync.when(
          data: (settings) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title: Goals Section
                  _buildSectionHeader(context, 'GOALS & TARGETS', Icons.flag_rounded),
                  Card(
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context,
                          title: 'Daily Practice Goal',
                          subtitle:
                              '${(settings.dailyGoal / 108.0).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} malas (${settings.dailyGoal} mantras)',
                          icon: Icons.today_rounded,
                          onTap: () => _showEditGoalDialog(
                            context,
                            ref,
                            title: 'Daily Goal',
                            currentValueMantras: settings.dailyGoal,
                            onSave: (val) => ref.read(userSettingsProvider.notifier).updateSettings(dailyGoal: val),
                          ),
                        ),
                        Divider(height: 1, indent: 64, color: theme.dividerColor.withValues(alpha: 0.5)),
                        _buildSettingTile(
                          context,
                          title: 'Monthly Practice Goal',
                          subtitle:
                              '${(settings.monthlyGoal / 108.0).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} malas (${settings.monthlyGoal} mantras)',
                          icon: Icons.calendar_month_rounded,
                          onTap: () => _showEditGoalDialog(
                            context,
                            ref,
                            title: 'Monthly Goal',
                            currentValueMantras: settings.monthlyGoal,
                            onSave: (val) => ref.read(userSettingsProvider.notifier).updateSettings(monthlyGoal: val),
                          ),
                        ),
                        Divider(height: 1, indent: 64, color: theme.dividerColor.withValues(alpha: 0.5)),
                        _buildSettingTile(
                          context,
                          title: 'Total Lifetime Goal',
                          subtitle:
                              '${(settings.totalGoal / 108.0).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} malas (${NumberFormat('#,###').format(settings.totalGoal)} mantras)',
                          icon: Icons.emoji_events_rounded,
                          onTap: () => _showEditGoalDialog(
                            context,
                            ref,
                            title: 'Total Goal',
                            currentValueMantras: settings.totalGoal,
                            onSave: (val) => ref.read(userSettingsProvider.notifier).updateSettings(totalGoal: val),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title: Data adjustment
                  _buildSectionHeader(context, 'PRACTICE OFFSET', Icons.tune_rounded),
                  Card(
                    child: _buildSettingTile(
                      context,
                      title: 'Manual Starting Offset',
                      subtitle:
                          '+${(settings.totalOffset / 108.0).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} malas (+${NumberFormat('#,###').format(settings.totalOffset)} mantras) prior count',
                      icon: Icons.history_rounded,
                      onTap: () => _showEditGoalDialog(
                        context,
                        ref,
                        title: 'Starting Count Offset',
                        currentValueMantras: settings.totalOffset,
                        onSave: (val) => ref.read(userSettingsProvider.notifier).updateSettings(totalOffset: val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title: Preferences Section
                  _buildSectionHeader(context, 'PREFERENCES', Icons.palette_rounded),
                  Card(
                    child: SwitchListTile(
                      value: settings.isDarkMode,
                      onChanged: (val) => ref.read(userSettingsProvider.notifier).updateSettings(isDarkMode: val),
                      title: const Text(
                        'Dark Aesthetic',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        settings.isDarkMode ? 'Using dark contrast theme' : 'Using light clean theme',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      activeThumbColor: theme.colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title: Backup Section
                  _buildSectionHeader(context, 'BACKUP & RESTORE', Icons.cloud_sync_rounded),
                  Card(
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context,
                          title: 'Export Local Backup',
                          subtitle: 'Save a copy of your logs to device Downloads folder',
                          icon: Icons.upload_file_rounded,
                          onTap: () => _exportBackup(context, ref),
                        ),
                        Divider(height: 1, indent: 64, color: theme.dividerColor.withValues(alpha: 0.5)),
                        _buildSettingTile(
                          context,
                          title: 'Import Local Backup',
                          subtitle: 'Restore practice records and targets from JSON backup',
                          icon: Icons.file_download_rounded,
                          onTap: () => _importBackup(context, ref),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title: Danger Zone Section
                  _buildSectionHeader(context, 'DANGER ZONE', Icons.warning_amber_rounded,
                      color: Colors.redAccent.withValues(alpha: 0.8)),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.2),
                    ),
                    color: Colors.redAccent.withValues(alpha: 0.04),
                    child: _buildSettingTile(
                      context,
                      title: 'Reset All Data',
                      subtitle: 'Permanently wipe all session histories, offsets, and goals',
                      icon: Icons.delete_forever_rounded,
                      iconColor: Colors.redAccent,
                      textColor: Colors.redAccent,
                      onTap: () => _confirmReset(context, ref),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error loading configurations: $e')),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, {Color? color}) {
    final theme = Theme.of(context);
    final headerColor = color ?? theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6);

    return Padding(
      padding: const EdgeInsets.only(left: 6.0, bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: headerColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: headerColor,
              letterSpacing: 1.1,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (iconColor ?? primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: iconColor ?? primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: textColor ?? theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
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
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
