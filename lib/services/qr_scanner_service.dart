import 'dart:async';
import 'dart:io';

import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerService {
  static bool _isScanning = false;

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
  static Future<bool> isCameraAvailable() async {
    MobileScannerController? controller;
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        return true;
      }

      controller = createController();
      await controller.start();
      await controller.stop();
      return true;
    } catch (e) {
      print('QRScannerService: 相机检查失败: $e');
      return false;
    } finally {
      await controller?.dispose();
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
          'FORMAT': 'W01',
          'RAW': trimmed,
        };
      }

      return null;
    } catch (e) {
      print('QRScannerService: WiFi QR解析失败: $e');
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
    } catch (e) {
      print('QRScannerService: 相机QR解析失败: $e');
      return null;
    }
  }

  /// Connect to WiFi network (placeholder).
  static Future<bool> connectToWiFi(String ssid, String password) async {
    try {
      final trimmedSsid = ssid.trim();
      if (trimmedSsid.isEmpty) {
        return false;
      }

      print('QRScannerService: 尝试连接WiFi - SSID: $trimmedSsid');

      if (Platform.isMacOS) {
        final interface = await _resolveWifiInterface();
        if (interface == null) {
          print('QRScannerService: 未找到可用的 Wi-Fi 接口');
          return false;
        }

        final arguments = <String>['-setairportnetwork', interface, trimmedSsid];
        if (password.isNotEmpty) {
          arguments.add(password);
        }

        const toolPath = '/usr/sbin/networksetup';
        final result = await Process.run(toolPath, arguments);
        if (result.exitCode != 0) {
          print(
              'QRScannerService: networksetup失败 (code ${result.exitCode}): ${result.stderr} ${result.stdout}');
          return false;
        }
        return true;
      }

      // TODO: Implement platform-specific logic for other systems as needed.
      return true;
    } catch (e) {
      print('QRScannerService: WiFi连接失败: $e');
      return false;
    }
  }

  static Future<bool> connectToWiFiWithRetry(
    String ssid,
    String password, {
    int maxAttempts = 3,
    Duration verificationDelay = const Duration(seconds: 3),
  }) async {
    final targetSsid = _normalizeSsid(ssid);

    if (!Platform.isMacOS) {
      return await connectToWiFi(targetSsid, password);
    }

    await _refreshWifiNetworks();

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final success = await connectToWiFi(targetSsid, password);
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
        print('QRScannerService: 未检测到目标网络，正在进行第${attempt + 1}次重试');
        await _refreshWifiNetworks();
      }
    }

    return await isConnectedToWifi(targetSsid);
  }

  static Future<String?> currentWifiSsid() async {
    if (!Platform.isMacOS) {
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
        print('QRScannerService: 获取当前网络失败: ${result.stderr}');
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
    } catch (e) {
      print('QRScannerService: 读取当前WiFi失败: $e');
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
        print('QRScannerService: 无法获取硬件端口列表: ${result.stderr}');
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
    } catch (e) {
      print('QRScannerService: 解析Wi-Fi接口失败: $e');
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
        print('QRScannerService: Wi-Fi 刷新失败: ${result.stderr}');
      }
    } catch (e) {
      print('QRScannerService: Wi-Fi 刷新异常: $e');
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
