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
import 'package:newbuddy/services/reminder_service.dart';
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
  ValueNotifier<ZegoUIKitRoomState>? _roomStateNotifier; 
  
  DateTime? _interactionStartTime;
  DateTime? _lastRecordingEndTime; 
  bool _isListenerAttached = false; 

  // NUCLEAR LOOP PROTECTION FLAGS
  bool _isAudioPlaying = false; 
  bool _postPlaybackCooldown = false;

  bool _isListening = false; 
  bool _isSessionActive = false; 
  bool _isBlushing = false; 
  bool _isTalking = false;
  bool _eyesClosed = false;
  bool _mouthOpen = false;
  bool _isRecording = false; 
  bool _isVoiceDetected = false;
  bool _pendingCall = false; 

  Timer? _blinkTimer;
  Timer? _talkingMouthTimer;
  Timer? _vadSilenceTimer;
  Timer? _sessionExpiryTimer; 
  Timer? _callCheckTimer; 
  Timer? _postPlaybackMuteTimer; // Declared at class level
  
  static const Duration _vadSilenceTimeout = Duration(seconds: 4);
  static const Duration _sessionTimeout = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    _wakeWordService = WakeWordService(onWakeWord: _onWakeWordDetected);
    _cobraVADService = CobraVADService(onVad: _onVadDetected);
    _initServices();
    _startBlinking();
    _setupAudioPlayerListener();
    
    // Listen for Zego call events (Room State) using ValueNotifier
    _roomStateNotifier = ZegoUIKit().getRoomStateStream();
    _roomStateNotifier?.addListener(_onZegoRoomStateChanged);
    
    _log.info('ChatBotFace initialized.');
  }

  Future<void> _restartServices() async {
      _log.info(">>> RESTARTING SERVICES (Hard Reset) <<<");
      
      // 1. Force Stop Everything
      _sessionExpiryTimer?.cancel();
      _vadSilenceTimer?.cancel();
      _callCheckTimer?.cancel(); 
      _voiceProcessor?.removeFrameListener(_onAudioFrame);
      _isListenerAttached = false;
      await _voiceProcessor?.stop();
      await _cobraVADService.stop();
      await _wakeWordService.stop();

      // 2. Reset Flags
      if (mounted) {
        setState(() {
          _isSessionActive = false;
          _isRecording = false;
          _isVoiceDetected = false;
          _isProcessingGrpc = false;
          _isTalking = false;
          _isBlushing = false;
          _isListening = false; 
          _isAudioPlaying = false;
          _postPlaybackCooldown = false;
        });
      }

      // 3. Re-initialize and Start
      await _initServices();
      _log.info("Services restarted. Listening for Wake Word.");
  }

  void _startCallStatusPolling() {
    _callCheckTimer?.cancel();
    _callCheckTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
       if (timer.tick < 5) return;
       
       if (ZegoUIKit().getRoom().id.isEmpty) {
          _log.info("Polling: Not in room (ID empty). Call ended. Restarting services.");
          timer.cancel();
          _restartServices();
       }
    });
  }

  void _onZegoRoomStateChanged() {
    final state = _roomStateNotifier?.value;
    if (state == null) return;

    _log.info("Zego Room State: ${state.reason}");
    
    if (state.reason == ZegoRoomStateChangedReason.Logout || 
        state.reason == ZegoRoomStateChangedReason.KickOut ||
        state.reason == ZegoRoomStateChangedReason.ReconnectFailed) {
        
        _log.info("Call ended detected. Initiating restart sequence...");
        
        Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
               _restartServices();
            }
        });
    }
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
      if (mounted) {
        setState(() {
          _isListening = true;
          _isSessionActive = false; // Reset session state
        });
      }
      _log.info("Wake word engine started (Session Inactive).");    
    } catch (e) {
      _log.severe("Failed to start wake word listener: $e");
    }
  }

  Future<void> _stopWakeWordListening() async {
    try {
      await _wakeWordService.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
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
    if (mounted) {
      setState(() {
        _isSessionActive = true;
      });
    }

    try {
       await _cobraVADService.start(); 
       
       _voiceProcessor?.removeFrameListener(_onAudioFrame); 
       _voiceProcessor?.addFrameListener(_onAudioFrame);
       _isListenerAttached = true;
       await _voiceProcessor?.start(512, 16000);
       _log.info("Session VAD listening started.");
    } catch (e) {
       _log.severe("Error starting session VAD: $e");
    }

    _resetSessionTimer();
  }
  
  void _onAudioFrame(List<int> frame) {
      // 1. ABSOLUTE GATEKEEPER
      if (_isAudioPlaying || _postPlaybackCooldown) {
          return; // Drop frame immediately
      }
      
      if (_isTalking) return;

      if (!_isSessionActive) return;

      _cobraVADService.process(frame);

      if (_isRecording) {
          if (_audioStreamController != null && !_audioStreamController!.isClosed) {
             final pcm16 = Int16List.fromList(frame);
             final bytes = pcm16.buffer.asUint8List();
             _audioStreamController!.add(bytes);
          }
      }
  }

  void _resetSessionTimer() {
    _sessionExpiryTimer?.cancel();
    if (_isSessionActive) {
        _log.info("Session timer reset. Waiting for speech...");
        _sessionExpiryTimer = Timer(_sessionTimeout, _endSession);
    }
  }

  void _endSession({bool restartWakeWord = true}) async {
    if (!_isSessionActive) return;
    _log.info("Ending session. Restart WakeWord: $restartWakeWord");
    
    _sessionExpiryTimer?.cancel();
    
    if (_isRecording) {
      _log.info("Force stopping recording during session end.");
      _vadSilenceTimer?.cancel();
      if (_audioStreamController != null && !_audioStreamController!.isClosed) {
        await _audioStreamController!.close();
      }
      if (mounted) {
        setState(() {
          _isRecording = false;
        });
      }
    }
    
    _voiceProcessor?.removeFrameListener(_onAudioFrame);
    _isListenerAttached = false;
    await _voiceProcessor?.stop();
    await _cobraVADService.stop(); 
    
    if (mounted) {
      setState(() {
        _isSessionActive = false;
        _isVoiceDetected = false;
        _isRecording = false; 
        _isProcessingGrpc = false;
      });
    }
    
    if (restartWakeWord) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _startWakeWordListening();
    } else {
      _log.info("Wake Word NOT restarted (likely due to incoming call).");
    }
  }

  void _onVadDetected(double voiceProbability) {
    if (_isTalking || _isAudioPlaying || _postPlaybackCooldown) return;
    
    if (_lastRecordingEndTime != null && 
        DateTime.now().difference(_lastRecordingEndTime!) < const Duration(milliseconds: 1500)) {
      return;
    }

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
      
      if (mounted) setState(() => _isVoiceDetected = true);
      
      _startRecording();
    }
  }

  void _stopAnimation() {
    if (_isTalking) {
      if (mounted) {
        setState(() {
          _isTalking = false;
          _isBlushing = false; 
          _mouthOpen = false;
        });
      }
      _talkingMouthTimer?.cancel();
      _log.info('Audio animation stopped.');
    }
  }

  void _setupAudioPlayerListener() {
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed || 
          state.processingState == ProcessingState.idle) {
        
        // Audio physically finished. Now start the cooldown.
        if (_isAudioPlaying) {
            _log.info("Audio playback completed. Starting 2s cooldown.");
            if (mounted) {
              setState(() {
                _isAudioPlaying = false;
                _postPlaybackCooldown = true;
                _isTalking = false; // Stop animation
                _mouthOpen = false;
              });
            }
            
            // Wait for echo to die down
            Timer(const Duration(milliseconds: 2000), () async {
               _log.info("Cooldown expired. Listening resumed.");
               if (mounted) {
                 setState(() => _postPlaybackCooldown = false);
               }
               
               // Handle pending call AFTER cooldown to ensure clean break
               if (_pendingCall) {
                   _log.info("Cooldown done. Executing pending call.");
                   _pendingCall = false;
                   await _initiateCall();
               } else if (_isSessionActive) {
                   _resumeSessionListening(); 
               }
            });
        }
      }
    });
  }
  
  void _resumeSessionListening() async {
      if (!_isSessionActive) return;
      
      _log.info("Resuming session listening... Waiting for echo decay.");
      
      // Wait for room echo to die down
      await Future.delayed(const Duration(milliseconds: 2000));
      
      try {
        // Start Hardware FIRST (to flush buffer)
        await _voiceProcessor?.stop(); 
        await _voiceProcessor?.start(512, 16000);
        
        // Wait 1.5s to flush "pop" and stale frames
        await Future.delayed(const Duration(milliseconds: 1500));
        
        // ATTACH LISTENER
        if (!_isListenerAttached && _isSessionActive) {
            _voiceProcessor?.removeFrameListener(_onAudioFrame); 
            _voiceProcessor?.addFrameListener(_onAudioFrame);
            _isListenerAttached = true;
            _log.info("Listener attached. Ready for user input.");
        }
        
      } catch (e) {
          _log.severe("Error resuming session listening: $e");
      }
  }

  void _startBlinking() {
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (mounted) setState(() => _eyesClosed = true);
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
    // Do NOT reset pendingCall here; it comes from stream logic
    
    _audioStreamController = StreamController<List<int>>();
    
    try {
      _log.info("Starting gRPC speech stream...");
      
      final buddyId = FirebaseService.currentUserModel.id;
      final caregiverId = FirebaseService.caregiverId;

      if (caregiverId == null || caregiverId == 'unknown_caregiver') {
        _log.warning("Abort recording: Caregiver ID is unknown.");
        await _audioStreamController?.close();
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isProcessingGrpc = false;
          });
        }
        return;
      }
      
      final activeReminders = ReminderService.instance.getActiveRemindersText();

      final responseStream = _grpcClient.processSpeechStream(
        _audioStreamController!.stream, 
        16000,
        caregiverId,
        buddyId,
        activeReminders
      );
      
      _grpcStreamSubscription = responseStream.listen(
        (response) {
          _log.info("Received stream response: Transcribed: ${response.transcribedText}, LLM: ${response.llmResponse}, TriggerCall: ${response.triggerCall}");
          
          if (response.triggerCall) {
             _log.info("Trigger call detected!");
             _pendingCall = true;
             _endSession(restartWakeWord: false); 
          }
          
          if (response.audioData.isNotEmpty) {
             _playAudioResponse(response.audioData);
          } else if (_pendingCall) {
             // If no audio but call triggered, execute immediately (via listener logic simulation or direct call)
             // We can simulate playback finish to trigger the flow
             _log.info("No audio with trigger call, initiating call immediately.");
             _initiateCall();
             _pendingCall = false;
          }
        },
        onError: (e) {
          _log.severe('gRPC stream error: $e');
          if (mounted) setState(() => _isBlushing = false);
          if (_isSessionActive) _resumeSessionListening();
          _pendingCall = false; 
        },
        onDone: () {
          _log.info('gRPC stream closed by server.');
        },
      );
    } catch (e) {
      _log.severe('Failed to start gRPC stream: $e');
       return;
    }

    if (mounted) {
      setState(() {
        _isRecording = true;
        _isProcessingGrpc = true;
      });
    }
    _log.info("Recording started...");

    _vadSilenceTimer = Timer(_vadSilenceTimeout, _stopRecording);
  }

  Future<void> _initiateCall() async {
    _log.info(">>> _initiateCall STARTED <<<");
    
    // STRICT CLEANUP
    _sessionExpiryTimer?.cancel();
    _vadSilenceTimer?.cancel();
    _voiceProcessor?.removeFrameListener(_onAudioFrame);
    await _voiceProcessor?.stop();
    await _cobraVADService.stop();
    await _wakeWordService.stop();
    
    if (mounted) {
      setState(() {
        _isListening = false;
        _isSessionActive = false;
        _isRecording = false;
      });
    }
    
    _startCallStatusPolling();

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
      _log.severe("Cannot initiate call: Caregiver ID not found after reload.");
      _restartServices();
      return;
    }

    String caregiverName = FirebaseService.caregiverName ?? 'Caregiver';
    _log.info("Sending call invitation to caregiver: $caregiverId ($caregiverName)");
    
    try {
      await ZegoUIKitPrebuiltCallInvitationService().send(
        invitees: [
          ZegoCallUser(
            caregiverId,
            caregiverName, 
          ),
        ],
        isVideoCall: false, 
      );
      _log.info("Zego call invitation sent successfully.");
    } catch (e) {
      _log.severe("Error sending Zego invitation: $e");
      _restartServices();
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;
    _interactionStartTime = DateTime.now();
    _lastRecordingEndTime = DateTime.now(); 
    _log.info("Silence timeout, stopping recording.");

    _vadSilenceTimer?.cancel();
    
    await _voiceProcessor?.stop();

    if (_audioStreamController != null && !_audioStreamController!.isClosed) {
      await _audioStreamController!.close();
      _log.info("Audio stream closed.");
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isVoiceDetected = false;
        _isBlushing = true; 
      });
    }
  }

  Future<void> _playAudioResponse(List<int> pcmBytes) async {
    _log.info('Preparing to play ${pcmBytes.length} bytes of PCM audio.');
    
    _sessionExpiryTimer?.cancel();
    
    if (_isListenerAttached) {
        _voiceProcessor?.removeFrameListener(_onAudioFrame);
        _isListenerAttached = false;
    }
    
    await _voiceProcessor?.stop();
    
    try {
      const sampleRate = 24000;
      const numChannels = 1;
      const bitsPerSample = 16;

      final header = _generateWavHeader(pcmBytes.length, numChannels, sampleRate, bitsPerSample);
      final wavBytes = header + pcmBytes;

      await _audioPlayer.setAudioSource(BytesAudioSource(wavBytes));
      
      // Set flags BEFORE playing
      if (mounted) {
        setState(() {
          _isAudioPlaying = true;
          _isTalking = true;
          _postPlaybackCooldown = false;
        });
      }
      
      _talkingMouthTimer?.cancel();
      _talkingMouthTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted && _isTalking) {
          setState(() => _mouthOpen = !_mouthOpen);
        }
      });

      await _audioPlayer.play();
      // We rely on the listener to handle the end.

    } catch (e) {
      _log.severe('Error playing audio response: $e');
      if (mounted) {
          setState(() {
            _isAudioPlaying = false;
            _isTalking = false;
          });
      }
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
    _roomStateNotifier?.removeListener(_onZegoRoomStateChanged);
    _callCheckTimer?.cancel();
    _postPlaybackMuteTimer?.cancel();
    _grpcClient.shutdown();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _wakeWordService.dispose();
    _cobraVADService.dispose();
    _voiceProcessor?.removeFrameListener(_onAudioFrame);
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
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.yellow.shade300,
              shape: BoxShape.rectangle,
            ),
          ),
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
          Positioned(
            top: size.height * 0.60,
            left: (size.width / 2) - 45,
            child: _buildMouth(),
          ),
          Positioned(
            top: size.height * 0.45,
            left: 0,
            right: 0,
            child: Column(
              children: [],
            ),
          ),
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
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Start call',
              iconSize: 28,
              icon: const Icon(Icons.video_call, color: Colors.black),
              onPressed: () async {
                _voiceProcessor?.removeFrameListener(_onAudioFrame);
                await _voiceProcessor?.stop();
                await _wakeWordService.stop();

                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JoinScreen()),
                );
                
                if (mounted && !_isListening && !_isSessionActive) {
                   _restartServices();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
