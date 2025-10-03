import 'dart:async';
import 'dart:io';

import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/logger.dart';

class QRScannerService {
  static const _logName = 'QRScannerService';
  static bool _isScanning = false;
  static const MethodChannel _wifiChannel = MethodChannel('imagingedge/wifi');

  static void _info(String message) => logInfo(message, name: _logName);

  static void _warn(String message, {Object? error, StackTrace? stackTrace}) =>
      logWarning(message, name: _logName, error: error, stackTrace: stackTrace);

  /// Create a scanner controller with sensible defaults for desktop.
  static MobileScannerController createController() {
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 400,
      facing: _defaultCameraFacing(),
      torchEnabled: false,
      formats: const [BarcodeFormat.qrCode],
      autoStart: true,
    );
  }

  /// Check if camera permission is granted.
  static Future<bool> checkCameraPermission() async {
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        return true;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Request camera permission.
  static Future<bool> requestCameraPermission() async {
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        return true;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if camera is available by attempting to start a controller when needed.
  static Future<bool> isCameraAvailable(MobileScannerController controller) async {
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        return true;
      }

      await controller.start();
      return true;
    } on MobileScannerException catch (e) {
      // If the controller is not yet attached, wait a moment and retry once.
      if (e.errorCode == MobileScannerErrorCode.controllerNotAttached) {
        try {
          await Future.delayed(const Duration(milliseconds: 200));
          await controller.start();
          return true;
        } catch (error, stack) {
          _warn('Camera availability retry failed: $error', error: error, stackTrace: stack);
        }
      }
      _warn('Camera availability check failed: ${e.errorCode}', error: e);
      return false;
    } finally {
      // Leave the controller running for the caller to manage.
    }
  }

  /// Parse WiFi QR code formats, supporting escaped characters and Sony W01 payloads.
  static Map<String, String>? parseWiFiQRCode(String data) {
    try {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        return null;
      }

      if (trimmed.startsWith('WIFI:')) {
        final payload = trimmed.substring(5);
        final segments = _splitEscapedSegments(payload);
        if (segments.isEmpty) {
          return null;
        }

        final params = <String, String>{};
        for (final segment in segments) {
          final keyValue = _splitFirstUnescaped(segment, ':');
          if (keyValue == null) continue;
          params[keyValue.$1] = _unescapeWiFiValue(keyValue.$2);
        }

        final ssid = params['S'];
        if (ssid == null) {
          return null;
        }
        return {
          ...params,
          'SSID': ssid,
          'PASSWORD': params['P'] ?? '',
          'HIDDEN': params['H'] ?? params['HIDDEN'] ?? '',
          'FORMAT': 'WIFI',
          'RAW': trimmed,
        };
      }

      if (trimmed.startsWith('W01:')) {
        final payload = trimmed.substring(4);
        final segments = _splitEscapedSegments(payload);
        if (segments.isEmpty) {
          return null;
        }

        final params = <String, String>{};
        for (final segment in segments) {
          final keyValue = _splitFirstUnescaped(segment, ':');
          if (keyValue == null) continue;
          params[keyValue.$1] = _unescapeWiFiValue(keyValue.$2);
        }

        final originalSsid = params['S'];
        final password = params['P'];
        final cameraModel = params['C'];
        if (originalSsid == null || password == null) {
          return null;
        }

        final computedSsid =
            cameraModel != null ? 'DIRECT-$originalSsid:$cameraModel' : originalSsid;
        return {
          ...params,
          'S': computedSsid,
          'SSID': computedSsid,
          'PASSWORD': password,
          'HIDDEN': params['H'] ?? params['HIDDEN'] ?? '',
          'FORMAT': 'W01',
          'RAW': trimmed,
        };
      }

      return null;
    } catch (e, stack) {
      _warn('Failed to parse Wi-Fi QR code: $e', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Parse camera IP QR code (various formats).
  static CameraConnectionInfo? parseCameraQRCode(String rawData) {
    try {
      final data = rawData.trim();
      if (data.isEmpty) {
        return null;
      }

      // Custom CAMERA format e.g. CAMERA:IP:192.168.0.1;PORT:64321;NAME:Alpha
      if (data.startsWith('CAMERA:')) {
        final params = <String, String>{};
        final parts = data.substring(7).split(';');
        for (final part in parts) {
          final separatorIndex = part.indexOf(':');
          if (separatorIndex > 0) {
            final key = part.substring(0, separatorIndex).toUpperCase();
            final value = part.substring(separatorIndex + 1);
            params[key] = value;
          }
        }

        final ip = params['IP'];
        if (ip != null) {
          final port = int.tryParse(params['PORT'] ?? '') ?? 64321;
          final name = params['NAME'] ?? 'Camera';
          return CameraConnectionInfo(
            ipAddress: ip,
            port: port,
            name: name,
            raw: data,
          );
        }
      }

      final uri = Uri.tryParse(data);
      if (uri != null && uri.host.isNotEmpty) {
        final port = uri.hasPort ? uri.port : 64321;
        return CameraConnectionInfo(
          ipAddress: uri.host,
          port: port,
          name: uri.host,
          raw: data,
        );
      }

      // IP with optional port, e.g. 192.168.0.1:64321
      final ipPortMatch = RegExp(
        r'^(?<ip>(?:\d{1,3}\.){3}\d{1,3})(?::(?<port>\d{1,5}))?$',
      ).firstMatch(data);
      if (ipPortMatch != null) {
        final ip = ipPortMatch.namedGroup('ip') ?? '';
        final portStr = ipPortMatch.namedGroup('port');
        final port = portStr != null ? int.tryParse(portStr) ?? 64321 : 64321;
        return CameraConnectionInfo(
          ipAddress: ip,
          port: port,
          name: ip,
          raw: data,
        );
      }

      // Generic key-value payload containing IP / PORT information.
      final normalized = data.replaceAll('=', ':').replaceAll('：', ':');
      if (normalized.toUpperCase().contains('IP')) {
        final segments = normalized.split(RegExp(r'[;\n\r\s]+'));
        String? ip;
        int? port;
        String? name;
        for (final segment in segments) {
          final parts = segment.split(':');
          if (parts.length < 2) continue;
          final key = parts.first.trim().toUpperCase();
          final value = parts.sublist(1).join(':').trim();
          if (key == 'IP' || key == 'HOST' || key == 'ADDRESS') {
            ip = value;
          } else if (key == 'PORT' || key == 'P') {
            port = int.tryParse(value);
          } else if (key == 'NAME' || key == 'DEVICE') {
            name = value;
          }
        }

        if (ip != null) {
          return CameraConnectionInfo(
            ipAddress: ip,
            port: port ?? 64321,
            name: name ?? ip,
            raw: data,
          );
        }
      }

      return null;
    } catch (e, stack) {
      _warn('Failed to parse camera QR code: $e', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Connect to WiFi network (placeholder).
  static Future<bool> connectToWiFi(
    String ssid,
    String password, {
    bool hidden = false,
  }) async {
    try {
      final trimmedSsid = ssid.trim();
      if (trimmedSsid.isEmpty) {
        return false;
      }

  _info('Attempting Wi-Fi connection to $trimmedSsid');

      if (Platform.isAndroid) {
        final permissionsGranted = await _ensureAndroidWifiPermissions();
        if (!permissionsGranted) {
          _warn('Wi-Fi connection failed due to missing permissions');
          return false;
        }

        final bool? result = await _wifiChannel.invokeMethod<bool>('connectToWifi', {
          'ssid': trimmedSsid,
          'password': password,
          'hidden': hidden,
        });
        return result ?? false;
      }

      if (Platform.isMacOS) {
        final interface = await _resolveWifiInterface();
        if (interface == null) {
          _warn('No Wi-Fi interface available on macOS');
          return false;
        }

        final arguments = <String>['-setairportnetwork', interface, trimmedSsid];
        if (password.isNotEmpty) {
          arguments.add(password);
        }

        const toolPath = '/usr/sbin/networksetup';
        final result = await Process.run(toolPath, arguments);
        if (result.exitCode != 0) {
          _warn(
            'networksetup failed with code ${result.exitCode}: ${result.stderr} ${result.stdout}',
          );
          return false;
        }
        return true;
      }

      // TODO: Implement platform-specific logic for other systems as needed.
      return true;
    } catch (e, stack) {
      _warn('Wi-Fi connection attempt threw an error: $e', error: e, stackTrace: stack);
      return false;
    }
  }

  static Future<bool> connectToWiFiWithRetry(
    String ssid,
    String password, {
    int maxAttempts = 3,
    Duration verificationDelay = const Duration(seconds: 3),
    bool hidden = false,
  }) async {
    final targetSsid = _normalizeSsid(ssid);

    if (!Platform.isMacOS) {
      final success = await connectToWiFi(targetSsid, password, hidden: hidden);
      if (!Platform.isAndroid) {
        return success;
      }

      if (!success) {
        return false;
      }

      if (verificationDelay.inMilliseconds > 0) {
        await Future.delayed(verificationDelay);
      }

      return await isConnectedToWifi(targetSsid);
    }

    await _refreshWifiNetworks();

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final success = await connectToWiFi(targetSsid, password, hidden: hidden);
      if (!success) {
        continue;
      }

      if (verificationDelay.inMilliseconds > 0) {
        await Future.delayed(verificationDelay);
      }

      final connected = await isConnectedToWifi(targetSsid);
      if (connected) {
        return true;
      }

      if (attempt < maxAttempts) {
        _info('Target network not detected, retrying (${attempt + 1}/$maxAttempts)');
        await _refreshWifiNetworks();
      }
    }

    return await isConnectedToWifi(targetSsid);
  }

  static Future<String?> currentWifiSsid() async {
    if (!Platform.isMacOS) {
      if (Platform.isAndroid) {
        try {
          final String? ssid = await _wifiChannel.invokeMethod<String>('getCurrentSsid');
          if (ssid == null || ssid.isEmpty) {
            return null;
          }
          return ssid;
        } on MissingPluginException catch (e, stack) {
          _warn('Android Wi-Fi plugin missing', error: e, stackTrace: stack);
          return null;
        } on PlatformException catch (e, stack) {
          _warn('Failed to obtain Android Wi-Fi information', error: e, stackTrace: stack);
          return null;
        }
      }
      return null;
    }

    try {
      final interface = await _resolveWifiInterface();
      if (interface == null) {
        return null;
      }

      const toolPath = '/usr/sbin/networksetup';
      final result = await Process.run(toolPath, ['-getairportnetwork', interface]);
      if (result.exitCode != 0) {
        _warn('Failed to get current macOS network: ${result.stderr}');
        return null;
      }

      final output = result.stdout.toString().trim();
      if (output.isEmpty || output.contains('You are not associated')) {
        return null;
      }

      if (output.contains('Current Wi-Fi Network:')) {
        return output.split(':').last.trim();
      }

      return output;
    } catch (e, stack) {
      _warn('Failed to read current Wi-Fi network', error: e, stackTrace: stack);
      return null;
    }
  }

  static Future<bool> isConnectedToWifi(String ssid) async {
    final current = await currentWifiSsid();
    if (current == null) {
      return false;
    }
    return _normalizeSsid(current) == _normalizeSsid(ssid);
  }

  static Future<bool> _ensureAndroidWifiPermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final locationStatus = await Permission.locationWhenInUse.request();
    if (!locationStatus.isGranted && !locationStatus.isLimited) {
      final fallback = await Permission.location.request();
      if (!fallback.isGranted && !fallback.isLimited) {
        return false;
      }
    }

    final nearbyStatus = await Permission.nearbyWifiDevices.request();
    if (nearbyStatus.isPermanentlyDenied) {
      return false;
    }

    if (!nearbyStatus.isGranted && !nearbyStatus.isLimited) {
      _warn('NEARBY_WIFI_DEVICES permission not granted; connectivity may be limited');
    }

    return true;
  }

  /// Split payloads on unescaped semicolons.
  static List<String> _splitEscapedSegments(String payload) {
    final segments = <String>[];
    final buffer = StringBuffer();
    var isEscaped = false;

    for (final codeUnit in payload.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (isEscaped) {
        buffer.write(char);
        isEscaped = false;
        continue;
      }

      if (char == '\\') {
        isEscaped = true;
        continue;
      }

      if (char == ';') {
        final segment = buffer.toString().trim();
        if (segment.isNotEmpty) {
          segments.add(segment);
        }
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      segments.add(tail);
    }

    return segments;
  }

  /// Split a string on the first unescaped [separator] character.
  static (String, String)? _splitFirstUnescaped(String input, String separator) {
    var isEscaped = false;
    for (var index = 0; index < input.length; index++) {
      final char = input[index];
      if (isEscaped) {
        isEscaped = false;
        continue;
      }
      if (char == '\\') {
        isEscaped = true;
        continue;
      }
      if (char == separator) {
        final key = input.substring(0, index).trim();
        final value = input.substring(index + 1).trim();
        if (key.isEmpty) {
          return null;
        }
        return (key, value);
      }
    }
    return null;
  }

  /// Unescape Wi-Fi QR encoded values such as '\\;' and '\\:'.
  static String _unescapeWiFiValue(String value) {
    final buffer = StringBuffer();
    var isEscaped = false;

    for (final codeUnit in value.codeUnits) {
      final char = String.fromCharCode(codeUnit);
      if (isEscaped) {
        buffer.write(char);
        isEscaped = false;
        continue;
      }
      if (char == '\\') {
        isEscaped = true;
        continue;
      }
      buffer.write(char);
    }

    if (isEscaped) {
      buffer.write('\\');
    }

    return buffer.toString();
  }

  /// Track scanning status to avoid duplicate processing.
  static bool get isScanning => _isScanning;

  /// Update scanning status.
  static void setScanning(bool scanning) {
    _isScanning = scanning;
  }

  static CameraFacing _defaultCameraFacing() {
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return CameraFacing.front;
    }
    return CameraFacing.back;
  }

  static String? _cachedWifiInterface;

  static Future<String?> _resolveWifiInterface() async {
    if (_cachedWifiInterface != null) {
      return _cachedWifiInterface;
    }

    try {
      const toolPath = '/usr/sbin/networksetup';
      final result = await Process.run(toolPath, ['-listallhardwareports']);
      if (result.exitCode != 0) {
        _warn('Failed to list hardware ports: ${result.stderr}');
        return _cachedWifiInterface = 'en0';
      }

      final lines = result.stdout.toString().split(RegExp(r'\r?\n'));
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trim().startsWith('Hardware Port:') &&
            line.contains('Wi-Fi')) {
          for (var j = i + 1; j < lines.length; j++) {
            final next = lines[j].trim();
            if (next.startsWith('Device:')) {
              final device = next.substring('Device:'.length).trim();
              if (device.isNotEmpty) {
                return _cachedWifiInterface = device;
              }
            }
          }
        }
      }

      return _cachedWifiInterface = 'en0';
    } catch (e, stack) {
      _warn('Failed to resolve Wi-Fi interface', error: e, stackTrace: stack);
      return _cachedWifiInterface = 'en0';
    }
  }

  static Future<void> _refreshWifiNetworks() async {
    if (!Platform.isMacOS) {
      return;
    }

    try {
      const airportPath =
          '/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport';
      final result = await Process.run(airportPath, ['-s']);
      if (result.exitCode != 0) {
        _warn('Wi-Fi refresh command failed: ${result.stderr}');
      }
    } catch (e, stack) {
      _warn('Wi-Fi refresh command threw an error', error: e, stackTrace: stack);
    }
  }

  static String _normalizeSsid(String value) {
    return value.replaceAll('"', '').trim();
  }
}

/// Camera connection information parsed from QR code.
class CameraConnectionInfo {
  final String ipAddress;
  final int port;
  final String name;
  final String raw;

  const CameraConnectionInfo({
    required this.ipAddress,
    required this.port,
    required this.name,
    required this.raw,
  });

  @override
  String toString() {
    return 'CameraConnectionInfo(ip: $ipAddress, port: $port, name: $name)';
  }
}
