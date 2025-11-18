import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../screens/join_screen.dart';
import 'package:newbuddy/grpc_client.dart';
import 'package:logging/logging.dart';
import 'package:newbuddy/src/wake_word_service.dart';
import 'package:flutter_voice_processor/flutter_voice_processor.dart';

class BytesAudioSource extends StreamAudioSource {
  final List<int> _bytes;

  BytesAudioSource(this._bytes) : super(tag: 'BytesAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

class ChatBotFace extends StatefulWidget {
  const ChatBotFace({super.key});

  @override
  State<ChatBotFace> createState() => _ChatBotFaceState();
}

class _ChatBotFaceState extends State<ChatBotFace> with TickerProviderStateMixin {
  final GrpcClient _grpcClient = GrpcClient();
  final _log = Logger('ChatBotFace');
  String _responseMessage = 'Ready to listen...';
  bool _isProcessingGrpc = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final WakeWordService _wakeWordService;
  final List<int> _audioBuffer = [];
  final VoiceProcessor? _voiceProcessor = VoiceProcessor.instance;
  bool _isListeningForWakeWord = false;
  bool _isTalking = false;
  bool _eyesClosed = false;
  bool _mouthOpen = false;
  bool _isRecording = false;

  Timer? _blinkTimer;
  Timer? _talkingMouthTimer;

  @override
  void initState() {
    super.initState();
    _wakeWordService = WakeWordService(onWakeWord: _onWakeWordDetected);
    _initServices();

    _startBlinking();
    _setupAudioPlayerListener();
    _log.info('ChatBotFace initialized.');
  }

  Future<void> _initServices() async {
    try {
      await _wakeWordService.init();
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        _log.warning('Microphone permission denied. Cannot start services.');
        setState(() {
          _responseMessage = 'Microphone permission denied.';
        });
        return;
      }
      await _wakeWordService.start();
      setState(() {
        _isListeningForWakeWord = true;
        _responseMessage = 'Listening for wake word...';
      });
    } catch (e) {
      _log.severe('Failed to start services on init: $e');
      setState(() {
        _responseMessage = 'Could not start services.';
      });
    }
  }

  void _onWakeWordDetected(int keywordIndex) {
    _log.info(">>>>>> WAKE WORD DETECTED! <<<<<<");
    setState(() {
      _isListeningForWakeWord = false;
      _responseMessage = "Wake word detected! Press mic to record.";
    });
  }

  void _setupAudioPlayerListener() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        setState(() => _isTalking = false);
        _talkingMouthTimer?.cancel();
        _log.info('Audio playback completed.');
      }
    });
  }

  void _startBlinking() {
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      setState(() => _eyesClosed = true);
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _eyesClosed = false);
    });
  }

  Future<void> _handleMicPressed() async {
    if (_isRecording) {
      await _stopRecording();
    } else if (!_isListeningForWakeWord) {
      await _startRecording();
    } else {
      // Toggle wake word listening
      if (_isListeningForWakeWord) {
        await _wakeWordService.stop();
        setState(() {
          _isListeningForWakeWord = false;
          _responseMessage = 'Ready to listen...';
        });
      } else {
        try {
          await _wakeWordService.start();
          setState(() {
            _isListeningForWakeWord = true;
            _responseMessage = 'Listening for wake word...';
          });
        } catch (e) {
          _log.severe('Error starting wake word listener: $e');
          setState(() {
            _responseMessage = 'Error: Could not start listener.';
          });
        }
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      _audioBuffer.clear();
      _voiceProcessor?.addFrameListener(_voiceProcessorFrameListener);
      // These values should be based on what the gRPC server expects.
      // Using common values for now.
      await _voiceProcessor?.start(512, 16000);
      setState(() {
        _isRecording = true;
        _responseMessage = 'Recording... Press mic to stop.';
      });
      _log.info('Recording started for STT.');
    } catch (e) {
      _log.severe('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _voiceProcessor?.removeFrameListener(_voiceProcessorFrameListener);
    await _voiceProcessor?.stop();

    setState(() => _isRecording = false);
    _log.info('Recording stopped. Processing buffered audio.');

    if (_audioBuffer.isNotEmpty) {
      _processRecordedAudio(_audioBuffer.toList());
      _audioBuffer.clear();
    }

    // Go back to listening for wake word
    await _wakeWordService.start();
    setState(() {
      _isListeningForWakeWord = true;
      _responseMessage = 'Listening for wake word...';
    });
  }

  void _voiceProcessorFrameListener(List<int> frame) {
    _audioBuffer.addAll(frame);
  }

  Future<void> _processRecordedAudio(List<int> audioData) async {
    if (_isProcessingGrpc) return;

    setState(() {
      _isProcessingGrpc = true;
      _responseMessage = 'Processing audio...';
    });
    _log.info('UI State: Processing audio for gRPC...');

    try {
      const sampleRate = 16000;

      _log.info('Calling gRPC service with ${audioData.length} bytes of audio data.');
      final response = await _grpcClient.processSpeech(audioData, sampleRate);

      setState(() {
        _responseMessage = '''Transcribed: ${response.transcribedText}
LLM Response: ${response.llmResponse}''';
        _isProcessingGrpc = false;
      });
      _log.info('UI State: gRPC response received.');

      if (response.audioData.isNotEmpty) {
        _playAudioResponse(response.audioData);
      }
    } catch (e) {
      setState(() {
        _responseMessage = 'Error: $e';
        _isProcessingGrpc = false;
      });
      _log.severe('UI State: gRPC call error: $e', e);
    }
  }

  Future<void> _playAudioResponse(List<int> pcmBytes) async {
    _log.info('Preparing to play ${pcmBytes.length} bytes of PCM audio.');
    try {
      const sampleRate = 24000;
      const numChannels = 1;
      const bitsPerSample = 16;

      final header = _generateWavHeader(pcmBytes.length, numChannels, sampleRate, bitsPerSample);
      final wavBytes = header + pcmBytes;

      await _audioPlayer.setAudioSource(BytesAudioSource(wavBytes));
      _audioPlayer.play();

      setState(() => _isTalking = true);

      _talkingMouthTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) {
          setState(() => _mouthOpen = !_mouthOpen);
        }
      });
    } catch (e) {
      _log.severe('Error playing audio response: $e');
    }
  }

  Uint8List _generateWavHeader(int dataLength, int numChannels, int sampleRate, int bitsPerSample) {
    final byteRate = (sampleRate * numChannels * bitsPerSample) ~/ 8;
    final blockAlign = (numChannels * bitsPerSample) ~/ 8;
    final totalDataLen = dataLength + 36;

    final buffer = ByteData(44);
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, totalDataLen, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6d); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Sub-chunk size
    buffer.setUint16(20, 1, Endian.little); // Audio format (1 for PCM)
    buffer.setUint16(22, numChannels, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, byteRate, Endian.little);
    buffer.setUint16(32, blockAlign, Endian.little);
    buffer.setUint16(34, bitsPerSample, Endian.little);
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataLength, Endian.little);

    return buffer.buffer.asUint8List();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _talkingMouthTimer?.cancel();
    _grpcClient.shutdown();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _wakeWordService.dispose();
    _voiceProcessor?.stop();
    _log.info('ChatBotFace disposed, clients and players shut down.');
    super.dispose();
  }

  Widget _buildEye(bool isClosed) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: 30,
      height: isClosed ? 4 : 30,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }

  Widget _buildMouth() {
    if (_isTalking && _mouthOpen) {
      return Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
        ),
      );
    } else {
      return Container(
        width: 90,
        height: 45,
        decoration: BoxDecoration(
          border: const Border(
            bottom: BorderSide(width: 6, color: Colors.black),
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(90)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      width: double.infinity,
      height: size.height,
      child: Stack(
        children: [
          // Face background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.yellow.shade300,
              shape: BoxShape.rectangle,
            ),
          ),
          // Eyes
          Positioned(
            top: size.height * 0.22,
            left: size.width * 0.25 - 15,
            child: _buildEye(_eyesClosed),
          ),
          Positioned(
            top: size.height * 0.22,
            right: size.width * 0.25 - 15,
            child: _buildEye(_eyesClosed),
          ),
          // Mouth
          Positioned(
            top: size.height * 0.60,
            left: (size.width / 2) - 45,
            child: _buildMouth(),
          ),
          // gRPC Response Display and Loading Indicator
          Positioned(
            top: size.height * 0.45,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_isProcessingGrpc)
                  const CircularProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _responseMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
          // Microphone button
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: _isRecording
                      ? 'Stop recording'
                      : _isListeningForWakeWord
                          ? 'Listening for wake word...'
                          : 'Start recording',
                  iconSize: 36,
                  icon: Icon(
                    _isRecording || _isListeningForWakeWord
                        ? Icons.mic
                        : Icons.mic_none,
                    color: _isRecording || _isListeningForWakeWord
                        ? Colors.red
                        : null,
                  ),
                  onPressed: _handleMicPressed,
                ),
              ],
            ),
          ),
          // Video call button (top-right)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Start call',
              iconSize: 28,
              icon: const Icon(Icons.video_call, color: Colors.black),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
