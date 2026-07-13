import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/storage_provider.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/cloud_relay_service.dart';
import '../../services/nearby_connector.dart';
import '../../services/discovery_service.dart';
import '../../services/network_discovery_service.dart';
import '../../services/http_transfer_service.dart';
import '../../services/sound_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _autoAcceptTransfers = false;
  bool _encryptionEnabled = true;
  bool _transferNotifications = true;
  bool _deviceHidden = false;
  bool _discoveryEnabled = true;
  bool _autoCleanup = true;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).user;
    _usernameController.text = user?.username ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeProvider);
    final storageState = ref.watch(storageStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppColors.primaryGreenSurface,
                      backgroundImage: authState.user?.profilePicture != null
                          ? FileImage(File(authState.user!.profilePicture!))
                          : null,
                      child: authState.user?.profilePicture == null
                          ? Text(
                              ((authState.user?.username ?? '').isNotEmpty
                                      ? authState.user!.username[0]
                                      : 'U')
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryGreen,
                              ),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryGreen,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'Username',
                    prefixIcon: const Icon(Icons.person_outline, size: 22),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final newName = _usernameController.text;
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Change Name'),
                          content: Text(
                            'Do you want to change your registered name to "$newName"?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ref
                                    .read(authStateProvider.notifier)
                                    .updateProfile(
                                      username: newName,
                                      deviceName: newName,
                                    );
                                NearbyConnector.instance
                                    .updateDeviceName(newName);
                                HttpTransferService.instance
                                    .updateDeviceName(newName);
                                NetworkDiscoveryService.instance
                                    .updateDeviceName(newName);
                              },
                              child: const Text('Change'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Profile'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Section
          _SectionHeader(title: 'Account'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_add_outlined,
                  title: 'Create Account',
                  subtitle: authState.isGuest
                      ? 'Guest mode active'
                      : 'Registered user',
                  trailing: authState.isGuest
                      ? null
                      : const Icon(Icons.check, color: AppColors.success),
                  onTap: () {
                    if (authState.isGuest) {
                      _showCreateAccountDialog();
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.phone_android_outlined,
                  title: 'Device Name',
                  subtitle:
                      authState.user?.deviceName ??
                      AuthService.instance.deviceModelName,
                  onTap: () => _showEditDeviceNameDialog(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: RadioGroup<ThemeModePreference>(
              groupValue: themeMode,
              onChanged: (value) {
                if (value == ThemeModePreference.light) {
                  ref.read(themeProvider.notifier).setLightMode();
                } else if (value == ThemeModePreference.dark) {
                  ref.read(themeProvider.notifier).setDarkMode();
                } else if (value == ThemeModePreference.system) {
                  ref.read(themeProvider.notifier).setSystemMode();
                }
              },
              child: Column(
                children: [
                  RadioListTile<ThemeModePreference>(
                    title: const Text('Light Mode'),
                    subtitle: const Text('Always use light theme'),
                    value: ThemeModePreference.light,
                    activeColor: AppColors.primaryGreen,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<ThemeModePreference>(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Always use dark theme'),
                    value: ThemeModePreference.dark,
                    activeColor: AppColors.primaryGreen,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<ThemeModePreference>(
                    title: const Text('System Default'),
                    subtitle: const Text('Follow system theme'),
                    value: ThemeModePreference.system,
                    activeColor: AppColors.primaryGreen,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transfer Settings Section
          _SectionHeader(title: 'Transfers'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                _SettingsSwitchTile(
                  icon: Icons.autorenew_rounded,
                  title: 'Auto-Accept Transfers',
                  subtitle: 'Automatically accept incoming files',
                  value: _autoAcceptTransfers,
                  onChanged: (value) =>
                      setState(() => _autoAcceptTransfers = value),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsSwitchTile(
                  icon: Icons.lock_outline,
                  title: 'End-to-End Encryption',
                  subtitle: 'End-to-end encrypt all transfers',
                  value: _encryptionEnabled,
                  onChanged: (value) =>
                      setState(() => _encryptionEnabled = value),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'Transfer Notifications',
                  subtitle: 'Get notified about transfer events',
                  value: _transferNotifications,
                  onChanged: (value) =>
                      setState(() => _transferNotifications = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sound Settings Section
          _SectionHeader(title: 'Sounds'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_active_outlined,
                  title: 'Message Sound',
                  subtitle: SoundService.instance.notificationSound ==
                          'notification.wav'
                      ? 'Default Chime'
                      : SoundService.instance.notificationSound ==
                              'notification_alt.wav'
                          ? 'Soft Tone'
                          : 'Two-Tone',
                  onTap: () => _showSoundPicker(
                    title: 'Message Sound',
                    options: SoundService.notificationOptions,
                    current: SoundService.instance.notificationSound,
                    onSelect: (value) {
                      SoundService.instance.setNotificationSound(value);
                      setState(() {});
                    },
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.check_circle_outline,
                  title: 'Transfer Sound',
                  subtitle: SoundService.instance.transferSound ==
                          'transfer_complete.wav'
                      ? 'Default Ding'
                      : SoundService.instance.transferSound ==
                              'transfer_alt.wav'
                          ? 'Deep Tone'
                          : 'Chriss',
                  onTap: () => _showSoundPicker(
                    title: 'Transfer Sound',
                    options: SoundService.transferOptions,
                    current: SoundService.instance.transferSound,
                    onSelect: (value) {
                      SoundService.instance.setTransferSound(value);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Privacy Section
          _SectionHeader(title: 'Privacy'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                _SettingsSwitchTile(
                  icon: Icons.visibility_off_outlined,
                  title: 'Hide Device',
                  subtitle: 'Make device invisible to others',
                  value: _deviceHidden,
                  onChanged: (value) {
                    setState(() => _deviceHidden = value);
                    DiscoveryService.instance.setDeviceHidden(value);
                  },
                ),
                const Divider(height: 1, indent: 56),
                _SettingsSwitchTile(
                  icon: Icons.wifi_find_outlined,
                  title: 'Enable Discovery',
                  subtitle: 'Allow others to find your device',
                  value: _discoveryEnabled,
                  onChanged: (value) {
                    setState(() => _discoveryEnabled = value);
                    DiscoveryService.instance.setDiscoveryEnabled(value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cloud Relay Section
          _SectionHeader(title: 'Cloud Relay'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_outlined,
                        color: Colors.orange,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Relay Server',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Server URL used for remote file sharing via cloud relay.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(
                    text: CloudRelayService.instance.serverUrl,
                  ),
                  decoration: InputDecoration(
                    hintText: 'http://your-server:3000',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check, size: 20),
                      onPressed: () {
                        // In production, save to shared_preferences
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Server URL updated'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Storage Section
          _SectionHeader(title: 'Storage'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Storage Usage',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(storageStateProvider.notifier).clearCache(),
                      child: const Text('Clear Cache'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (storageState.stats != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value:
                          (storageState.stats!['totalSize'] as int) /
                          1073741824,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    storageState.stats!['totalSizeFormatted'] as String? ??
                        '0 B',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 12),
                _SettingsSwitchTile(
                  icon: Icons.auto_delete_outlined,
                  title: 'Auto-Cleanup',
                  subtitle: 'Automatically remove old transfers',
                  value: _autoCleanup,
                  onChanged: (value) => setState(() => _autoCleanup = value),
                ),
                const Divider(height: 24),
                _buildStoragePathInfo(isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // About Section
          _SectionHeader(title: 'About'),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'Version',
                  subtitle: '1.0.0',
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Developer',
                  subtitle: 'Christian Mahuve',
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Open Source Licenses',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'AfriShare',
                    applicationVersion: '1.0.0',
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.share_rounded,
                  title: 'Share AfriShare',
                  subtitle: 'Send the APK to nearby devices',
                  onTap: _shareApk,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showCreateAccountDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                final name = nameController.text;
                ref
                    .read(authStateProvider.notifier)
                    .register(
                      username: name,
                      email: emailController.text.isNotEmpty
                          ? emailController.text
                          : null,
                    );
                NearbyConnector.instance.updateDeviceName(name);
                        HttpTransferService.instance.updateDeviceName(name);
                        NetworkDiscoveryService.instance.updateDeviceName(name);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (image == null) return;

      final savedPath = await StorageService.instance.saveProfileImage(
        image.path,
      );
      if (savedPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save profile image')),
          );
        }
        return;
      }

      await ref
          .read(authStateProvider.notifier)
          .updateProfile(profilePicture: savedPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _shareApk() async {
    if (!Platform.isAndroid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('APK sharing is only available on Android'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preparing APK...'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      final result = await Process.run('sh', [
        '-c',
        'pm path com.afrishare.afrishare',
      ]);
      final lines = result.stdout.toString().trim().split('\n');
      final apkPaths = <String>[];
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('package:')) {
          apkPaths.add(trimmed.substring(8).trim());
        }
      }

      if (apkPaths.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not locate APK'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final files = <XFile>[];
      for (int i = 0; i < apkPaths.length; i++) {
        final suffix = apkPaths.length > 1 ? '_part$i' : '';
        final dest = '${tempDir.path}/AfriShare$suffix.apk';
        await File(apkPaths[i]).copy(dest);
        files.add(XFile(dest));
      }

      await Share.shareXFiles(
        files,
        subject: 'AfriShare APK',
        text: 'Share files offline via WiFi or remotely via cloud relay.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share APK: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildStoragePathInfo(bool isDark) {
    final path = StorageService.instance.transferPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.folder_outlined,
              color: AppColors.primaryGreen,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Storage Location',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Files are saved here by default',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            path,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'To save copies elsewhere, open a completed transfer and use "Save to..."',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.info.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditDeviceNameDialog() {
    final controller = TextEditingController(
      text: ref.read(authStateProvider).user?.deviceName ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter device name',
            prefixIcon: Icon(Icons.devices),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final deviceName = controller.text;
                ref
                    .read(authStateProvider.notifier)
                    .updateProfile(deviceName: deviceName);
                NearbyConnector.instance.updateDeviceName(deviceName);
                HttpTransferService.instance.updateDeviceName(deviceName);
                NetworkDiscoveryService.instance.updateDeviceName(deviceName);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSoundPicker({
    required String title,
    required List<Map<String, String>> options,
    required String current,
    required ValueChanged<String> onSelect,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: RadioGroup<String>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) {
              onSelect(value);
              SoundService.instance.playSound(value);
              Navigator.pop(ctx);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final opt in options) ...[
                RadioListTile<String>(
                  title: Text(opt['label']!),
                  subtitle: Text(opt['value']!),
                  value: opt['value']!,
                  activeColor: AppColors.primaryGreen,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGreen, size: 24),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            )
          : null,
      trailing:
          trailing ??
          (onTap != null ? const Icon(Icons.chevron_right, size: 22) : null),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryGreen, size: 24),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primaryGreen,
      ),
    );
  }
}
