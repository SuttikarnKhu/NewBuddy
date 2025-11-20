import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

class CobraVADService {
  static const MethodChannel _methodChannel = MethodChannel('com.example.newbuddy/cobra_vad');
  static const EventChannel _eventChannel = EventChannel('com.example.newbuddy/cobra_vad_events');
  final _log = Logger('CobraVADService');
  final Function(double) _vadCallback;
  StreamSubscription? _vadSubscription;

  CobraVADService({required Function(double) onVad}) : _vadCallback = onVad;

  Future<void> init(String accessKey) async {
    try {
      await _methodChannel.invokeMethod('initCobra', {'accessKey': accessKey});
      _log.info('Cobra VAD service initialized.');
    } on PlatformException catch (e) {
      _log.severe('Failed to initialize Cobra VAD: ${e.message}');
      rethrow;
    }
  }

  Future<void> start() async {
    try {
      _vadSubscription = _eventChannel.receiveBroadcastStream().cast<double>().listen(
        (voiceProbability) {
          _vadCallback(voiceProbability);
        },
        onError: (error) {
          _log.severe("VAD event channel error: $error");
        },
      );
      await _methodChannel.invokeMethod('startCobra');
      _log.info('Cobra VAD started and listening to events.');
    } on PlatformException catch (e) {
      _log.severe('Failed to start Cobra VAD: ${e.message}');
    }
  }

  Future<void> startManual() async {
    try {
      _vadSubscription = _eventChannel.receiveBroadcastStream().cast<double>().listen(
        (voiceProbability) {
          _vadCallback(voiceProbability);
        },
        onError: (error) {
          _log.severe("VAD event channel error: $error");
        },
      );
      // Do NOT invoke 'startCobra' here. We only want to listen to events from manual processing.
      _log.info('Cobra VAD started (Manual Mode) and listening to events.');
    } on PlatformException catch (e) {
      _log.severe('Failed to start Cobra VAD (Manual): ${e.message}');
    }
  }

  Future<void> process(List<int> frame) async {
    try {
      // Convert List<int> (which is int16) to Uint8List (byte array)
      final pcm16 = Int16List.fromList(frame);
      final bytes = pcm16.buffer.asUint8List();

      await _methodChannel.invokeMethod('process', {'frame': bytes});
    } on PlatformException catch (e) {
      _log.severe('Failed to process frame with Cobra: ${e.message}');
    }
  }

  Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod('stopCobra');
      await _vadSubscription?.cancel();
      _vadSubscription = null;
      _log.info('Cobra VAD stopped.');
    } on PlatformException catch (e) {
      _log.severe('Failed to stop Cobra VAD: ${e.message}');
    }
  }

  Future<void> dispose() async {
    try {
      await _vadSubscription?.cancel();
      await _methodChannel.invokeMethod('disposeCobra');
      _log.info('Cobra VAD disposed.');
    } on PlatformException catch (e) {
      _log.severe('Failed to dispose Cobra VAD: ${e.message}');
    }
  }
}