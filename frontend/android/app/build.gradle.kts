plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

@Suppress("DEPRECATION")
android {
    namespace = "org.fvlabs.handover"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "org.fvlabs.handover"
        // Play Target API Level policy (Aug 2025+): target API 35. Pin to 35 for Play compliance.
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Play App Signing: prefer env vars / CI secrets; fallback to debug keystore only for local `flutter run --release`
            val keystorePath = System.getenv("KEYSTORE_PATH") ?: System.getenv("ANDROID_KEYSTORE_PATH")
            val keystorePassword = System.getenv("KEYSTORE_PASSWORD") ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
            val keyAlias = System.getenv("KEY_ALIAS")
            val keyPassword = System.getenv("KEY_PASSWORD")

            if (keystorePath != null && keystorePassword != null && keyAlias != null && keyPassword != null) {
                storeFile = file(keystorePath)
                storePassword = keystorePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
                println("Using release keystore from env: $keystorePath")
            } else {
                // Local development fallback — DO NOT use for Play upload; configure KEYSTORE_* env vars in CI
                // This avoids hard-failing local builds but prints a clear warning
                println("WARNING: Release signing env vars not set (KEYSTORE_PATH/KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD) — falling back to debug keystore for local testing only. For Play upload, set env vars or use Play App Signing.")
                storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
                // debug keystore creds are standard; only used when env vars absent
                storePassword = "android"
                this.keyAlias = "androiddebugkey"
                this.keyPassword = "android"
                // If debug keystore missing (CI), fall back to Gradle debug signingConfig
                if (storeFile?.exists() == false) {
                    println("Debug keystore not found at ${storeFile?.path} — using Gradle debug signingConfig as last resort")
                }
            }
        }
    }

    buildTypes {
        release {
            // Use release signingConfig — requires KEYSTORE_* env vars in CI / Play App Signing
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            // Explicit debug type keeps cleartext network_security_config separate
            isDebuggable = true
        }
    }

    // Play 16KB: ensure uncompressed native libs are aligned correctly (AGP 8+)
    packaging {
        jniLibs {
            useLegacyPackaging = false
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
