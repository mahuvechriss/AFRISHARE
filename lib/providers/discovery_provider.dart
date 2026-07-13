import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../services/discovery_service.dart';
import '../services/profile_picture_service.dart';
import '../core/constants/app_constants.dart';

final discoveryServiceProvider = Provider<DiscoveryService>((ref) {
  return DiscoveryService.instance;
});

final discoveryStateProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
      final discoveryService = ref.read(discoveryServiceProvider);
      return DiscoveryNotifier(discoveryService);
    });

class DiscoveryState {
  final List<DeviceModel> devices;
  final bool isDiscovering;
  final bool isScanning;
  final String? error;

  const DiscoveryState({
    this.devices = const [],
    this.isDiscovering = false,
    this.isScanning = false,
    this.error,
  });

  DiscoveryState copyWith({
    List<DeviceModel>? devices,
    bool? isDiscovering,
    bool? isScanning,
    String? error,
  }) => DiscoveryState(
    devices: devices ?? this.devices,
    isDiscovering: isDiscovering ?? this.isDiscovering,
    isScanning: isScanning ?? this.isScanning,
    error: error,
  );
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final DiscoveryService _discoveryService;

  DiscoveryNotifier(this._discoveryService) : super(const DiscoveryState()) {
    final onDiscovered = _discoveryService.onDeviceDiscovered;
    final onUpdated = _discoveryService.onDeviceUpdated;
    final onLost = _discoveryService.onDeviceLost;

    _discoveryService.onDeviceDiscovered = (device) {
      _updateDevices();
      if (device.ipAddress != null && device.ipAddress!.isNotEmpty) {
        ProfilePictureService.instance.fetch(
          device.deviceId,
          device.ipAddress!,
          device.port ?? AppConstants.discoveryPort,
        );
      }
      return Future.microtask(() async {
        await onDiscovered?.call(device);
      });
    };
    _discoveryService.onDeviceUpdated = (device) {
      onUpdated?.call(device);
      _updateDevices();
    };
    _discoveryService.onDeviceLost = (deviceId) {
      onLost?.call(deviceId);
      _updateDevices();
    };
    _updateDevices();
  }

  Future<void> startDiscovery() async {
    state = state.copyWith(isDiscovering: true);
    await _discoveryService.startDiscovery();
  }

  Future<void> stopDiscovery() async {
    await _discoveryService.stopDiscovery();
    state = state.copyWith(isDiscovering: false);
  }

  Future<void> searchDevices() async {
    state = state.copyWith(isScanning: true);
    await _discoveryService.searchForDevices();
    _updateDevices();
    state = state.copyWith(isScanning: false);
  }

  void _updateDevices() {
    state = state.copyWith(devices: _discoveryService.discoveredDevices);
  }

  void addDevice(DeviceModel device) {
    _discoveryService.addDevice(device);
    _updateDevices();
  }

  void pairDevice(String deviceId) {
    _discoveryService.pairDevice(deviceId);
    _updateDevices();
  }

  void blockDevice(String deviceId) {
    _discoveryService.blockDevice(deviceId);
    _updateDevices();
  }

  void updateDeviceStatus(String deviceId, DeviceStatus status) {
    _discoveryService.updateDeviceStatus(deviceId, status);
    _updateDevices();
  }

  @override
  void dispose() {
    _discoveryService.dispose();
    super.dispose();
  }
}
