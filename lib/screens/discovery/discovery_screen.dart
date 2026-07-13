import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/discovery_provider.dart';
import '../../services/nearby_connector.dart';
import '../../widgets/device/device_tile.dart';
import '../../widgets/common/empty_state.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final NearbyConnector _connector = NearbyConnector.instance;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(discoveryStateProvider.notifier).startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          _buildConnectionGuideCard(isDark),
          DeviceDiscoveryCard(
            isDiscovering: discoveryState.isDiscovering,
            deviceCount: discoveryState.devices.length,
            onToggle: () async {
              if (discoveryState.isDiscovering) {
                ref.read(discoveryStateProvider.notifier).stopDiscovery();
              } else {
                final messenger = ScaffoldMessenger.of(context);
                final location = await Permission.locationWhenInUse.request();
                if (!location.isGranted) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Location permission is required to discover nearby devices'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }
                  return;
                }
                ref.read(discoveryStateProvider.notifier).startDiscovery();
              }
            },
            onManualSearch: () {
              ref.read(discoveryStateProvider.notifier).searchDevices();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nearby Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  '${discoveryState.devices.length} found',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: discoveryState.devices.isEmpty
                ? const EmptyStateWidget(
                    icon: Icons.devices_rounded,
                    title: 'No devices found',
                    subtitle: 'Make sure both devices have discovery enabled\nand are on the same network',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: discoveryState.devices.length,
                    itemBuilder: (context, index) {
                      final device = discoveryState.devices[index];
                      return DeviceTile(
                        device: device,
                        onTap: () => _connectToDevice(device.deviceId),
                        onPair: () =>
                            ref.read(discoveryStateProvider.notifier).pairDevice(device.deviceId),
                        onBlock: () =>
                            ref.read(discoveryStateProvider.notifier).blockDevice(device.deviceId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _connectToDevice(String deviceId) {
    if (!mounted) return;
    ref.read(discoveryStateProvider.notifier).pairDevice(deviceId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Connecting to device...'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildConnectionGuideCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryGreen, AppColors.primaryBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Connect & Share',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Active', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStep(1, 'Both devices must be on the same WiFi network', isDark),
          const SizedBox(height: 6),
          _buildStep(2, 'Keep this tab open — devices auto-discover each other', isDark),
          const SizedBox(height: 6),
          _buildStep(3, 'Or open Send tab, pick files, and tap a device to send', isDark),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your IP', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.wifi, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _connector.localIp ?? 'Not connected',
                        style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int step, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text('$step', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9), height: 1.3)),
        ),
      ],
    );
  }
}
