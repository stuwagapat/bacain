import java.util.Properties

plugins {
    id("com.android.application")
    // Dipasang eksplisit karena proyek ini memakai AGP 8, yang belum punya
    // dukungan Kotlin bawaan.
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci penandatanganan dibaca dari android/key.properties kalau ada.
// Berkas itu TIDAK ikut masuk git — isinya rahasia. Kalau tidak ada, build
// jatuh ke kunci debug: tetap bisa dipasang, tapi tanda tangannya dibuat baru
// tiap kali dibangun di mesin lain, jadi penguji harus menghapus app dulu
// sebelum memasang versi berikutnya — dan progres mereka ikut hilang.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()

android {
    namespace = "com.bacain.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Dituntut oleh flutter_local_notifications: paket itu memakai API
        // java.time, yang baru ada di Android 8+. Desugaring menambalnya
        // untuk versi yang lebih lama. Tanpa ini build berhenti di
        // checkReleaseAarMetadata dengan pesan yang menyebut nama paketnya.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.bacain.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
