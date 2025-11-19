import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:logging/logging.dart';
import 'package:newbuddy/constants/picovoice.dart';

class WakeWordService {
  final _log = Logger('WakeWordService');
  PorcupineManager? _porcupineManager;
  final Function(int) _wakeWordCallback;
  bool _isListening = false;
  static const String _keywordAssetPath = "assets/jao-buddy_en_android_v3_0_0.ppn";

  bool get isListening => _isListening;

  WakeWordService({required Function(int) onWakeWord})
      : _wakeWordCallback = onWakeWord;

  Future<void> init() async {
    if (_porcupineManager != null) {
      return;
    }
    try {
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        picovoiceAccessKey,
        [_keywordAssetPath],
        _wakeWordCallback,
        errorCallback: _errorCallback,
      );
    } on PorcupineException catch (err) {
      // Handle initialization error
      _log.info("Failed to initialize Porcupine: ${err.message}");
      rethrow;
    }
  }

  /// Starts listening for the wake word.
  Future<void> start() async {
    if (_porcupineManager == null) {
      _log.warning("Porcupine not initialized. Call init() first.");
      throw Exception("Porcupine not initialized. Call init() first.");
    }
    if (!_isListening) {
      try {
        await _porcupineManager?.start();
        _isListening = true;
        _log.info("Wake word listener started successfully.");
      } on PorcupineException catch (ex) {
        _log.severe("Failed to start listening: ${ex.message}");
      }
    } else {
      _log.info("Wake word listener was already running.");
    }
  }

  /// Stops listening for the wake word.
  Future<void> stop() async {
    if (_isListening) {
      await _porcupineManager?.stop();
      _isListening = false;
      _log.info("Wake word listener stopped.");
    }
  }

  /// Releases resources used by the Porcupine engine.
  Future<void> dispose() async {
    await _porcupineManager?.delete();
    _porcupineManager = null;
  }

  /// Callback for errors that occur while processing audio.
  void _errorCallback(PorcupineException error) {
    _log.info("Porcupine error: ${error.message}");
  }
}
