import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── FCM CONFIG (Phase 2) ──────────────────────────────────────────────────────
// On Android — unlike web — the Firebase config is a FILE, not a set of
// dart-defines: `android/app/google-services.json`, from the Firebase console.
// The plugin below reads it and generates the resources `firebase_core`
// initialises from.
//
// 🔴 IT IS APPLIED ONLY IF THE FILE IS REALLY THERE, and the file is GITIGNORED.
// We do NOT commit a placeholder `google-services.json`. A fabricated project
// id, api key and app id sitting in the repo is a fabricated credential record:
// the build would succeed, `firebase_core` would "initialise", and every token
// request would fail against a Firebase project that does not exist — a green
// build that lies about being push-capable. Absent the file, the app boots on
// `NoopDriverFcmGateway`, which reports the gate honestly (see
// `features/notifications/driver_fcm_gateway.dart`).
//
// `apps/driver/android/app/google-services.json.example` documents the shape.
val googleServicesJson = file("google-services.json")
if (googleServicesJson.exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// ── RELEASE SIGNING ───────────────────────────────────────────────────────────
// Read from `android/key.properties`, which is GITIGNORED and never committed.
// If it is absent (every dev machine, CI without secrets) the release build
// falls back to the debug keystore so `flutter run --release` still works — but
// a debug-signed artifact CANNOT be uploaded to Play, which is the intended
// friction. The documented release command is in `apps/driver/README.md`.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.hoppin.hoppin_driver"
    compileSdk = flutter.compileSdkVersion

    // The NDK. Restored after an experiment that did not work, and the negative
    // result is worth recording so nobody repeats it.
    //
    // No plugin on this app's path needs the NDK — not geolocator, not
    // flutter_foreground_task, not firebase_core/messaging, not
    // permission_handler, not audioplayers. Not one declares an
    // `externalNativeBuild` or a CMakeLists, and the NDK compiles C/C++ that we
    // do not ship. So the ~2.5 GB it costs every developer looked like pure
    // waste, and I removed this line.
    //
    // **It made no difference.** AGP 9 supplies its own default `ndkVersion` and
    // installs it during project CONFIGURATION regardless of whether anything
    // compiles native code. Deleting the line does not opt out; it only removes
    // our control over WHICH version gets pulled. So it is back, pinned to
    // Flutter's, which is at least the version Flutter itself tests against.
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hoppin.hoppin_driver"

        // 🔴 THE FLOOR THAT MATTERS IS **23**. `flutter_foreground_task` requires
        // API 23 (Marshmallow); `firebase_messaging` requires 21+. Below 23 the
        // foreground service — the whole of this phase — does not exist.
        //
        // `flutter.minSdkVersion` is **24** today, so the requirement is met, and
        // this is left as the Flutter default DELIBERATELY: the Flutter gradle
        // tooling REWRITES a hardcoded literal back to `flutter.minSdkVersion` on
        // every `flutter build`, so pinning `23` here does not stay pinned — it
        // silently reverts, and a "pin" that reverts is worse than no pin because
        // it is believed.
        //
        // What actually guards the floor is `android_manifest_test.dart`, which
        // asserts the EFFECTIVE minSdk is >= 23. If Flutter ever drops its default
        // below that, the suite goes RED and names the plugin that broke.
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                // No keystore on this machine. Debug-signed so `--release` runs
                // locally; Play will refuse the upload, which is correct — an
                // artifact nobody can ship must not LOOK shippable.
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
