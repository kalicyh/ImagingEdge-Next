import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'settings_provider.dart';

/// Camera connection state
enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Camera provider state
class CameraState {
  final ConnectionState connectionState;
  final CameraModel? camera;
  final String? errorMessage;

  const CameraState({
    this.connectionState = ConnectionState.disconnected,
    this.camera,
    this.errorMessage,
  });

  CameraState copyWith({
    ConnectionState? connectionState,
    CameraModel? camera,
    String? errorMessage,
  }) {
    return CameraState(
      connectionState: connectionState ?? this.connectionState,
      camera: camera ?? this.camera,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isConnected => connectionState == ConnectionState.connected;
  bool get isConnecting => connectionState == ConnectionState.connecting;
  bool get hasError => connectionState == ConnectionState.error;
}

/// Camera provider implementation
class CameraNotifier extends StateNotifier<CameraState> {
  static const wifiErrorMessageCode = 'camera_wifi_error';
  CameraNotifier(this._settings) : super(const CameraState()) {
    _initializeService();
  }

  AppSettings _settings;
  ImagingEdgeService? _service;
  Timer? _connectionTimer;

  void _initializeService() {
    _service = ImagingEdgeService(
      address: _settings.cameraAddress,
      port: _settings.cameraPort,
      debug: _settings.debugMode,
    );
  }

  /// Update service when settings change
  void updateSettings(AppSettings settings) {
    _service = ImagingEdgeService(
      address: settings.cameraAddress,
      port: settings.cameraPort,
      debug: settings.debugMode,
    );
    _settings = settings;
  }

  /// Connect to camera
  Future<void> connect() async {
    if (_service == null) return;
    
    state = state.copyWith(
      connectionState: ConnectionState.connecting,
      errorMessage: null,
    );

    try {
      final camera = await _service!.getServiceInfo();
      
      state = state.copyWith(
        connectionState: ConnectionState.connected,
        camera: camera,
        errorMessage: null,
      );

      // Show notification if enabled
      if (_settings.notificationsEnabled) {
        await NotificationService.showTransferStartNotification(
          localeCode: _settings.localeCode,
        );
      }

      // Start daemon mode if enabled
      if (_settings.daemonMode) {
        _startDaemonMode();
      }
    } catch (e) {
      if (_settings.debugMode) {
        print('Camera connection failed: $e');
      }
      state = state.copyWith(
        connectionState: ConnectionState.error,
        errorMessage: wifiErrorMessageCode,
      );

      // Show error notification if enabled
      if (_settings.notificationsEnabled) {
        await NotificationService.showConnectionErrorNotification(
          localeCode: _settings.localeCode,
        );
      }
    }
  }

  /// Disconnect from camera
  Future<void> disconnect() async {
    _stopDaemonMode();
    
    if (_service != null && state.isConnected) {
      try {
        await _service!.endTransfer();
        
        // Show notification if enabled
        if (_settings.notificationsEnabled) {
          await NotificationService.showTransferEndNotification(
            localeCode: _settings.localeCode,
          );
        }
      } catch (e) {
        // Ignore errors when disconnecting
        print('Error ending transfer: $e');
      }
    }

    state = state.copyWith(
      connectionState: ConnectionState.disconnected,
      camera: null,
      errorMessage: null,
    );
  }

  /// Check if camera is reachable
  Future<bool> isReachable() async {
    if (_service == null) return false;
    return await _service!.isReachable();
  }

  /// Start daemon mode - periodically check connection
  void _startDaemonMode() {
    _stopDaemonMode(); // Stop any existing timer
    
    _connectionTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!state.isConnected) {
        final reachable = await isReachable();
        if (reachable) {
          await connect();
        }
      }
    });
  }

  /// Stop daemon mode
  void _stopDaemonMode() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

  @override
  void dispose() {
    _stopDaemonMode();
    super.dispose();
  }
}

/// Camera provider
final cameraProvider = StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  final settings = ref.watch(settingsProvider);
  final notifier = CameraNotifier(settings);
  
  // Listen to settings changes
  ref.listen(settingsProvider, (previous, next) {
    notifier.updateSettings(next);
  });
  
  return notifier;
});
