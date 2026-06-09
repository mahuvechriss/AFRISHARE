import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/device_model.dart';
import '../services/discovery_service.dart';

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
  }) =>
      DiscoveryState(
        devices: devices ?? this.devices,
        isDiscovering: isDiscovering ?? this.isDiscovering,
        isScanning: isScanning ?? this.isScanning,
        error: error,
      );
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  final DiscoveryService _discoveryService;

  DiscoveryNotifier(this._discoveryService) : super(const DiscoveryState());

  Future<void> startDiscovery() async {
    state = state.copyWith(isDiscovering: true);
    await _discoveryService.startDiscovery();

    _discoveryService.onDeviceDiscovered = (device) {
      _updateDevices();
    };
    _discoveryService.onDeviceUpdated = (device) {
      _updateDevices();
    };
    _discoveryService.onDeviceLost = (deviceId) {
      _updateDevices();
    };
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
    state = state.copyWith(
      devices: _discoveryService.discoveredDevices,
    );
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
