import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci penandatanganan dibaca dari android/key.properties, yang tidak pernah
// ikut masuk repo (sudah ada di android/.gitignore).
//
// Sebelum ini build release memakai kunci DEBUG bawaan template. Di mesin
// sendiri itu tidak kelihatan karena ~/.android/debug.keystore-nya tetap.
// Runner CI tidak punya berkas itu, jadi Gradle membuatnya baru tiap build —
// setiap rilis ditandatangani kunci acak yang berbeda, dan Android menolak
// memperbarui aplikasi yang tanda tangannya tidak sama. Itu yang muncul
// sebagai "paket ini bentrok dengan paket yang sudah ada".
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.andndredev.luminaraphotobooth"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.andndredev.luminaraphotobooth"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystoreProperties.isNotEmpty()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Tanpa key.properties — kontributor lain, atau `flutter run
            // --release` di mesin mana pun — tetap jatuh ke kunci debug supaya
            // build-nya tidak gagal. APK-nya cuma tidak bisa dipakai
            // memperbarui pemasangan yang sudah ada, dan itu memang benar.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
