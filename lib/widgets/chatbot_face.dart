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
import 'package:newbuddy/src/cobra_vad_service.dart';
import 'package:newbuddy/constants/picovoice.dart';
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
  String _responseMessage = 'Initializing...';
  bool _isProcessingGrpc = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final WakeWordService _wakeWordService;
  late final CobraVADService _cobraVADService;
  final List<int> _audioBuffer = [];
  final VoiceProcessor? _voiceProcessor = VoiceProcessor.instance;
  StreamController<List<int>>? _audioStreamController;
  StreamSubscription? _grpcStreamSubscription;

  bool _isListening = false;
  bool _isTalking = false;
  bool _eyesClosed = false;
  bool _mouthOpen = false;
  bool _isRecording = false;
  bool _isVoiceDetected = false;

  Timer? _blinkTimer;
  Timer? _talkingMouthTimer;
  Timer? _vadSilenceTimer;
  static const Duration _vadSilenceTimeout = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _wakeWordService = WakeWordService(onWakeWord: _onWakeWordDetected);
    _cobraVADService = CobraVADService(onVad: _onVadDetected);
    _initServices();
    _startBlinking();
    _setupAudioPlayerListener();
    _log.info('ChatBotFace initialized.');
  }

  Future<void> _initServices() async {
    try {
      await _wakeWordService.init();
      await _cobraVADService.init(picovoiceAccessKey);
      await _startWakeWordListening();
    } catch (e) {
      _log.severe('Failed to initialize services: $e');
      setState(() {
        _responseMessage = 'Failed to initialize services.';
      });
    }
  }

  Future<void> _startWakeWordListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _log.warning('Microphone permission denied.');
      setState(() {
        _responseMessage = 'Microphone permission denied.';
      });
      return;
    }
    try {
      await _wakeWordService.start();
      setState(() {
        _isListening = true;
        _responseMessage = 'Listening for wake word...';
      });
      _log.info("Wake word engine started.");
    } catch (e) {
      _log.severe("Failed to start wake word listener: $e");
    }
  }

  Future<void> _stopWakeWordListening() async {
    try {
      await _wakeWordService.stop();
      setState(() {
        _isListening = false;
      });
      _log.info("Wake word engine stopped.");
    } catch (e) {
      _log.severe("Failed to stop wake word listener: $e");
    }
  }

  void _onWakeWordDetected(int keywordIndex) async {
    _log.info(">>>>>> WAKE WORD DETECTED! <<<<<<");
    await _stopWakeWordListening();

    // Handoff to VAD
    await _cobraVADService.start();
    setState(() {
      _responseMessage = "Wake word detected! Speak now.";
    });
    _log.info("Cobra VAD started.");
  }

  void _onVadDetected(double voiceProbability) {
    _log.info("VAD Probability: $voiceProbability");
    if (_isRecording) {
      // While recording, VAD just resets the silence timer
      if (voiceProbability > 0.5) {
        _vadSilenceTimer?.cancel();
        _vadSilenceTimer = Timer(_vadSilenceTimeout, _stopRecording);
      }
      return;
    }

    if (voiceProbability > 0.5 && !_isVoiceDetected) {
      _log.info("Voice detected, starting recording...");
      setState(() => _isVoiceDetected = true);
      _startRecording();
    }
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
    if (_isListening) {
      await _stopWakeWordListening();
      setState(() => _responseMessage = "Services stopped.");
    } else {
      await _startWakeWordListening();
    }
  }

  void _startRecording() async {
    _audioBuffer.clear();
    
    // Initialize stream controller for gRPC
    _audioStreamController = StreamController<List<int>>();
    
    // Start the bidirectional stream
    try {
      _log.info("Starting gRPC speech stream...");
      final responseStream = _grpcClient.processSpeechStream(_audioStreamController!.stream, 16000);
      
      _grpcStreamSubscription = responseStream.listen(
        (response) {
          _log.info("Received stream response: ${response.transcribedText}");
          setState(() {
            _responseMessage = 'Transcribed: ${response.transcribedText}\nLLM: ${response.llmResponse}';
            _isProcessingGrpc = false; // Ensure spinner is off if it was on
          });
          
          if (response.audioData.isNotEmpty) {
             _playAudioResponse(response.audioData);
          }
        },
        onError: (e) {
          _log.severe('gRPC stream error: $e');
          setState(() => _responseMessage = 'Error: $e');
        },
        onDone: () {
          _log.info('gRPC stream closed by server.');
        },
      );
    } catch (e) {
      _log.severe('Failed to start gRPC stream: $e');
       setState(() => _responseMessage = 'Connection failed.');
       return;
    }

    _voiceProcessor?.addFrameListener(_voiceProcessorFrameListener);
    await _voiceProcessor?.start(512, 16000);
    setState(() {
      _isRecording = true;
      _responseMessage = 'Recording...';
      _isProcessingGrpc = true; // Optional: Show processing state while streaming
    });
    _log.info("Recording started...");

    // Start silence timer
    _vadSilenceTimer = Timer(_vadSilenceTimeout, _stopRecording);
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    _log.info("Silence timeout, stopping recording.");

    _vadSilenceTimer?.cancel();
    await _voiceProcessor?.stop();
    _voiceProcessor?.removeFrameListener(_voiceProcessorFrameListener);

    // Close the stream to signal end of audio to server
    if (_audioStreamController != null && !_audioStreamController!.isClosed) {
      await _audioStreamController!.close();
      _log.info("Audio stream closed.");
    }
    // Note: We do NOT cancel _grpcStreamSubscription here immediately, 
    // because the server might still be sending the final response.
    // It will complete on its own or we can cancel it when we start a new session.

    setState(() {
      _isRecording = false;
      _isVoiceDetected = false;
      // _isProcessingGrpc = false; // Keep true if waiting for final response?
    });

    // Handoff back to wake word
    await _cobraVADService.stop();
    _log.info("Cobra VAD stopped.");
    await _startWakeWordListening();
  }

  void _voiceProcessorFrameListener(List<int> frame) {
    // While recording, we feed the audio to both the buffer and the VAD
    if (_isRecording) {
      // _audioBuffer.addAll(frame); // Buffer is less critical now, but good for debug
      _cobraVADService.process(frame);

      // Convert Int16 PCM to Bytes for gRPC stream
      if (_audioStreamController != null && !_audioStreamController!.isClosed) {
         final pcm16 = Int16List.fromList(frame);
         final bytes = pcm16.buffer.asUint8List();
         _audioStreamController!.add(bytes);
      }
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
    _vadSilenceTimer?.cancel();
    _grpcStreamSubscription?.cancel(); // Cancel stream subscription
    _grpcClient.shutdown();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _wakeWordService.dispose();
    _cobraVADService.dispose();
    _voiceProcessor?.removeFrameListener(_voiceProcessorFrameListener);
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
                  tooltip: _isListening
                      ? 'Listening...'
                      : 'Services stopped. Tap to start.',
                  iconSize: 36,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_off,
                    color: _isListening ? Colors.red : null,
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