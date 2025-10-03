import 'dart:developer' as developer;

const _logName = 'ImagingEdgeNext';

void logDebug(String message, {String name = _logName}) {
  developer.log(message, name: name, level: 500);
}

void logInfo(String message, {String name = _logName}) {
  developer.log(message, name: name);
}

void logWarning(String message, {String name = _logName, Object? error, StackTrace? stackTrace}) {
  developer.log(message, name: name, level: 900, error: error, stackTrace: stackTrace);
}

void logError(
  String message, {
  String name = _logName,
  Object? error,
  StackTrace? stackTrace,
}) {
  developer.log(message, name: name, level: 1000, error: error, stackTrace: stackTrace);
}
