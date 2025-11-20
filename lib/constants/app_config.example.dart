// Centralized app configuration for secrets and IDs.
// IMPORTANT: 
// 1. Copy this file to 'app_config.dart'
// 2. Replace `appID` and `appSign` with values from your ZEGOCLOUD console.
// 3. Get your credentials from: https://console.zegocloud.com/

class AppConfig {
  // ZEGOCLOUD App ID (integer)
  // Get from: https://console.zegocloud.com/project
  static const int appID = 0; // Replace with your App ID

  // ZEGOCLOUD App Sign (string)
  // Get from: https://console.zegocloud.com/project
  static const String appSign = 'YOUR_APP_SIGN_HERE'; // Replace with your App Sign
}
