plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.newbuddy"
    // Use highest compileSdk required by plugins (native_device_orientation required 36)
    compileSdk = 36
    // Pin the NDK version required by several plugins
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.newbuddy"
    // Some plugins require minSdk >= 22; set to 22 for compatibility.
    minSdk = 22
    // Set target and compile SDKs to highest plugin requirement (36)
    targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Prevent obfuscation of SDK public class names used by ZEGOCLOUD
            // (add proguard rules file)
            proguardFiles.add(file("proguard-rules.pro"))
        }
    }
}

flutter {
    source = "../.."
}
