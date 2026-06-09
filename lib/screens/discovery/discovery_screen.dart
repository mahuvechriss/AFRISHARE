import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/discovery_provider.dart';
import '../../services/qr_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/device/device_tile.dart';
import '../../widgets/common/empty_state.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final QRService _qrService = QRService.instance;
  bool _showQRCode = false;

  @override
  void initState() {
    super.initState();
    // Auto-start discovery
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
          // QR Code Section
          if (_showQRCode) _buildQRCodeSection(),

          // Discovery Controls
          DeviceDiscoveryCard(
            isDiscovering: discoveryState.isDiscovering,
            deviceCount: discoveryState.devices.length,
            onToggle: () {
              if (discoveryState.isDiscovering) {
                ref.read(discoveryStateProvider.notifier).stopDiscovery();
              } else {
                ref.read(discoveryStateProvider.notifier).startDiscovery();
              }
            },
            onManualSearch: () {
              ref.read(discoveryStateProvider.notifier).searchDevices();
            },
          ),

          // QR Code Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showQRCode = !_showQRCode),
                  icon: Icon(
                    _showQRCode ? Icons.close : Icons.qr_code_scanner,
                    size: 20,
                  ),
                  label: Text(_showQRCode ? 'Hide QR' : 'QR Pairing'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _showScanner(),
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: const Text('Scan QR'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Device List Header
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
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Device List
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

  Widget _buildQRCodeSection() {
    final authService = AuthService.instance;
    final qrData = _qrService.generatePairingData(
      authService.deviceId,
      authService.currentUser?.deviceName ?? 'My Device',
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Share this QR code',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ask the other device to scan this code',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _qrService.generateQRWidget(
              data: qrData,
              size: 200,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            authService.currentUser?.deviceName ?? 'My Device',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  void _showScanner() {
    // In a real app, this would open the mobile_scanner
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('QR Scanner ready'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _connectToDevice(String deviceId) {
    ref.read(discoveryStateProvider.notifier).pairDevice(deviceId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Connecting to device...'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
