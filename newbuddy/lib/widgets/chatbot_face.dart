import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/contact_screen.dart';

class ChatBotFace extends StatefulWidget {
  const ChatBotFace({super.key});

  @override
  State<ChatBotFace> createState() => _ChatBotFaceState();
}

class _ChatBotFaceState extends State<ChatBotFace> with TickerProviderStateMixin {
  bool _isTalking = false;
  bool _eyesClosed = false;
  bool _mouthOpen = false;

  // Microphone / recording state (simple stub: no external recorder)
  bool _isRecording = false;

  Timer? _blinkTimer;
  Timer? _talkingMouthTimer;

  @override
  void initState() {
    super.initState();
    _startBlinking();
  }

  void _startBlinking() {
    _blinkTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      setState(() => _eyesClosed = true);
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) setState(() => _eyesClosed = false);
    });
  }

  // No text input/send behavior (removed as requested)

  Future<void> _handleMicPressed() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      if (!mounted) return;

      // Simple toggle behavior: show snackbars instead of actual recording
      if (!_isRecording) {
        setState(() => _isRecording = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording started (stub)')),
          );
        }
      } else {
        setState(() => _isRecording = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Recording stopped (stub)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Microphone error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _talkingMouthTimer?.cancel();
    // Nothing to dispose for the recorder stub
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
          // Microphone button only
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Microphone',
                  iconSize: 36,
                  icon: Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    color: _isRecording ? Colors.red : null,
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
                  MaterialPageRoute(builder: (_) => const ContactScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
