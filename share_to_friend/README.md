# NewBuddy Call Invitation Setup - Essential Files Only

## 📦 Files Included:
1. `app_config.example.dart` - Zego credentials template
2. `user.dart` - User data model
3. `firebase_service.dart` - Firebase authentication & Firestore
4. `main.dart` - Zego initialization reference
5. `pubspec.yaml` - Dependencies list

---

## 🚀 Quick Setup Guide for iOS

### Step 1: Add Firebase to Your Project
```bash
# In your Flutter project root
flutterfire configure
```
- Select project: **buddyfinal2437** (use YOUR existing Firebase project!)
- Select platforms: **iOS** (and others if needed)

**Important:** We'll use YOUR Firebase project so we share the same user database!

### Step 2: Copy Essential Files

**Create these folders in your project:**
```
your_project/
├── lib/
│   ├── constants/
│   ├── model/
│   └── services/
```

**Copy files to these locations:**
- `app_config.example.dart` → `lib/constants/app_config.dart` (rename it!)
- `user.dart` → `lib/model/user.dart`
- `firebase_service.dart` → `lib/services/firebase_service.dart`

### Step 3: Update app_config.dart
Open `lib/constants/app_config.dart` and replace with:
```dart
class AppConfig {
  static const int appID = 1763575890;
  static const String appSign = '913f6c6fbdaadb458e9d66d58bdc769c14ba6eb2116b3f0da7a72eea78fc09cb';
}
```

### Step 4: Add Dependencies
Copy these dependencies from `pubspec.yaml` to your project:
```yaml
dependencies:
  flutter:
    sdk: flutter
  zego_uikit: ^2.28.34
  zego_uikit_prebuilt_call: ^4.21.1
  zego_uikit_signaling_plugin: ^2.8.19
  permission_handler: ^12.0.1
  cupertino_icons: ^1.0.2
  firebase_core: ^4.2.1
  firebase_auth: ^6.1.2
  cloud_firestore: ^6.1.0
```

Then run:
```bash
flutter pub get
```

### Step 5: Setup Zego in main.dart
Add this code to your `main.dart` (see the included `main.dart` for full example):

```dart
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set navigator key for Zego
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);
  
  // Initialize Zego with system calling UI
  await ZegoUIKit().initLog().then((value) async {
    await ZegoUIKitPrebuiltCallInvitationService().useSystemCallingUI(
      [ZegoUIKitSignalingPlugin()],
    );
    runApp(const MyApp());
  });
}

// Register navigatorKey in MaterialApp
MaterialApp(
  navigatorKey: navigatorKey,
  // ... rest of your app
)
```

### Step 6: Initialize Call Service After Login
After user signs in, initialize the call service:
```dart
import 'package:newbuddy/services/firebase_service.dart';
import 'package:newbuddy/constants/app_config.dart';

Future<void> initializeCallService() async {
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
```

### Step 7: iOS Permissions
Add to `ios/Runner/Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Need camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>Need microphone access for calls</string>
```

### Step 8: Install CocoaPods
```bash
cd ios
pod install
cd ..
```

### Step 9: Add Call Buttons in Your UI
```dart
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';

// Voice call button
ZegoSendCallInvitationButton(
  isVideoCall: false,
  invitees: [
    ZegoUIKitUser(
      id: targetUserID,
      name: targetUserName,
    ),
  ],
)

// Video call button
ZegoSendCallInvitationButton(
  isVideoCall: true,
  invitees: [
    ZegoUIKitUser(
      id: targetUserID,
      name: targetUserName,
    ),
  ],
)
```

---

## ✅ Testing

1. **Android user (your friend):** Register with email (e.g., `android@test.com`)
2. **iOS user (you):** Register with different email (e.g., `ios@test.com`)
3. Both sign in to respective apps
4. You should see each other in your contact lists
5. Tap call button to initiate call!

---

## 🔑 Important Notes

- ✅ **Same Firebase project:** Both apps must use `buddy-a50df`
- ✅ **Same Zego credentials:** Both apps use appID `1763575890` and the same appSign
- ✅ **Shared user database:** You'll see each other because you share the same Firestore `users` collection
- ✅ **Cross-platform:** Android ↔️ iOS calls work seamlessly with Zego

---

## 🐛 Troubleshooting

**Can't see each other in contacts?**
- Verify both apps use the same Firebase project
- Check Firestore security rules allow read access

**Call invitation not working?**
- Verify both apps use the same Zego appID and appSign
- Check that you initialized ZegoUIKitPrebuiltCallInvitationService after login

**Permission issues?**
- Make sure iOS Info.plist has camera and microphone permissions
- Request permissions at runtime if needed

---

## 📞 Need Help?
Check the `main.dart` file included for full initialization example.

Good luck with your iOS app! 🎉
