import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/storage_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _usernameController = TextEditingController();

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
                      backgroundImage:
                          authState.user?.profilePicture != null
                              ? FileImage(
                                  File(authState.user!.profilePicture!),
                                )
                              : null,
                      child: authState.user?.profilePicture == null
                          ? Text(
                              (authState.user?.username ?? 'U')[0]
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
                      ref.read(authStateProvider.notifier).updateProfile(
                            username: _usernameController.text,
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
                  trailing: authState.isGuest ? null : const Icon(Icons.check, color: AppColors.success),
                  onTap: () {
                    if (authState.isGuest) {
                      _showCreateAccountDialog();
                    }
                  },
                ),
                const Divider(height: 1, indent: 56),
                _SettingsTile(
                  icon: Icons.devices_outlined,
                  title: 'Device Name',
                  subtitle: authState.user?.deviceName ?? 'My Device',
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
            child: Column(
              children: [
                RadioListTile<ThemeModePreference>(
                  title: const Text('Light Mode'),
                  subtitle: const Text('Always use light theme'),
                  value: ThemeModePreference.light,
                  groupValue: themeMode,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeProvider.notifier).setLightMode();
                    }
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<ThemeModePreference>(
                  title: const Text('Dark Mode'),
                  subtitle: const Text('Always use dark theme'),
                  value: ThemeModePreference.dark,
                  groupValue: themeMode,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeProvider.notifier).setDarkMode();
                    }
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                RadioListTile<ThemeModePreference>(
                  title: const Text('System Default'),
                  subtitle: const Text('Follow system theme'),
                  value: ThemeModePreference.system,
                  groupValue: themeMode,
                  activeColor: AppColors.primaryGreen,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeProvider.notifier).setSystemMode();
                    }
                  },
                ),
              ],
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
                  value: false,
                  onChanged: (value) {},
                ),
                const Divider(height: 1, indent: 56),
                _SettingsSwitchTile(
                  icon: Icons.lock_outline,
                  title: 'End-to-End Encryption',
                  subtitle: 'Encrypt all transfers with AES-256',
                  value: true,
                  onChanged: (value) {},
                ),
                const Divider(height: 1, indent: 56),
                _SettingsSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'Transfer Notifications',
                  subtitle: 'Get notified about transfer events',
                  value: true,
                  onChanged: (value) {},
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
                  value: false,
                  onChanged: (value) {},
                ),
                const Divider(height: 1, indent: 56),
                _SettingsSwitchTile(
                  icon: Icons.wifi_find_outlined,
                  title: 'Enable Discovery',
                  subtitle: 'Allow others to find your device',
                  value: true,
                  onChanged: (value) {},
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
                      onPressed: () => ref.read(storageStateProvider.notifier).clearCache(),
                      child: const Text('Clear Cache'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (storageState.stats != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (storageState.stats!['totalSize'] as int) /
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
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SettingsSwitchTile(
                  icon: Icons.auto_delete_outlined,
                  title: 'Auto-Cleanup',
                  subtitle: 'Automatically remove old transfers',
                  value: true,
                  onChanged: (value) {},
                ),
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
                  icon: Icons.description_outlined,
                  title: 'Open Source Licenses',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'AfriShare',
                    applicationVersion: '1.0.0',
                  ),
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
                ref.read(authStateProvider.notifier).register(
                      username: nameController.text,
                      email: emailController.text.isNotEmpty
                          ? emailController.text
                          : null,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
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
                ref.read(authStateProvider.notifier).updateProfile(
                      deviceName: controller.text,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            )
          : null,
      trailing: trailing ?? (onTap != null
          ? const Icon(Icons.chevron_right, size: 22)
          : null),
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
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.primaryGreen,
      ),
    );
  }
}
