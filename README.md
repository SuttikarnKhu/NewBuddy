# ElderBuddyApp

This document outlines the steps to set up and run the ElderBuddyApp on a macOS environment, and how to configure microphone permissions.

## 1. Prerequisites

Before running the application, ensure you have Flutter installed on your system. You can check your Flutter installation with the following command:

```bash
flutter --version
```

## 2. Running the Application

If you are running the project for the first time on a new platform (like desktop), you may need to add support for it.

**2.1. Add Desktop Support**

To enable support for running the app on macOS, run the following command in the project's root directory:

```bash
flutter create .
```

**2.2. Run the App on macOS**

Once desktop support is enabled, you can run the application on macOS using:

```bash
flutter run -d macos
```

## 3. Enabling Microphone Access

To ensure the application can access the microphone when running in an emulator or simulator, you need to add the appropriate permissions.

**3.1. Android**

The `RECORD_AUDIO` permission has been added to the `android/app/src/main/AndroidManifest.xml` file. This allows the app to record audio on Android devices.

**3.2. iOS**

The `NSMicrophoneUsageDescription` key has been added to the `ios/Runner/Info.plist` file. This provides a necessary description to the user when the app requests microphone access on iOS devices.