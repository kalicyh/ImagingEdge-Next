import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../utils/utils.dart';

class ImagingEdgeService {
  final String address;
  final int port;
  final bool debug;

  late final String _baseUrl;
  late final String _controlUrl;
  late final String _contentDirectoryUrl;
  bool _transferActive = false;
  
  ImagingEdgeService({
    required this.address,
    this.port = 64321,
    this.debug = false,
  }) {
    _baseUrl = 'http://$address:$port';
    _controlUrl = '$_baseUrl/upnp/control/XPushList';
    _contentDirectoryUrl = '$_baseUrl/upnp/control/ContentDirectory';
  }

  /// Test connection to camera and get service information
  Future<CameraModel> getServiceInfo() async {
    try {
      if (debug) print('Getting service info from $_baseUrl');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/DmsDescPush.xml'),
        headers: {'User-Agent': 'ImagingEdge4Linux'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final services = XmlParser.parseServiceDescription(response.body);
        if (debug) print('Found services: $services');
        
        return CameraModel(
          address: address,
          port: port,
          isConnected: true,
          services: services,
        );
      } else {
        throw ImagingEdgeException('Failed to get service info: HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (debug) print('Error getting service info: $e');
      throw ImagingEdgeException('Failed to connect to camera: $e');
    }
  }

  /// Start transfer mode on camera
  Future<void> startTransfer() async {
    try {
      if (_transferActive) {
        if (debug) print('Transfer already active, skipping start request.');
        return;
      }

      if (debug) print('Starting transfer...');
      
      final response = await _sendSoapRequest(
        'X_TransferStart',
        XmlParser.createTransferStartRequest(),
      );
      
      if (debug) print('Transfer start response: ${response.statusCode}');
      _transferActive = true;
    } catch (e) {
      throw ImagingEdgeException('Failed to start transfer: $e');
    }
  }

  /// End transfer mode on camera
  Future<void> endTransfer() async {
    try {
      if (debug) {
        final status = _transferActive ? 'active' : 'inactive';
        print('Sending transfer end request (local state: $status).');
      }

      final response = await _sendSoapRequest(
        'X_TransferEnd',
        XmlParser.createTransferEndRequest(),
      );

      if (debug) print('Transfer end response: ${response.statusCode}');
      _transferActive = false;
    } catch (e) {
      final message = e.toString();
      if (message.contains('errorCode>402') ||
          message.toLowerCase().contains('action x_transferend failed')) {
        if (debug) {
          print('Transfer already terminated on camera side. Clearing local state.');
        }
        _transferActive = false;
        return;
      }
      throw ImagingEdgeException('Failed to end transfer: $e');
    }
  }

  /// Get directory content from camera
  Future<List<dynamic>> getDirectoryContent(
    String containerId, {
    int startIndex = 0,
    int requestCount = 200,
  }) async {
    try {
      return await _getPushListContent(
        containerId,
        startIndex: startIndex,
        requestCount: requestCount,
      );
    } on ImagingEdgeException catch (e) {
      if (debug) {
        print('PushList content fetch failed: $e, falling back to ContentDirectory browse.');
      }
      return await _getContentDirectoryContent(
        containerId,
        startIndex: startIndex,
        requestCount: requestCount,
      );
    }
  }

  Future<List<dynamic>> _getPushListContent(
    String containerId, {
    required int startIndex,
    required int requestCount,
  }) async {
    if (debug) print('Getting directory content for container: $containerId via XPushList');

    final response = await _sendSoapRequest(
      'X_GetContentList',
      XmlParser.createGetContentListRequest(
        containerId,
        startIndex: startIndex,
        requestCount: requestCount,
      ),
    );

    final items = XmlParser.parseDirectoryContent(response.body);
    if (debug) print('Found ${items.length} items in directory (XPushList)');

    return items;
  }

  Future<List<dynamic>> _getContentDirectoryContent(
    String containerId, {
    required int startIndex,
    required int requestCount,
  }) async {
    if (debug) {
      print('Getting directory content for container: $containerId via ContentDirectory Browse (start=$startIndex)');
    }

    final response = await _sendContentDirectoryRequest(
      XmlParser.createBrowseRequest(
        containerId,
        startIndex: startIndex,
        requestCount: requestCount,
      ),
    );

    final document = XmlParser.parseSoapEnvelope(response.body);
    final resultXml = document.resultXml.trim();
    if (resultXml.isEmpty) {
      if (debug) {
        print('ContentDirectory response returned empty result set.');
      }
      return const [];
    }

    final items = XmlParser.parseDirectoryContent(resultXml);

    final results = List<dynamic>.from(items);

    if (document.numberReturned > 0 && document.hasMore(startIndex)) {
      final nextStart = startIndex + document.numberReturned;
      if (debug) {
        print('More items available for $containerId, fetching from index $nextStart');
      }
      final moreItems = await _getContentDirectoryContent(
        containerId,
        startIndex: nextStart,
        requestCount: requestCount,
      );
      results.addAll(moreItems);
    }

    return results;
  }

  /// Recursively browse camera directory structure
  Future<List<ImageModel>> browseImages({String rootContainer = 'PushRoot'}) async {
    final allImages = <ImageModel>[];

    try {
      final triedRoots = <String>{};
      final rootsToTry = <String>[
        rootContainer,
        if (rootContainer != 'PhotoRoot') 'PhotoRoot',
        if (rootContainer != '0') '0',
      ];

      for (final root in rootsToTry) {
        if (triedRoots.contains(root)) continue;
        triedRoots.add(root);

        if (debug) print('Browsing root container: $root');
        try {
          await _browseRecursive(root, allImages);
          if (allImages.isNotEmpty) {
            break;
          }
        } catch (e) {
          if (debug) {
            print('Browse failed for $root: $e');
          }
          // Try next root
        }
      }

      if (debug) print('Total images found: ${allImages.length}');
      return allImages;
    } catch (e) {
      throw ImagingEdgeException('Failed to browse images: $e');
    }
  }

  /// Recursively browse directory structure
  Future<void> _browseRecursive(String containerId, List<ImageModel> images) async {
    final items = await getDirectoryContent(containerId);
    
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        if (item['type'] == 'container') {
          // Recursively browse subdirectories
          await _browseRecursive(item['id'], images);
        }
        // Note: Map items from parseDirectoryContent are already processed in XmlParser
      } else if (item is ImageModel) {
        images.add(item);
      }
    }
  }

  /// Download a single file with progress callback
  Future<void> downloadFile(
    String url,
    String outputPath, {
    int? expectedSize,
    Function(int downloaded, int total)? onProgress,
  }) async {
    try {
      if (debug) print('Downloading: $url -> $outputPath');
      
      // Check if file already exists and has correct size
      if (await FileManager.isFileDownloaded(outputPath, expectedSize)) {
        if (debug) print('File already exists and has correct size, skipping');
        onProgress?.call(expectedSize ?? 0, expectedSize ?? 0);
        return;
      }
      
      // Ensure output directory exists
      await FileManager.ensureDirectoryExists(File(outputPath).parent.path);
      
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'ImagingEdge4Linux';
      
      final response = await http.Client().send(request);
      
      if (response.statusCode == 200) {
        final file = File(outputPath);
        final sink = file.openWrite();
        
        int downloaded = 0;
        final total = response.contentLength ?? expectedSize ?? 0;
        
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          onProgress?.call(downloaded, total);
        }
        
        await sink.close();
        
        // Verify file size if expected size was provided
        if (expectedSize != null) {
          final actualSize = await FileManager.getFileSize(outputPath);
          if (actualSize != expectedSize) {
            await FileManager.deleteFile(outputPath);
            throw ImagingEdgeException('Downloaded file size mismatch: expected $expectedSize, got $actualSize');
          }
        }
        
        if (debug) print('Download completed: $outputPath');
      } else {
        throw ImagingEdgeException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } catch (e) {
      throw ImagingEdgeException('Failed to download file: $e');
    }
  }

  /// Send SOAP request to camera
  Future<http.Response> _sendSoapRequest(String action, String body) async {
    final response = await http.post(
      Uri.parse(_controlUrl),
      headers: {
        'SOAPACTION': '"urn:schemas-sony-com:service:XPushList:1#$action"',
        'Content-Type': 'text/xml; charset="utf-8"',
        'User-Agent': 'ImagingEdge4Linux',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final snippet = response.body.isNotEmpty
          ? response.body.trim().replaceAll(RegExp(r'\s+'), ' ')
          : 'No response body';
      throw ImagingEdgeException(
        'SOAP request failed: HTTP ${response.statusCode} - $snippet',
      );
    }

    return response;
  }

  Future<http.Response> _sendContentDirectoryRequest(String body) async {
    final response = await http.post(
      Uri.parse(_contentDirectoryUrl),
      headers: {
        'SOAPACTION': '"urn:schemas-upnp-org:service:ContentDirectory:1#Browse"',
        'Content-Type': 'text/xml; charset="utf-8"',
        'User-Agent': 'ImagingEdge4Linux',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final snippet = response.body.isNotEmpty
          ? response.body.trim().replaceAll(RegExp(r'\s+'), ' ')
          : 'No response body';
      throw ImagingEdgeException(
        'SOAP request failed: HTTP ${response.statusCode} - $snippet',
      );
    }

    return response;
  }

  /// Check if camera is reachable
  Future<bool> isReachable() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/DmsDescPush.xml'),
        headers: {'User-Agent': 'ImagingEdge4Linux'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class ImagingEdgeException implements Exception {
  final String message;
  const ImagingEdgeException(this.message);
  
  @override
  String toString() => 'ImagingEdgeException: $message';
}
