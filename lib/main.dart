import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/app_config.dart';
import 'services/firebase_service.dart';
import 'screens/id_input_screen.dart';
import 'screens/home_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  /// Set navigator key for call invitation service
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);
  
  /// Initialize Zego and set up system calling UI with signaling plugin
  await ZegoUIKit().initLog().then((value) async {
    ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI(
      [ZegoUIKitSignalingPlugin()],
    );
    
    // Check if user is already logged in
    final prefs = await SharedPreferences.getInstance();
    final savedUserID = prefs.getString('userID');
    final savedUserName = prefs.getString('userName');
    
    if (savedUserID != null && savedUserName != null) {
      // Reload user data from Firestore to restore full user info
      await FirebaseService.getUserById(savedUserID);
      
      // Auto-initialize Zego for saved user
      await ZegoUIKitPrebuiltCallInvitationService().init(
        appID: AppConfig.appID,
        appSign: AppConfig.appSign,
        userID: savedUserID,
        userName: savedUserName,
        plugins: [ZegoUIKitSignalingPlugin()],
        notificationConfig: ZegoCallInvitationNotificationConfig(
          androidNotificationConfig: ZegoCallAndroidNotificationConfig(
            showFullScreen: true,
            channelID: "ZegoUIKit",
            channelName: "Call Notifications",
            sound: "call_ringtone",
            vibrate: true,
          ),
        ),
        requireConfig: (ZegoCallInvitationData data) {
          var config = (data.invitees.length > 1)
              ? ZegoCallType.videoCall == data.type
                  ? ZegoUIKitPrebuiltCallConfig.groupVideoCall()
                  : ZegoUIKitPrebuiltCallConfig.groupVoiceCall()
              : ZegoCallType.videoCall == data.type
                  ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
                  : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
          return config;
        },
      );
    }
    
    runApp(MainApp(isLoggedIn: savedUserID != null));
  });
}

class MainApp extends StatelessWidget {
  final bool isLoggedIn;
  
  const MainApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NewBuddy',
      theme: ThemeData(primarySwatch: Colors.blue),
      navigatorKey: navigatorKey,
      home: isLoggedIn ? const HomeScreen() : const IdInputScreen(),
    );
  }
}
