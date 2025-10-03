import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imagingedge_next/l10n/app_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/camera_provider.dart' as camera;
import '../services/qr_scanner_service.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  late final MobileScannerController _controller;
  String? scannedData;
  bool isScanning = true;
  String? errorMessage;
  Map<String, String>? lastWifiAttempt;
  bool wifiConnectionFailed = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _controller = QRScannerService.createController();
    QRScannerService.setScanning(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkCameraAvailability();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkCameraAvailability() async {
    try {
      final isAvailable = await QRScannerService.isCameraAvailable(_controller);
      if (!isAvailable) {
        setState(() {
          errorMessage = l10n.qrCameraUnavailable;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = l10n.qrCameraCheckFailed(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: errorMessage != null
                ? _buildErrorWidget()
                : _buildScannerWidget(),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.black.withOpacity(0.8),
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (scannedData != null) ...[
                            Text(
                              l10n.qrResultTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              scannedData!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 16),
                            if (wifiConnectionFailed && lastWifiAttempt != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(
                                  l10n.qrWifiFailureHint,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  if (!wifiConnectionFailed)
                                    ElevatedButton(
                                      onPressed: () async =>
                                          await _processQRData(scannedData!),
                                      child: Text(l10n.qrProcessResult),
                                    ),
                                  ElevatedButton(
                                    onPressed: () => _copyToClipboard(
                                      scannedData ?? '',
                                      successMessage: l10n.qrCopySuccessResult,
                                    ),
                                    child: Text(l10n.qrCopyResult),
                                  ),
                                  if (wifiConnectionFailed &&
                                      lastWifiAttempt != null) ...[
                                    ElevatedButton(
                                      onPressed: () => _copyToClipboard(
                                        lastWifiAttempt!['SSID'] ??
                                            lastWifiAttempt!['S'] ??
                                            '',
                                        successMessage: l10n.qrCopySuccessSsid,
                                      ),
                                      child: Text(l10n.qrCopyWifiName),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _copyToClipboard(
                                        lastWifiAttempt!['PASSWORD'] ??
                                            lastWifiAttempt!['P'] ??
                                            '',
                                        successMessage: l10n.qrCopySuccessPassword,
                                      ),
                                      child: Text(l10n.qrCopyWifiPassword),
                                    ),
                          ],
                          ElevatedButton(
                            onPressed: () {
                              _resetScanner();
                            },
                            child: Text(l10n.qrRescan),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text(
                      l10n.qrAlignHint,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerWidget() {
    return LayoutBuilder(
      builder: (context, _) {
        final size = MediaQuery.sizeOf(context);
        final scanWidth = size.width * 0.8;
        final scanHeight = size.height * 0.36;
        final targetCenterY = (size.height / 2) - 20;
        final minCenterY = scanHeight / 2;
        final scanCenter = Offset(
          size.width / 2,
          targetCenterY < minCenterY ? minCenterY : targetCenterY,
        );
        final scanWindow = Rect.fromCenter(
          center: scanCenter,
          width: scanWidth,
          height: scanHeight,
        );

        return AiBarcodeScanner(
          controller: _controller,
          galleryButtonType: GalleryButtonType.none,
          scanWindow: scanWindow,
          onDetect: (BarcodeCapture capture) async {
            if (!QRScannerService.isScanning) {
              return;
            }

            final Barcode? first =
                capture.barcodes.isNotEmpty ? capture.barcodes.first : null;
            final String? scannedValue =
                first?.displayValue ?? first?.rawValue;
            if (scannedValue == null || scannedValue.isEmpty) {
              return;
            }

            QRScannerService.setScanning(false);
            await _controller.stop();
            if (!mounted) return;
            setState(() {
              scannedData = scannedValue;
              isScanning = false;
            });
            await _processQRData(scannedValue);
          },
          onDispose: () {
            print('AI scanner disposed');
          },
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.qrCameraInitFailed,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? l10n.qrUnknownError,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      errorMessage = null;
                    });
                    _checkCameraAvailability();
                  },
                  child: Text(l10n.commonRetry),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _showManualInputDialog,
                  child: Text(l10n.connectionManualInput),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processQRData(String data) async {
    if (!mounted) return;
    setState(() {
      wifiConnectionFailed = false;
      lastWifiAttempt = null;
    });

    final wifiData = QRScannerService.parseWiFiQRCode(data);
    if (wifiData != null) {
      setState(() {
        lastWifiAttempt = wifiData;
      });
      final ssid = wifiData['SSID'] ?? wifiData['S'] ?? '';
      final password = wifiData['PASSWORD'] ?? wifiData['P'] ?? '';
      final hiddenRaw = (wifiData['HIDDEN'] ?? wifiData['H'] ?? '').toLowerCase();
      final isHiddenNetwork = hiddenRaw == 'true' || hiddenRaw == '1' || hiddenRaw == 'yes';
      final success = await QRScannerService.connectToWiFi(
        ssid,
        password,
        hidden: isHiddenNetwork,
      );
      if (!mounted) return;
      if (success) {
        _showResult(l10n.connectionWifiConnecting(ssid));
        final cameraState = ref.read(camera.cameraProvider);
        if (!cameraState.isConnected && !cameraState.isConnecting) {
          ref.read(camera.cameraProvider.notifier).connect(wifiInfo: {
            'ssid': ssid,
            'password': password,
            'hidden': isHiddenNetwork.toString(),
            'raw': wifiData['RAW'] ?? data,
          });
        }
        Future.microtask(() {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
        return;
      }

      setState(() {
        wifiConnectionFailed = true;
      });
      _showResult(l10n.connectionWifiFailed);
      return;
    }

    if (!mounted) return;
    _showResult(l10n.qrScanValidPrompt);
    await _resetScanner();
  }

  void _showManualInputDialog() {
    final TextEditingController textController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(l10n.manualInputTitle),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(
              hintText: l10n.manualInputHint,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = textController.text.trim();
                if (input.isNotEmpty) {
                  Navigator.of(context).pop();
                  try {
                    await _controller.stop();
                  } catch (_) {}
                  QRScannerService.setScanning(false);
                  if (!mounted) return;
                  setState(() {
                    scannedData = input;
                    isScanning = false;
                  });
                  await _processQRData(input);
                }
              },
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    );
  }

  void _copyToClipboard(String value, {String? successMessage}) {
    if (value.isEmpty) {
      _showResult(l10n.qrCopyEmpty);
      return;
    }
    Clipboard.setData(ClipboardData(text: value));
    _showResult(successMessage ?? l10n.commonCopied);
  }

  Future<void> _resetScanner() async {
    setState(() {
      scannedData = null;
      isScanning = true;
      errorMessage = null;
      wifiConnectionFailed = false;
      lastWifiAttempt = null;
    });
    QRScannerService.setScanning(true);
    try {
      await _controller.start();
    } catch (e) {
      setState(() {
        errorMessage = l10n.qrRestartFailed(e.toString());
      });
    }
  }

  void _showResult(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
