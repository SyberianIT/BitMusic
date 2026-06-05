pluginManagement {
    val flutterSdkPath: String = run {
        val flutterSdk = file("local.properties").readLines()
            .firstOrNull { it.startsWith("flutter.sdk=") }
            ?.substringAfter("=")
            ?.trim()
        requireNotNull(flutterSdk) { "flutter.sdk not set in local.properties" }
        flutterSdk
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
    id("com.android.application") version "8.3.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.23" apply false
}

include(":app")
