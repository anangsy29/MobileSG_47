plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.smartgateapp"  // namespace wajib ada
    compileSdk = 34                           // Bisa sesuaikan dengan Flutter sdk, misal 34

    ndkVersion = "27.0.12077973"             // NDK yang diminta plugin Firebase dan local_notifications

    defaultConfig {
        applicationId = "com.smartgateapp"
        minSdk = 21                          // Minimal SDK, bisa disesuaikan, minimal 21 agar firebase lancar
        targetSdk = 34                      // Sama seperti compileSdk
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        release {
            // Gunakan debug signing sementara, ganti sesuai keperluan produksi
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Firebase BoM untuk mengelola versi firebase library
    implementation(platform("com.google.firebase:firebase-bom:33.14.0"))

    // Firebase Analytics (contoh, sesuaikan jika perlu)
    implementation("com.google.firebase:firebase-analytics")

    // Tambahkan dependencies lain yang kamu butuhkan
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}
