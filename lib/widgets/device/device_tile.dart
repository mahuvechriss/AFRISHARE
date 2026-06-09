import 'package:flutter/material.dart';
import '../../models/device_model.dart';
import '../../core/theme/app_colors.dart';

class DeviceTile extends StatelessWidget {
  final DeviceModel device;
  final VoidCallback? onTap;
  final VoidCallback? onPair;
  final VoidCallback? onBlock;
  final bool showActions;

  const DeviceTile({
    super.key,
    required this.device,
    this.onTap,
    this.onPair,
    this.onBlock,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor().withValues(alpha: 0.1),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.devices_rounded,
                        color: _getStatusColor(),
                        size: 24,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(),
                          border: Border.all(
                            color: isDark
                                ? AppColors.surfaceDark
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          device.isPaired
                              ? Icons.link
                              : Icons.link_off,
                          size: 13,
                          color: device.isPaired
                              ? AppColors.primaryGreen
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          device.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(),
                          ),
                        ),
                        if (device.signalStrength > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.wifi,
                            size: 13,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (showActions && device.isConnectable && !device.isPaired)
                _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (device.status) {
      case DeviceStatus.online:
        return AppColors.deviceOnline;
      case DeviceStatus.offline:
        return AppColors.deviceOffline;
      case DeviceStatus.connecting:
        return AppColors.deviceConnecting;
      case DeviceStatus.paired:
        return AppColors.primaryGreen;
    }
  }

  Widget _buildActionButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPair != null)
          IconButton(
            onPressed: onPair,
            icon: const Icon(Icons.link, size: 22),
            color: AppColors.primaryGreen,
            tooltip: 'Pair',
          ),
        if (onBlock != null)
          IconButton(
            onPressed: onBlock,
            icon: const Icon(Icons.block, size: 22),
            color: AppColors.error,
            tooltip: 'Block',
          ),
        if (onPair == null && onBlock == null)
          const SizedBox.shrink(),
      ],
    );
  }
}

class DeviceDiscoveryCard extends StatelessWidget {
  final bool isDiscovering;
  final VoidCallback? onToggle;
  final VoidCallback? onManualSearch;
  final int deviceCount;

  const DeviceDiscoveryCard({
    super.key,
    required this.isDiscovering,
    this.onToggle,
    this.onManualSearch,
    this.deviceCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDiscovering
                    ? AppColors.primaryGreenSurface
                    : Colors.grey.shade100,
              ),
              child: isDiscovering
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  : Icon(
                      Icons.wifi_find,
                      color: Colors.grey.shade600,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDiscovering ? 'Discovering Devices...' : 'Device Discovery',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    deviceCount > 0
                        ? '$deviceCount device${deviceCount == 1 ? '' : 's'} found'
                        : isDiscovering
                            ? 'Searching for nearby devices...'
                            : 'Tap to start scanning',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (onToggle != null)
              Switch(
                value: isDiscovering,
                onChanged: (_) => onToggle!(),
                activeTrackColor: AppColors.primaryGreen,
              ),
            if (onManualSearch != null && !isDiscovering)
              IconButton(
                onPressed: onManualSearch,
                icon: const Icon(Icons.search, size: 22),
                color: AppColors.primaryBlue,
              ),
          ],
        ),
      ),
    );
  }
}
