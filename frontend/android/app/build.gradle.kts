plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "in.unlabel.unlabel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Keep this identifier stable across all demo versions.
        applicationId = "in.unlabel.unlabel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val demoKeystore = providers.environmentVariable("UNLABEL_DEMO_KEYSTORE").orNull
    if (providers.environmentVariable("GITHUB_ACTIONS").orNull == "true") {
        require(!demoKeystore.isNullOrBlank()) { "CI requires the registered demo keystore." }
    }
    if (!demoKeystore.isNullOrBlank()) {
        signingConfigs.create("registeredDemo") {
            storeFile = file(demoKeystore)
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        release {
            // CI restores a private stable demo key registered with Firebase.
            // Local builds use the developer's registered debug certificate.
            signingConfig = signingConfigs.getByName(
                if (demoKeystore.isNullOrBlank()) "debug" else "registeredDemo"
            )
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

dependencies {
    // Bundled models: label OCR works offline without Play Services downloads.
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
}
