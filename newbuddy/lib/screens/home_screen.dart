import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:newbuddy/services/firebase_service.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import '../widgets/chatbot_face.dart';
import '../constants/app_config.dart';
import 'sign_in_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _initializeCallInvitationService();
  }

  Future<void> _initializeCallInvitationService() async {
    /// Initialize call invitation service with logged-in user data
    final uid = firebaseService.value.currentAuthUser?.uid;
    if (uid != null) {
      await FirebaseService.loadCurrentUser(uid);
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: AppConfig.appID,
        appSign: AppConfig.appSign,
        userID: FirebaseService.currentUserModel.uid,
        userName: FirebaseService.currentUserModel.name,
        plugins: [ZegoUIKitSignalingPlugin()],
      );
    }
  }

  Future<void> _logout() async {
    try {
      // Uninitialize call service before logout
      ZegoUIKitPrebuiltCallInvitationService().uninit();
      
      // Clear user cache
      FirebaseService.clearCurrentUser();
      
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SignInPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      print(e.message);
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
              top: 16,
              left: 16,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
