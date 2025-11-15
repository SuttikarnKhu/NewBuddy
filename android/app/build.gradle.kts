plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.newbuddy"

    // Required by plugins (like native_device_orientation)
    compileSdk = 36

    // Required for Zego / CallKit plugins
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.newbuddy"

        // Flutter provides these automatically
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        // Required for AGP 8.x + Kotlin DSL (missing in your file)
        compileSdk = 36

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    java {
        toolchain {
            languageVersion.set(JavaLanguageVersion.of(17))
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
