import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../widgets/chatbot_face.dart';
import '../services/firebase_service.dart';
import 'id_input_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _signOut() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Clear saved login
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userID');
    await prefs.remove('userName');

    // Uninitialize Zego
    await ZegoUIKitPrebuiltCallInvitationService().uninit();

    // Clear Firebase service
    FirebaseService.clearCurrentUser();

    // Navigate to login screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const IdInputScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const ChatBotFace(),
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton(
                onPressed: _signOut,
                tooltip: 'Sign Out',
                backgroundColor: Colors.red,
                child: const Icon(Icons.logout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
