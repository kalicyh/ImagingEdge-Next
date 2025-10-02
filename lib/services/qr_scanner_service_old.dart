import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';

class QRScannerService {
  static bool _isScanning = false;
  
  /// Initialize camera permissions and get available cameras
  static Future<List<CameraDescription>> initializeCameras() async {
    try {
      final cameras = await availableCameras();
      return cameras;
    } catch (e) {
      throw QRScannerException('Failed to initialize cameras: $e');
    }
  }
  
  /// Check if camera permission is granted
  static Future<bool> checkCameraPermission() async {
    try {
      // On desktop platforms, camera permission is usually granted by default
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        return true;
      }
      
      // For other platforms, you might need to implement permission checking
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    try {
      // On desktop platforms, permission is usually automatic
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        return true;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if camera is available
  static Future<bool> isCameraAvailable() async {
    try {
      // 尝试创建一个临时控制器来测试相机可用性
      final testController = MobileScannerController(
        autoStart: false,
        formats: [BarcodeFormat.qrCode],
      );
      
      // 尝试启动并立即停止
      await testController.start();
      await testController.stop();
      await testController.dispose();
      
      print('QRScannerService: 相机可用性检查通过');
      return true;
    } catch (e) {
      print('QRScannerService: 相机不可用: $e');
      return false;
    }
  }
  
  /// Create a new mobile scanner controller
  static MobileScannerController createController() {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        formats: [BarcodeFormat.qrCode],
        // 让 MobileScanner widget 自动启动
        autoStart: true,
        torchEnabled: false,
        returnImage: false, // 减少内存使用
      );
      
      // 添加调试信息
      print('QRScannerService: 创建了新的扫描控制器');
      
      return _controller!;
    } catch (e) {
      print('QRScannerService: 创建控制器失败: $e');
      rethrow;
    }
  }
  
  /// Start scanning for QR codes
  static Future<void> startScanning() async {
    try {
      if (_controller != null && !_isScanning) {
        print('QRScannerService: 开始启动扫描器...');
        await _controller!.start();
        _isScanning = true;
        print('QRScannerService: 扫描器启动成功');
      }
    } catch (e) {
      print('QRScannerService: 启动扫描器失败: $e');
      _isScanning = false;
      rethrow;
    }
  }
  
  /// Stop scanning for QR codes
  static Future<void> stopScanning() async {
    if (_controller != null && _isScanning) {
      await _controller!.stop();
      _isScanning = false;
    }
  }
  
  /// Dispose of the scanner controller
  static Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isScanning = false;
    }
  }
  
  /// Parse WiFi QR code data
  static WiFiInfo? parseWiFiQRCode(String qrData) {
    try {
      // WiFi QR codes typically follow this format:
      // WIFI:T:WPA;S:SSID;P:password;H:false;;
      if (!qrData.startsWith('WIFI:')) {
        return null;
      }
      
      final Map<String, String> params = {};
      final parts = qrData.substring(5).split(';'); // Remove 'WIFI:' prefix
      
      for (final part in parts) {
        if (part.contains(':') && part.length > 2) {
          final colonIndex = part.indexOf(':');
          final key = part.substring(0, colonIndex);
          final value = part.substring(colonIndex + 1);
          params[key] = value;
        }
      }
      
      final ssid = params['S'];
      final password = params['P'];
      final security = params['T'] ?? 'WPA';
      final hidden = params['H'] == 'true';
      
      if (ssid != null) {
        return WiFiInfo(
          ssid: ssid,
          password: password ?? '',
          security: security,
          hidden: hidden,
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Parse camera IP information from QR code
  /// This could be a custom format for camera connection info
  static CameraConnectionInfo? parseCameraQRCode(String qrData) {
    try {
      // Custom format: CAMERA:IP:192.168.122.1;PORT:64321;NAME:Sony Camera
      if (qrData.startsWith('CAMERA:')) {
        final Map<String, String> params = {};
        final parts = qrData.substring(7).split(';'); // Remove 'CAMERA:' prefix
        
        for (final part in parts) {
          if (part.contains(':') && part.length > 2) {
            final colonIndex = part.indexOf(':');
            final key = part.substring(0, colonIndex);
            final value = part.substring(colonIndex + 1);
            params[key] = value;
          }
        }
        
        final ip = params['IP'];
        final portStr = params['PORT'];
        final name = params['NAME'];
        
        if (ip != null) {
          final port = int.tryParse(portStr ?? '64321') ?? 64321;
          return CameraConnectionInfo(
            ipAddress: ip,
            port: port,
            name: name ?? 'Camera',
          );
        }
      }
      
      // Also try to parse as plain IP address
      final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
      if (ipRegex.hasMatch(qrData)) {
        return CameraConnectionInfo(
          ipAddress: qrData,
          port: 64321,
          name: 'Camera',
        );
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// WiFi connection information parsed from QR code
class WiFiInfo {
  final String ssid;
  final String password;
  final String security;
  final bool hidden;
  
  const WiFiInfo({
    required this.ssid,
    required this.password,
    this.security = 'WPA',
    this.hidden = false,
  });
  
  @override
  String toString() {
    return 'WiFiInfo(ssid: $ssid, security: $security, hidden: $hidden)';
  }
}

/// Camera connection information parsed from QR code
class CameraConnectionInfo {
  final String ipAddress;
  final int port;
  final String name;
  
  const CameraConnectionInfo({
    required this.ipAddress,
    required this.port,
    required this.name,
  });
  
  @override
  String toString() {
    return 'CameraConnectionInfo(ip: $ipAddress, port: $port, name: $name)';
  }
}

class QRScannerException implements Exception {
  final String message;
  const QRScannerException(this.message);
  
  @override
  String toString() => 'QRScannerException: $message';
}