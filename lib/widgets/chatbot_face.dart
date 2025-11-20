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
import 'package:newbuddy/services/firebase_service.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';

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
  bool _isProcessingGrpc = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final WakeWordService _wakeWordService;
  late final CobraVADService _cobraVADService;
  final List<int> _audioBuffer = [];
  final VoiceProcessor? _voiceProcessor = VoiceProcessor.instance;
  StreamController<List<int>>? _audioStreamController;
  StreamSubscription? _grpcStreamSubscription;
  DateTime? _interactionStartTime;

  bool _isListening = false; // True if Wake Word service is active
  bool _isSessionActive = false; // True if in an active interaction session
  bool _isBlushing = false; 
  bool _isTalking = false;
  bool _eyesClosed = false;
  bool _mouthOpen = false;
  bool _isRecording = false; // True if currently capturing user audio
  bool _isVoiceDetected = false;

  Timer? _blinkTimer;
  Timer? _talkingMouthTimer;
  Timer? _vadSilenceTimer;
  Timer? _sessionExpiryTimer; // Timer for session timeout
  
  static const Duration _vadSilenceTimeout = Duration(seconds: 4);
  static const Duration _sessionTimeout = Duration(seconds: 20);

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
    }
  }

  Future<void> _startWakeWordListening() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _log.warning('Microphone permission denied.');
      return;
    }
    try {
      await _wakeWordService.start();
      setState(() {
        _isListening = true;
        _isSessionActive = false; // Reset session state
      });
      _log.info("Wake word engine started (Session Inactive).");    
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
    _startSession();
  }

  void _startSession() async {
    _log.info("Starting new session...");
    setState(() {
      _isSessionActive = true;
    });

    // Start VAD listening using VoiceProcessor and Manual Frame Feeding
    // We do NOT call _cobraVADService.start() because that starts internal recording.
    // Instead, we use start() of the wrapper to ensure event channel is listening, 
    // BUT we modified native code to support 'process' method.
    
    // Actually, we DO need to call start() on the Dart service wrapper to set up the event listener?
    // Looking at cobra_vad_service.dart: start() does `_eventChannel...listen` AND `invokeMethod('startCobra')`.
    // `invokeMethod('startCobra')` starts the native recorder. WE DON'T WANT THAT.
    
    // We need to manually set up the listener without starting native recorder.
    // But `CobraVADService` doesn't expose a method for that.
    // We should have modified `CobraVADService` to separate `listenEvents` from `startNativeRecorder`.
    
    // WORKAROUND: Call start(), but immediately call stop() on native? No.
    // Native `startCobra` starts the thread.
    
    // Better: We should have added `startManual()` to CobraVADService.
    // Since I can't easily change `CobraVADService` interface safely without potentially breaking other things (though I seem to be the only user), 
    // let's rely on the fact that `process` works now.
    
    // Wait, if I call `_cobraVADService.start()`, it starts native recording.
    // If I ALSO run `_voiceProcessor`, they conflict.
    
    // I need to fix `CobraVADService.dart` to allow listening without starting native recorder.
    // OR, I just call `start()` and then ignore the fact that it starts a recorder?
    // No, that causes "Dead IAudioRecord".
    
    // I MUST modify `CobraVADService.dart` to split initialization.
    // OR, I can just duplicate the event listening logic here if `_eventChannel` was public. It's not.
    
    // I will use `_cobraVADService.start()` but I rely on my native fix to NOT crash if `process` is called?
    // No, `start()` starts the native loop which reads from mic.
    
    // I will modify `cobra_vad_service.dart` first to add `startManual()`.
    // Since I am replacing the whole `chatbot_face.dart` file, I will pause this replacement and do `cobra_vad_service.dart` first.
    
    // ... But I can't cancel this tool call easily.
    // I will write the logic assuming `_cobraVADService.startManual()` exists, then I will go implement it.
    
    // Actually, I'll stick to `start()` but I will modify `cobra_vad_service.dart` to accept a flag `manual`?
    
    // For now, let's write the code assuming `startManual` exists.
    
    try {
       // Assuming I add startManual() to CobraVADService
       await _cobraVADService.startManual(); 
       
       _voiceProcessor?.addFrameListener(_vadOnlyFrameListener);
       await _voiceProcessor?.start(512, 16000);
       _log.info("Session VAD listening started (Manual Mode).");
    } catch (e) {
       _log.severe("Error starting session VAD: $e");
    }

    _resetSessionTimer();
  }
  
  void _vadOnlyFrameListener(List<int> frame) {
      if (!_isRecording && _isSessionActive) {
          _cobraVADService.process(frame);
      }
  }

  void _resetSessionTimer() {
    _sessionExpiryTimer?.cancel();
    if (_isSessionActive) {
        _log.info("Session timer reset. Waiting for speech...");
        _sessionExpiryTimer = Timer(_sessionTimeout, _endSession);
    }
  }

  void _endSession() async {
    if (!_isSessionActive) return;
    _log.info("Session timed out due to inactivity.");
    
    _sessionExpiryTimer?.cancel();
    
    _voiceProcessor?.removeFrameListener(_vadOnlyFrameListener);
    await _voiceProcessor?.stop();
    await _cobraVADService.stop(); // Stop listening to events
    
    setState(() {
      _isSessionActive = false;
    });
    
    await _startWakeWordListening();
  }

  void _onVadDetected(double voiceProbability) {
    if (_isRecording) {
      if (voiceProbability > 0.7) {
        _vadSilenceTimer?.cancel();
        _vadSilenceTimer = Timer(_vadSilenceTimeout, _stopRecording);
      }
      return;
    }

    if (_isSessionActive && voiceProbability > 0.5 && !_isVoiceDetected) {
      _log.info("Voice detected in session, starting recording...");
      
      _sessionExpiryTimer?.cancel(); 
      
      setState(() => _isVoiceDetected = true);
      
      // We are already running VoiceProcessor.
      // We switch mode: Remove VAD-only listener, add Recording listener.
      _voiceProcessor?.removeFrameListener(_vadOnlyFrameListener);
      
      _startRecording();
    }
  }

  void _stopAnimation() {
    if (_isTalking) {
      setState(() {
        _isTalking = false;
        _isBlushing = false; 
        _mouthOpen = false;
      });
      _talkingMouthTimer?.cancel();
      _log.info('Audio animation stopped.');
    }
  }

  void _setupAudioPlayerListener() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed || 
          state.processingState == ProcessingState.idle) {
        _stopAnimation();
        if (_isSessionActive) {
            _resetSessionTimer();
             _resumeSessionListening();
        }
      }
    });
  }
  
  void _resumeSessionListening() async {
      if (!_isSessionActive) return;
      _log.info("Resuming session listening after bot speech...");
      
      try {
        _voiceProcessor?.removeFrameListener(_voiceProcessorFrameListener);
        _voiceProcessor?.removeFrameListener(_vadOnlyFrameListener);
        
        // Restart VP for VAD only
        _voiceProcessor?.addFrameListener(_vadOnlyFrameListener);
        
        // Restart capture (it was stopped in _stopRecording)
        await _voiceProcessor?.stop(); // Safety
        await _voiceProcessor?.start(512, 16000);
        
      } catch (e) {
          _log.severe("Error resuming session listening: $e");
      }
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
      _startSession();
    } else if (_isSessionActive) {
       _endSession();
    } else {
       _startWakeWordListening();
    }
  }

  void _startRecording() async {
    _audioBuffer.clear();
    
    _audioStreamController = StreamController<List<int>>();
    
    try {
      _log.info("Starting gRPC speech stream...");
      
      final buddyId = FirebaseService.currentUserModel.id;
      final caregiverId = FirebaseService.caregiverId ?? 'unknown_caregiver';
      
      final responseStream = _grpcClient.processSpeechStream(
        _audioStreamController!.stream, 
        16000,
        caregiverId,
        buddyId
      );
      
      _grpcStreamSubscription = responseStream.listen(
        (response) {
          _log.info("Received stream response: Transcribed: ${response.transcribedText}, LLM: ${response.llmResponse}");
          
          if (response.triggerCall) {
             _log.info("Trigger call detected! Initiating call to caregiver...");
             _initiateCall();
             _endSession(); 
          }
          
          if (response.audioData.isNotEmpty) {
             _playAudioResponse(response.audioData);
          }
        },
        onError: (e) {
          _log.severe('gRPC stream error: $e');
          setState(() => _isBlushing = false);
          if (_isSessionActive) _resumeSessionListening();
        },
        onDone: () {
          _log.info('gRPC stream closed by server.');
        },
      );
    } catch (e) {
      _log.severe('Failed to start gRPC stream: $e');
       return;
    }

    _voiceProcessor?.addFrameListener(_voiceProcessorFrameListener);
    // VP is already running from session start.
    
    setState(() {
      _isRecording = true;
      _isProcessingGrpc = true;
    });
    _log.info("Recording started...");

    _vadSilenceTimer = Timer(_vadSilenceTimeout, _stopRecording);
  }

  Future<void> _initiateCall() async {
    String? caregiverId = FirebaseService.caregiverId;

    if (caregiverId == null) {
      _log.warning("Caregiver ID is null. Attempting to reload...");
      try {
         final buddyId = FirebaseService.currentUserModel.id;
         await FirebaseService.getUserById(buddyId);
         caregiverId = FirebaseService.caregiverId;
      } catch (e) {
         _log.severe("Failed to reload user/caregiver ID: $e");
      }
    }

    if (caregiverId == null) {
      _log.warning("Cannot initiate call: Caregiver ID not found.");
      return;
    }

    String caregiverName = FirebaseService.caregiverName ?? 'Caregiver';
    _log.info("Sending call invitation to caregiver: $caregiverId ($caregiverName)");
    
    await ZegoUIKitPrebuiltCallInvitationService().send(
      invitees: [
        ZegoCallUser(
          caregiverId,
          caregiverName, 
        ),
      ],
      isVideoCall: false, 
    );
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    _interactionStartTime = DateTime.now();
    _log.info("Silence timeout, stopping recording.");

    _vadSilenceTimer?.cancel();
    
    // Stop VP during playback to prevent echo
    await _voiceProcessor?.stop();
    _voiceProcessor?.removeFrameListener(_voiceProcessorFrameListener);

    if (_audioStreamController != null && !_audioStreamController!.isClosed) {
      await _audioStreamController!.close();
      _log.info("Audio stream closed.");
    }

    setState(() {
      _isRecording = false;
      _isVoiceDetected = false;
      _isBlushing = true; 
    });
  }

  void _voiceProcessorFrameListener(List<int> frame) {
    if (_isRecording) {
      _cobraVADService.process(frame);
      if (_audioStreamController != null && !_audioStreamController!.isClosed) {
         final pcm16 = Int16List.fromList(frame);
         final bytes = pcm16.buffer.asUint8List();
         _audioStreamController!.add(bytes);
      }
    }
  }

  Future<void> _playAudioResponse(List<int> pcmBytes) async {
    _log.info('Preparing to play ${pcmBytes.length} bytes of PCM audio.');
    
    _sessionExpiryTimer?.cancel();
    
    try {
      const sampleRate = 24000;
      const numChannels = 1;
      const bitsPerSample = 16;

      final header = _generateWavHeader(pcmBytes.length, numChannels, sampleRate, bitsPerSample);
      final wavBytes = header + pcmBytes;

      _stopAnimation();

      await _audioPlayer.setAudioSource(BytesAudioSource(wavBytes));
      _audioPlayer.play();
      
      if (_interactionStartTime != null) {
        final latency = DateTime.now().difference(_interactionStartTime!);
        _log.info('LATENCY (End of speech -> Start of playback): ${(latency.inMilliseconds / 1000).toStringAsFixed(2)} seconds');
      }

      setState(() => _isTalking = true);

      _talkingMouthTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) {
          setState(() => _mouthOpen = !_mouthOpen);
        }
      });
    } catch (e) {
      _log.severe('Error playing audio response: $e');
      _stopAnimation();
      if (_isSessionActive) _resumeSessionListening();
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
    _sessionExpiryTimer?.cancel();
    _grpcStreamSubscription?.cancel(); 
    _grpcClient.shutdown();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _wakeWordService.dispose();
    _cobraVADService.dispose();
    _voiceProcessor?.removeFrameListener(_voiceProcessorFrameListener);
    _voiceProcessor?.removeFrameListener(_vadOnlyFrameListener);
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

  Widget _buildCheek() {
    return Opacity(
      opacity: _isBlushing ? 1.0 : 0.0,
      child: Container(
        width: 60,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.pink.withOpacity(0.3),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.pink.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 5,
            )
          ],
        ),
      ),
    );
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
          // Cheeks
          Positioned(
            top: size.height * 0.32,
            left: size.width * 0.12,
            child: _buildCheek(),
          ),
          Positioned(
            top: size.height * 0.32,
            right: size.width * 0.12,
            child: _buildCheek(),
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
                // CircularProgressIndicator removed
                // _responseMessage text removed
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
                      ? 'Listening for Wake Word...'
                      : _isSessionActive 
                          ? 'Session Active (Listening)' 
                          : 'Services stopped.',
                  iconSize: 36,
                  icon: Icon(
                    _isListening ? Icons.hearing : (_isSessionActive ? Icons.mic : Icons.mic_off),
                    color: _isSessionActive ? Colors.green : (_isListening ? Colors.red : null),
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