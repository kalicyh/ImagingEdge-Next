import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imagingedge_next/l10n/app_localizations.dart';
import '../providers/providers.dart';
import '../providers/camera_provider.dart' as camera;
import '../services/services.dart';
import 'qr_scanner_screen.dart';
import '../services/qr_scanner_service.dart';
import '../widgets/fluid_dock.dart';

class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({super.key});

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  final TextEditingController _manualInputController = TextEditingController();
  bool _isRetryingWifi = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
  final cameraState = ref.watch(cameraProvider);
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(l10n.appTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                // Connection status card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          _getStatusIcon(cameraState.connectionState),
                          size: 48,
                          color: _getStatusColor(cameraState.connectionState),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getStatusText(cameraState.connectionState, l10n),
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        if (cameraState.hasError) ...[
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final errorText = cameraState.errorMessage ==
                                      camera.CameraNotifier.wifiErrorMessageCode
                                  ? l10n.cameraErrorWifi
                                  : (cameraState.errorMessage ??
                                      l10n.connectionUnknownError);
                              return Text(
                                errorText,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              );
                            },
                          ),
                          if (cameraState.lastWiFiSsid != null) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: cameraState.isConnecting || _isRetryingWifi
                                  ? null
                                  : () => _retryLastConnection(context, ref),
                              icon: _isRetryingWifi
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh),
                              label: Text(
                                _isRetryingWifi
                                    ? l10n.connectionRetrying
                                    : l10n.connectionRetryLast,
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 40),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                
                // QR Code scanning
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: cameraState.isConnecting ? null : () async {
                          final result = await Navigator.push<CameraConnectionInfo>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const QRScannerScreen(),
                            ),
                          );

                        if (result != null) {
                            ref
                                .read(settingsProvider.notifier)
                                .setCameraAddress(result.ipAddress);
                            ref
                                .read(settingsProvider.notifier)
                                .setCameraPort(result.port);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.connectionCameraInfoSet(
                                      result.ipAddress,
                                      result.name,
                                      result.port,
                                    ),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: Text(l10n.connectionScanQr),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: cameraState.isConnecting
                            ? null
                            : () => _showManualInputDialog(context, ref),
                        icon: const Icon(Icons.edit_note),
                        label: Text(l10n.connectionManualInput),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Connection buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: cameraState.isConnecting ? null : () async {
                          await ref.read(cameraProvider.notifier).connect();
                        },
                        icon: cameraState.isConnecting 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi),
                        label: Text(
                          cameraState.isConnecting
                              ? l10n.connectionConnecting
                              : l10n.connectionConnect,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: !cameraState.isConnected ? null : () async {
                          await ref.read(cameraProvider.notifier).disconnect();
                        },
                        icon: const Icon(Icons.wifi_off),
                        label: Text(l10n.connectionDisconnect),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                
                if (cameraState.isConnected) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/images');
                      },
                      icon: const Icon(Icons.photo_library),
                      label: Text(l10n.connectionBrowse),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 120),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: const FluidDock(currentRoute: '/'),
    );
  }

  Future<void> _retryLastConnection(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(cameraProvider.notifier);
    final currentState = ref.read(cameraProvider);
    final ssid = currentState.lastWiFiSsid;
    setState(() {
      _isRetryingWifi = true;
    });
    final success = await notifier.retryLastWifi();
    if (!mounted) return;
    setState(() {
      _isRetryingWifi = false;
    });
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success && ssid != null
              ? l10n.connectionWifiConnecting(ssid)
              : l10n.connectionWifiFailed,
        ),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Future<void> _showManualInputDialog(BuildContext context, WidgetRef ref) async {
    _manualInputController.clear();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.manualInputTitle),
          content: TextField(
            controller: _manualInputController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.manualInputHint,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.commonCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final input = _manualInputController.text.trim();
                if (input.isEmpty) {
                  return;
                }
                Navigator.of(context).pop();
                await _handleManualInput(input, ref);
              },
              child: Text(AppLocalizations.of(context)!.commonConfirm),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleManualInput(String data, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final wifiData = QRScannerService.parseWiFiQRCode(data);
    if (wifiData != null) {
      final ssid = wifiData['SSID'] ?? wifiData['S'] ?? '';
      final password = wifiData['PASSWORD'] ?? wifiData['P'] ?? '';
      final hiddenRaw = (wifiData['HIDDEN'] ?? wifiData['H'] ?? '').toLowerCase();
      final isHiddenNetwork =
          hiddenRaw == 'true' || hiddenRaw == '1' || hiddenRaw == 'yes';
      final success = await QRScannerService.connectToWiFi(
        ssid,
        password,
        hidden: isHiddenNetwork,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.connectionWifiConnecting(ssid)
                : l10n.connectionWifiFailed,
          ),
          backgroundColor: success ? Colors.green : Colors.redAccent,
        ),
      );

      if (success) {
        final currentState = ref.read(cameraProvider);
        if (!currentState.isConnected && !currentState.isConnecting) {
          await ref.read(cameraProvider.notifier).connect(wifiInfo: {
            'ssid': ssid,
            'password': password,
            'hidden': isHiddenNetwork.toString(),
          });
        }
      }
      return;
    }

    final cameraInfo = QRScannerService.parseCameraQRCode(data);
    if (cameraInfo != null) {
      ref.read(settingsProvider.notifier).setCameraAddress(cameraInfo.ipAddress);
      ref.read(settingsProvider.notifier).setCameraPort(cameraInfo.port);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.connectionCameraInfoSet(
              cameraInfo.ipAddress,
              cameraInfo.name,
              cameraInfo.port,
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.connectionManualInputInvalid),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  IconData _getStatusIcon(camera.ConnectionState state) {
    switch (state) {
      case camera.ConnectionState.disconnected:
        return Icons.wifi_off;
      case camera.ConnectionState.connecting:
        return Icons.wifi_find;
      case camera.ConnectionState.connected:
        return Icons.wifi;
      case camera.ConnectionState.error:
        return Icons.error;
    }
  }

  Color _getStatusColor(camera.ConnectionState state) {
    switch (state) {
      case camera.ConnectionState.disconnected:
        return Colors.grey;
      case camera.ConnectionState.connecting:
        return Colors.orange;
      case camera.ConnectionState.connected:
        return Colors.green;
      case camera.ConnectionState.error:
        return Colors.red;
    }
  }

  String _getStatusText(camera.ConnectionState state, AppLocalizations l10n) {
    switch (state) {
      case camera.ConnectionState.disconnected:
        return l10n.connectionStatusDisconnected;
      case camera.ConnectionState.connecting:
        return l10n.connectionStatusConnecting;
      case camera.ConnectionState.connected:
        return l10n.connectionStatusConnected;
      case camera.ConnectionState.error:
        return l10n.connectionStatusError;
    }
  }
}
