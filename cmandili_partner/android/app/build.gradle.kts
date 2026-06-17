plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.cmandili.partner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cmandili.partner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Ship only 64-bit ARM. Real Android phones since 2019 are arm64-v8a;
        // x86_64 is emulator-only and armeabi-v7a is legacy 32-bit. Dropping
        // both removes ~2/3 of the native-lib payload (Mapbox, Firebase,
        // flutter_sound, etc. each ship one .so per ABI), so the universal
        // APK from a plain `flutter build apk` shrinks from ~150 MB to ~50 MB.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }

        // Drop unused locale resources from bundled libraries (Firebase, Play
        // Services, Mapbox). We only ship en/ar/fr; everything else is dead
        // weight. resourceConfigurations is the AGP <8.5 spelling of
        // androidResources.localeFilters.
        resourceConfigurations += listOf("en", "ar", "fr")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // R8 minification is OFF: with Mapbox + Firebase + supabase_flutter
            // it requires hand-tuned -keep rules and crashed the Gradle daemon
            // on a 16 GB machine. The size win was already taken by
            // arm64-v8a-only `abiFilters` above (~2/3 APK reduction).
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Explicit Firebase Messaging dep so CmandiliMessagingService.kt can import
    // RemoteMessage and FirebaseMessagingService directly without relying on
    // transitive exposure from the Flutter plugin's AAR.
    implementation("com.google.firebase:firebase-messaging:23.4.1")
}
