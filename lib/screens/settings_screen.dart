import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imagingedge_next/l10n/app_localizations.dart';
import 'package:file_selector/file_selector.dart';
import '../providers/providers.dart';
import '../widgets/fluid_dock.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          IconButton(
            onPressed: () {
              _showResetDialog(context, ref);
            },
            icon: const Icon(Icons.restore),
            tooltip: l10n.settingsResetTooltip,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Download Settings Section
          _buildSectionCard(
            context,
            title: l10n.settingsDownloadSection,
            icon: Icons.download,
            children: [
              _buildDirectorySetting(
                context: context,
                ref: ref,
                title: l10n.settingsOutputDirectory,
                subtitle: l10n.settingsOutputDirectorySubtitle,
                value: settings.outputDirectory.isEmpty 
                    ? l10n.settingsOutputDirectoryDefault
                    : settings.outputDirectory,
              ),

              const SizedBox(height: 8),

              _buildInfoTile(
                context: context,
                title: l10n.settingsDownloadQuality,
                subtitle: l10n.settingsDownloadQualitySubtitle,
                icon: Icons.high_quality,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // App Settings Section
          _buildSectionCard(
            context,
            title: l10n.settingsAppSection,
            icon: Icons.settings,
            children: [
              _buildSwitchSetting(
                context: context,
                title: l10n.settingsDebugMode,
                subtitle: l10n.settingsDebugModeSubtitle,
                value: settings.debugMode,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setDebugMode(value);
                },
              ),

              _buildSwitchSetting(
                context: context,
                title: l10n.settingsNotifications,
                subtitle: l10n.settingsNotificationsSubtitle,
                value: settings.notificationsEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setNotificationsEnabled(value);
                },
              ),

              _buildSwitchSetting(
                context: context,
                title: l10n.settingsDaemonMode,
                subtitle: l10n.settingsDaemonModeSubtitle,
                value: settings.daemonMode,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setDaemonMode(value);
                },
              ),

              _buildLanguageSetting(
                context: context,
                ref: ref,
                localeCode: settings.localeCode,
                l10n: l10n,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Camera Settings Section
          _buildSectionCard(
            context,
            title: l10n.settingsCameraSection,
            icon: Icons.camera_alt,
            children: [
              _buildTextSetting(
                context: context,
                title: l10n.settingsCameraIp,
                subtitle: l10n.settingsCameraIpSubtitle,
                value: settings.cameraAddress,
                hintText: l10n.settingsCameraIpHint,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).setCameraAddress(value);
                },
              ),

              _buildNumberSetting(
                context: context,
                title: l10n.settingsCameraPort,
                subtitle: l10n.settingsCameraPortSubtitle,
                value: settings.cameraPort,
                hintText: '64321',
                onChanged: (value) {
                  final port = int.tryParse(value);
                  if (port != null && port > 0 && port <= 65535) {
                    ref.read(settingsProvider.notifier).setCameraPort(port);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // About Section
          _buildSectionCard(
            context,
            title: l10n.settingsAboutSection,
            icon: Icons.info,
            children: [
              _buildInfoTile(
                context: context,
                title: l10n.settingsAboutApp,
                subtitle: l10n.settingsAboutAppSubtitle,
                icon: Icons.photo_camera,
              ),

              _buildInfoTile(
                context: context,
                title: l10n.settingsAboutCompatible,
                subtitle: l10n.settingsAboutCompatibleSubtitle,
                icon: Icons.camera,
              ),

              _buildInfoTile(
                context: context,
                title: l10n.settingsAboutUsage,
                subtitle: l10n.settingsAboutUsageSubtitle,
                icon: Icons.help,
              ),
            ],
          ),
              const SizedBox(height: 120),
        ],
      ),
      bottomNavigationBar: const FluidDock(currentRoute: '/settings'),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextSetting({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String value,
    required String hintText,
    required Function(String) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value,
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberSetting({
    required BuildContext context,
    required String title,
    required String subtitle,
    required int value,
    required String hintText,
    required Function(String) onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: value.toString(),
            decoration: InputDecoration(
              hintText: hintText,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDirectorySetting({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await _pickDirectory(context, ref);
                },
                icon: const Icon(Icons.folder_open),
                label: Text(l10n.settingsBrowse),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  ref.read(settingsProvider.notifier).setOutputDirectory('');
                },
                icon: const Icon(Icons.restore),
                tooltip: l10n.settingsUseDefault,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchSetting({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildInfoTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Future<void> _pickDirectory(BuildContext context, WidgetRef ref) async {
    try {
      final result = await getDirectoryPath();
      if (result != null) {
        ref.read(settingsProvider.notifier).setOutputDirectory(result);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .settingsDirectoryPickFailed(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.settingsResetDialogTitle),
        content: Text(
          AppLocalizations.of(context)!.settingsResetDialogMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.commonCancel),
          ),
          TextButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.settingsResetSuccess,
                  ),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.settingsReset),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSetting({
    required BuildContext context,
    required WidgetRef ref,
    required String localeCode,
    required AppLocalizations l10n,
  }) {
    final normalized = (localeCode.isEmpty || localeCode == 'system')
        ? 'system'
        : localeCode;

    return ListTile(
      title: Text(l10n.settingsLanguage),
      subtitle: Text(l10n.settingsLanguageSubtitle),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: normalized,
          onChanged: (value) {
            if (value == null) return;
            ref.read(settingsProvider.notifier).setLocaleCode(value);
          },
          items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(l10n.commonSystem),
            ),
            DropdownMenuItem(
              value: 'en',
              child: Text(l10n.commonLanguageEnglish),
            ),
            DropdownMenuItem(
              value: 'ja',
              child: Text(l10n.commonLanguageJapanese),
            ),
            DropdownMenuItem(
              value: 'zh',
              child: Text(l10n.commonLanguageChinese),
            ),
          ],
        ),
      ),
    );
  }
}
