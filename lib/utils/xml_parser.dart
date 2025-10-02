import 'package:xml/xml.dart';
import '../models/models.dart';

class XmlParser {
  /// Parse the DmsDescPush.xml response to extract service information
  static List<String> parseServiceDescription(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final services = <String>[];
      
      // Find all service elements
      final serviceElements = document.findAllElements('service');
      for (final service in serviceElements) {
        final serviceType = service.findElements('serviceType').firstOrNull?.innerText;
        if (serviceType != null) {
          services.add(serviceType);
        }
      }
      
      return services;
    } catch (e) {
      throw XmlParserException('Failed to parse service description: $e');
    }
  }

  /// Parse directory content response from camera
  static List<dynamic> parseDirectoryContent(String xmlContent) {
    try {
      XmlDocument document = XmlDocument.parse(xmlContent);
      XmlElement? didlRoot = document.rootElement.name.local == 'DIDL-Lite'
          ? document.rootElement
          : document.findAllElements('DIDL-Lite').firstOrNull;

      if (didlRoot == null) {
        final resultElements = document.findAllElements('Result');
        final resultElement = resultElements.firstOrNull;
        if (resultElement != null) {
          final innerXml = resultElement.innerText.trim();
          if (innerXml.isEmpty) {
            return const [];
          }
          document = XmlDocument.parse(innerXml);
          didlRoot = document.rootElement.name.local == 'DIDL-Lite'
              ? document.rootElement
              : document.findAllElements('DIDL-Lite').firstOrNull;
        }
      }

      final xmlSource = didlRoot ?? document.rootElement;
      final items = <dynamic>[];

      // Find DIDL-Lite containers and items
      final containers = xmlSource.findAllElements('container');
      final itemElements = xmlSource.findAllElements('item');
      
      // Parse containers (directories)
      for (final container in containers) {
        final id = container.getAttribute('id');
        final title = container.findElements('dc:title').firstOrNull?.innerText;
        
        if (id != null && title != null) {
          items.add({
            'type': 'container',
            'id': id,
            'title': title,
          });
        }
      }
      
      // Parse items (files)
      for (final item in itemElements) {
        final imageData = _parseImageItem(item);
        if (imageData != null) {
          items.add(imageData);
        }
      }
      
      return items;
    } catch (e) {
      throw XmlParserException('Failed to parse directory content: $e');
    }
  }

  /// Parse a single image item from XML
  static ImageModel? _parseImageItem(XmlElement item) {
    try {
      final id = item.getAttribute('id');
      final title = item.findElements('dc:title').firstOrNull?.innerText;
      
      if (id == null || title == null) return null;
      
      // Parse description and date
      final description = item.findElements('dc:description').firstOrNull?.innerText;
      final dateStr = item.findElements('dc:date').firstOrNull?.innerText;
      DateTime? dateTime;
      if (dateStr != null) {
        try {
          dateTime = DateTime.parse(dateStr);
        } catch (e) {
          // Ignore date parsing errors
        }
      }
      
      // Parse resources (different quality URLs)
      final resources = <ImageQuality, String>{};
      final resElements = item.findAllElements('res');
      
      for (final res in resElements) {
        final url = res.innerText;
        final resolution = res.getAttribute('resolution');
        final protocolInfo = res.getAttribute('protocolInfo');
        
        if (url.isNotEmpty) {
          // Determine quality based on resolution or protocol info
          ImageQuality? quality = _determineImageQuality(resolution, protocolInfo, url);
          if (quality != null) {
            resources[quality] = url;
          }
        }
      }
      
      // Parse size from first resource
      int? size;
      final sizeAttr = resElements.firstOrNull?.getAttribute('size');
      if (sizeAttr != null) {
        size = int.tryParse(sizeAttr);
      }
      
      return ImageModel(
        id: id,
        title: title,
        description: description,
        dateTime: dateTime,
        size: size,
        resources: resources,
      );
    } catch (e) {
      return null;
    }
  }

  /// Determine image quality based on resolution, protocol info, or URL patterns
  static ImageQuality? _determineImageQuality(String? resolution, String? protocolInfo, String url) {
    // Check URL patterns first
    if (url.contains('LRG') || url.contains('large')) {
      return ImageQuality.large;
    } else if (url.contains('SM') || url.contains('small')) {
      return ImageQuality.medium;
    } else if (url.contains('TN') || url.contains('thumb')) {
      return ImageQuality.thumbnail;
    }
    
    // Check resolution if available
    if (resolution != null) {
      final parts = resolution.split('x');
      if (parts.length == 2) {
        final width = int.tryParse(parts[0]);
        if (width != null) {
          if (width >= 2000) {
            return ImageQuality.large;
          } else if (width >= 640) {
            return ImageQuality.medium;
          } else {
            return ImageQuality.thumbnail;
          }
        }
      }
    }
    
    // Check protocol info
    if (protocolInfo != null) {
      if (protocolInfo.contains('LRG')) {
        return ImageQuality.large;
      } else if (protocolInfo.contains('SM')) {
        return ImageQuality.medium;
      } else if (protocolInfo.contains('TN')) {
        return ImageQuality.thumbnail;
      }
    }
    
    // Default to large if we can't determine
    return ImageQuality.large;
  }

  /// Create SOAP envelope for X_TransferStart
  static String createTransferStartRequest() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:X_TransferStart xmlns:u="urn:schemas-sony-com:service:XPushList:1"></u:X_TransferStart>
  </s:Body>
</s:Envelope>''';
  }

  /// Create SOAP envelope for X_TransferEnd
  static String createTransferEndRequest() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:X_TransferEnd xmlns:u="urn:schemas-sony-com:service:XPushList:1">
      <ErrCode>0</ErrCode>
    </u:X_TransferEnd>
  </s:Body>
</s:Envelope>''';
  }

  /// Create SOAP envelope for X_GetContentList
  static String createGetContentListRequest(
    String containerId, {
    int startIndex = 0,
    int requestCount = 200,
  }) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:X_GetContentList xmlns:u="urn:schemas-sony-com:service:XPushList:1">
      <ContainerID>$containerId</ContainerID>
      <StartIndex>$startIndex</StartIndex>
      <RequestCount>$requestCount</RequestCount>
    </u:X_GetContentList>
  </s:Body>
</s:Envelope>''';
  }

  static String createBrowseRequest(
    String containerId, {
    int startIndex = 0,
    int requestCount = 200,
  }) {
    return '''<?xml version="1.0"?>
<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
  <s:Body>
    <u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
      <ObjectID>$containerId</ObjectID>
      <BrowseFlag>BrowseDirectChildren</BrowseFlag>
      <Filter>*</Filter>
      <StartingIndex>$startIndex</StartingIndex>
      <RequestedCount>$requestCount</RequestedCount>
      <SortCriteria></SortCriteria>
    </u:Browse>
  </s:Body>
</s:Envelope>''';
  }

  static SoapBrowseResponse parseSoapEnvelope(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final resultElement = document.findAllElements('Result').firstOrNull;
    final numberReturnedElement =
        document.findAllElements('NumberReturned').firstOrNull;
    final totalMatchesElement =
        document.findAllElements('TotalMatches').firstOrNull;

    final numberReturned =
        int.tryParse(numberReturnedElement?.innerText.trim() ?? '') ?? 0;
    final totalMatches =
        int.tryParse(totalMatchesElement?.innerText.trim() ?? '') ?? 0;

    final resultXml = resultElement?.innerText ?? '';

    return SoapBrowseResponse(
      resultXml: resultXml,
      numberReturned: numberReturned,
      totalMatches: totalMatches,
    );
  }
}

class XmlParserException implements Exception {
  final String message;
  const XmlParserException(this.message);
  
  @override
  String toString() => 'XmlParserException: $message';
}

class SoapBrowseResponse {
  final String resultXml;
  final int numberReturned;
  final int totalMatches;

  const SoapBrowseResponse({
    required this.resultXml,
    required this.numberReturned,
    required this.totalMatches,
  });

  bool hasMore(int startIndex) => startIndex + numberReturned < totalMatches;
}
