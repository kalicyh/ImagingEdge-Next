import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/logger.dart';
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
  final String? lastWiFiSsid;
  final String? lastWiFiPassword;
  final bool? lastWiFiHidden;

  const CameraState({
    this.connectionState = ConnectionState.disconnected,
    this.camera,
    this.errorMessage,
    this.lastWiFiSsid,
    this.lastWiFiPassword,
    this.lastWiFiHidden,
  });

  CameraState copyWith({
    ConnectionState? connectionState,
    CameraModel? camera,
    String? errorMessage,
    String? lastWiFiSsid,
    String? lastWiFiPassword,
    bool? lastWiFiHidden,
    bool clearLastWiFi = false,
  }) {
    return CameraState(
      connectionState: connectionState ?? this.connectionState,
      camera: camera ?? this.camera,
      errorMessage: errorMessage ?? this.errorMessage,
      lastWiFiSsid: clearLastWiFi ? null : (lastWiFiSsid ?? this.lastWiFiSsid),
      lastWiFiPassword:
          clearLastWiFi ? null : (lastWiFiPassword ?? this.lastWiFiPassword),
      lastWiFiHidden:
          clearLastWiFi ? null : (lastWiFiHidden ?? this.lastWiFiHidden),
    );
  }

  bool get isConnected => connectionState == ConnectionState.connected;
  bool get isConnecting => connectionState == ConnectionState.connecting;
  bool get hasError => connectionState == ConnectionState.error;
}

/// Camera provider implementation
class CameraNotifier extends Notifier<CameraState> {
  static const wifiErrorMessageCode = 'camera_wifi_error';

  AppSettings? _settings;
  ImagingEdgeService? _service;
  Timer? _connectionTimer;
  bool _initialized = false;

  @override
  CameraState build() {
    _syncSettings();
    return const CameraState();
  }

  void _syncSettings() {
    if (_initialized) {
      return;
    }

    _initialized = true;

    final currentSettings = ref.read(settingsProvider);
    _applySettings(currentSettings);

    ref.listen<AppSettings>(
      settingsProvider,
      (previous, next) => _applySettings(next),
      fireImmediately: false,
    );

    ref.onDispose(() {
      _stopDaemonMode();
    });
  }

  void _applySettings(AppSettings settings) {
    _settings = settings;
    _initializeService();
  }

  void _initializeService() {
    final settings = _settings;
    if (settings == null) {
      _service = null;
      return;
    }

    _service = ImagingEdgeService(
      address: settings.cameraAddress,
      port: settings.cameraPort,
      debug: settings.debugMode,
    );
  }

  /// Connect to camera
  Future<void> connect({Map<String, String>? wifiInfo}) async {
    final settings = _settings;
    if (_service == null || settings == null) return;
    
    state = state.copyWith(
      connectionState: ConnectionState.connecting,
      errorMessage: null,
    );

    if (wifiInfo != null) {
      state = state.copyWith(
        lastWiFiSsid: wifiInfo['ssid'],
        lastWiFiPassword: wifiInfo['password'],
        lastWiFiHidden: wifiInfo['hidden'] == 'true',
      );
    }

    try {
      final camera = await _service!.getServiceInfo();
      
      state = state.copyWith(
        connectionState: ConnectionState.connected,
        camera: camera,
        errorMessage: null,
        clearLastWiFi: true,
      );

      // Show notification if enabled
      if (settings.notificationsEnabled) {
        await NotificationService.showTransferStartNotification(
          localeCode: settings.localeCode,
        );
      }

      // Start daemon mode if enabled
      if (settings.daemonMode) {
        _startDaemonMode();
      }
    } catch (e, stack) {
      if (settings.debugMode) {
        logDebug('Camera connection failed: $e');
      } else {
        logWarning('Camera connection failed', error: e, stackTrace: stack);
      }
      state = state.copyWith(
        connectionState: ConnectionState.error,
        errorMessage: wifiErrorMessageCode,
      );

      // Show error notification if enabled
      if (settings.notificationsEnabled) {
        await NotificationService.showConnectionErrorNotification(
          localeCode: settings.localeCode,
        );
      }
    }
  }

  Future<bool> retryLastWifi() async {
    final ssid = state.lastWiFiSsid;
    if (ssid == null) {
      return false;
    }

    final password = state.lastWiFiPassword ?? '';
    final hidden = state.lastWiFiHidden ?? false;

    final wifiConnected = await QRScannerService.connectToWiFi(
      ssid,
      password,
      hidden: hidden,
    );

    if (!wifiConnected) {
      return false;
    }

    await connect(wifiInfo: {
      'ssid': ssid,
      'password': password,
      'hidden': hidden.toString(),
    });

    return true;
  }

  /// Disconnect from camera
  Future<void> disconnect() async {
    _stopDaemonMode();
    
    final settings = _settings;
    if (_service != null && state.isConnected) {
      try {
        await _service!.endTransfer();
        
        // Show notification if enabled
        if (settings?.notificationsEnabled ?? false) {
          await NotificationService.showTransferEndNotification(
            localeCode: settings!.localeCode,
          );
        }
      } catch (e, stack) {
        // Ignore errors when disconnecting
        logWarning('Error ending transfer', error: e, stackTrace: stack);
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

}

/// Camera provider
final cameraProvider = NotifierProvider<CameraNotifier, CameraState>(
  CameraNotifier.new,
);
