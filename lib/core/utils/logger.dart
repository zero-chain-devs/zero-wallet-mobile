import 'package:logger/logger.dart';

/// Application logger
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Verbose logging
  static void verbose(dynamic message, [dynamic error]) {
    _logger.t(message, error: error, stackTrace: StackTrace.current);
  }

  /// Debug logging
  static void debug(dynamic message, [dynamic error]) {
    _logger.d(message, error: error, stackTrace: StackTrace.current);
  }

  /// Info logging
  static void info(dynamic message, [dynamic error]) {
    _logger.i(message, error: error, stackTrace: StackTrace.current);
  }

  /// Warning logging
  static void warning(dynamic message, [dynamic error]) {
    _logger.w(message, error: error, stackTrace: StackTrace.current);
  }

  /// Error logging
  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(
      message,
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
    );
  }

  /// WTF logging (critical errors)
  static void wtf(dynamic message, [dynamic error]) {
    _logger.f(message, error: error, stackTrace: StackTrace.current);
  }
}
