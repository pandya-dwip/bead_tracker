import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          title: Text('Edit $title'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set target goals using rounds or repetitions. Changing either field updates the other.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 20),
                // Mala Field
                TextFormField(
                  controller: malasController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    labelText: 'Mala Rounds',
                    suffixText: 'rounds',
                    prefixIcon: const Icon(Icons.refresh_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                  decoration: InputDecoration(
                    labelText: 'Mantra Repetitions',
                    suffixText: 'mantras',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final finalMantras = int.parse(mantrasController.text);
                  onSave(finalMantras);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
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

      // 2. Save directly to the system Downloads folder (on Android/iOS/Windows/etc.)
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
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                SizedBox(width: 8),
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
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
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
      // 1. Pick file
      final FilePickerResult? result = await FilePicker.pickFiles(
        dialogTitle: 'Select bead_tracker_backup.json file',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        // User cancelled
        return;
      }

      final path = result.files.single.path!;
      final file = File(path);
      final content = await file.readAsString();

      // 2. Parse and Validate JSON
      final Map<String, dynamic> backupData = jsonDecode(content) as Map<String, dynamic>;

      if (backupData['settings'] == null || backupData['entries'] == null) {
        throw const FormatException('Invalid backup file structure: missing settings or entries.');
      }

      final settingsJson = backupData['settings'] as Map<String, dynamic>;
      final entriesJson = backupData['entries'] as List<dynamic>;

      final importedSettings = UserSettings.fromJson(settingsJson);
      final importedEntries = entriesJson
          .map((e) => DailyEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // 3. Confirm import (overwrites all data)
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Import?'),
            content: const Text(
              'Importing this backup will overwrite all current daily logs, sessions, offsets, and restore goal configurations from the backup file. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary),
                child: const Text('Restore Data'),
              ),
            ],
          ),
        );

        if (confirm != true) return;
      }

      // Show loading spinner
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Restoring backup...'),
              ],
            ),
          ),
        );
      }

      // Restore to database
      await ref.read(dailyEntriesProvider.notifier).restoreBackup(importedSettings, importedEntries);
      await ref.read(userSettingsProvider.notifier).loadSettings();

      // Close loading spinner
      if (context.mounted) {
        Navigator.of(context).pop();
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.green),
                SizedBox(width: 8),
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
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                SizedBox(width: 8),
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
        title: const Text('Reset All Data?'),
        content: const Text(
          'This will permanently delete all daily logs, sessions, offsets, and restore goals to default. This action cannot be reversed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(dailyEntriesProvider.notifier).resetAll();
      // Wipe settings and restore defaults (Mantra-based goals)
      await ref.read(userSettingsProvider.notifier).updateSettings(
            dailyGoal: 216,
            monthlyGoal: 5400,
            totalGoal: 150000,
            totalOffset: 0,
            isDarkMode: true,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('App data reset successfully'),
            backgroundColor: Colors.redAccent,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title: Goals Section
                  _buildSectionHeader(context, 'GOALS'),
                  Card(
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context,
                          title: 'Daily Practice Goal',
                          subtitle: '${(settings.dailyGoal / 108.0).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} malas (${settings.dailyGoal} mantras)',
                          icon: Icons.today_rounded,
                          onTap: () => _showEditGoalDialog(
                            context,
                            ref,
                            title: 'Daily Goal',
                            currentValueMantras: settings.dailyGoal,
                            onSave: (val) => ref
                                .read(userSettingsProvider.notifier)
                                .updateSettings(dailyGoal: val),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildSettingTile(
                          context,
                          title: 'Monthly Practice Goal',
                          subtitle: '${(settings.monthlyGoal / 108.0).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} malas (${settings.monthlyGoal} mantras)',
                          icon: Icons.calendar_month_rounded,
                          onTap: () => _showEditGoalDialog(
                            context,
                            ref,
                            title: 'Monthly Goal',
                            currentValueMantras: settings.monthlyGoal,
                            onSave: (val) => ref
                                .read(userSettingsProvider.notifier)
                                .updateSettings(monthlyGoal: val),
                          ),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildSettingTile(
                          context,
                          title: 'Total Practice Goal',
                          subtitle: '${(settings.totalGoal / 108.0).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} malas (${settings.totalGoal} mantras)',
                          icon: Icons.emoji_events_rounded,
                          onTap: () => _showEditGoalDialog(
                            context,
                            ref,
                            title: 'Total Goal',
                            currentValueMantras: settings.totalGoal,
                            onSave: (val) => ref
                                .read(userSettingsProvider.notifier)
                                .updateSettings(totalGoal: val),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title: Data adjustment
                  _buildSectionHeader(context, 'DATA ADJUSTMENTS'),
                  Card(
                    child: _buildSettingTile(
                      context,
                      title: 'Manual Count Offset',
                      subtitle: '+${(settings.totalOffset / 108.0).toStringAsFixed(1).replaceAll(RegExp(r"\.0$"), "")} malas (+${settings.totalOffset} mantras) starting offset',
                      icon: Icons.add_moderator_rounded,
                      onTap: () => _showEditGoalDialog(
                        context,
                        ref,
                        title: 'Starting Count Offset',
                        currentValueMantras: settings.totalOffset,
                        onSave: (val) => ref
                            .read(userSettingsProvider.notifier)
                            .updateSettings(totalOffset: val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title: Preferences Section
                  _buildSectionHeader(context, 'PREFERENCES'),
                  Card(
                    child: SwitchListTile(
                      value: settings.isDarkMode,
                      onChanged: (val) => ref
                          .read(userSettingsProvider.notifier)
                          .updateSettings(isDarkMode: val),
                      title: const Text(
                        'Dark Theme',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        settings.isDarkMode ? 'Using dark aesthetic' : 'Using light aesthetic',
                      ),
                      secondary: Icon(
                        settings.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      activeColor: theme.colorScheme.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title: Backup Section
                  _buildSectionHeader(context, 'BACKUP & RESTORE'),
                  Card(
                    child: Column(
                      children: [
                        _buildSettingTile(
                          context,
                          title: 'Export Local Backup',
                          subtitle: 'Save a backup of your logs to local storage',
                          icon: Icons.cloud_upload_rounded,
                          onTap: () => _exportBackup(context, ref),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildSettingTile(
                          context,
                          title: 'Import Local Backup',
                          subtitle: 'Restore entries and settings from backup file',
                          icon: Icons.cloud_download_rounded,
                          onTap: () => _importBackup(context, ref),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title: Reset Section
                  _buildSectionHeader(context, 'DANGER ZONE'),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                    child: _buildSettingTile(
                      context,
                      title: 'Reset All Data',
                      subtitle: 'Wipe all histories, entries, and settings',
                      icon: Icons.delete_forever_rounded,
                      iconColor: Colors.redAccent,
                      textColor: Colors.redAccent,
                      onTap: () => _confirmReset(context, ref),
                    ),
                  ),
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
          letterSpacing: 1.2,
        ),
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
      leading: Icon(
        icon,
        color: iconColor ?? primary,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor ?? theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodyMedium,
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
