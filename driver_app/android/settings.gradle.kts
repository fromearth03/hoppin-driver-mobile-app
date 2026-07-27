pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // FCM (Phase 2). Applied in `app/build.gradle.kts` ONLY when a real
    // `google-services.json` is present — see the guard there. We do not commit
    // a fabricated one: a made-up Firebase project id, api key and app id in the
    // repo is a fabricated credential record, and it would make the build LOOK
    // push-capable while every token request silently failed.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
