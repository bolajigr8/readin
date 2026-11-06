import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ────────────────────────────────────────────────────────
// android/key.properties (git-ignored; copy key.properties.example) points at the
// ReadIn release keystore. A release build WITHOUT it fails on purpose: an APK signed
// with the debug key cannot be updated by the real one (users would have to uninstall
// and lose their books). Local test only:
//   flutter build apk --release -P ALLOW_DEBUG_SIGNING=true
//   (or set the environment variable READIN_ALLOW_DEBUG_SIGNING=true)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}
val signingKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningKeys = signingKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val releaseStoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }
val releaseSigningProblem: String? = when {
    !keystorePropertiesFile.exists() ->
        "android/key.properties is missing (copy android/key.properties.example and fill it in)."
    missingSigningKeys.isNotEmpty() ->
        "android/key.properties has no value for: ${missingSigningKeys.joinToString()}."
    releaseStoreFile == null || !releaseStoreFile.exists() ->
        "the keystore named in android/key.properties (storeFile) was not found."
    else -> null
}
// Optional UPLOAD key for the Google Play bundle (Play App Signing re-signs with the release key).
// key.properties: uploadStoreFile / uploadStorePassword / uploadKeyAlias / uploadKeyPassword.
// Not set → the Play bundle is signed with the release key (Google accepts that too).
val uploadKeys = listOf("uploadStoreFile", "uploadStorePassword", "uploadKeyAlias", "uploadKeyPassword")
val uploadStoreFile = keystoreProperties.getProperty("uploadStoreFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }
val hasUploadKey = uploadKeys.all { !keystoreProperties.getProperty(it).isNullOrBlank() } &&
    uploadStoreFile != null && uploadStoreFile.exists()
val allowDebugSigning =
    (findProperty("ALLOW_DEBUG_SIGNING")?.toString() == "true") ||
        (System.getenv("READIN_ALLOW_DEBUG_SIGNING") == "true")

android {
    namespace = "com.micbol.readin"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // NEVER change: same id for both flavors and for every future release.
        applicationId = "com.micbol.readin"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningProblem == null) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = releaseStoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
        create("upload") {
            if (hasUploadKey) {
                keyAlias = keystoreProperties.getProperty("uploadKeyAlias")
                keyPassword = keystoreProperties.getProperty("uploadKeyPassword")
                storeFile = uploadStoreFile
                storePassword = keystoreProperties.getProperty("uploadStorePassword")
            }
        }
    }

    // Two versions of ReadIn from one code base (DECISIONS #17). SAME applicationId on purpose:
    // people can move from the APK to the Play version without uninstalling (books stay).
    //   direct = APK from our website (Paystack, whole-phone scan, MANAGE_EXTERNAL_STORAGE in src/direct)
    //   play   = Google Play (no Paystack, no all-files permission) — built as an AAB
    // Dart reads the flavor via `appFlavor` (lib/core/distribution.dart).
    flavorDimensions += "distribution"
    productFlavors {
        create("direct") {
            dimension = "distribution"
            // Release builds: the ReadIn release key (debug key only with the explicit opt-out).
            signingConfig = if (releaseSigningProblem == null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        create("play") {
            dimension = "distribution"
            // Upload key if configured, else the release key (debug only with the explicit opt-out).
            signingConfig = when {
                hasUploadKey -> signingConfigs.getByName("upload")
                releaseSigningProblem == null -> signingConfigs.getByName("release")
                else -> signingConfigs.getByName("debug")
            }
        }
    }

    buildTypes {
        release {
            // No signingConfig here on purpose: a build type's signingConfig overrides the
            // flavor's. (Debug builds keep the debug key — the debug build type sets it.)
            signingConfig = null
        }
    }
}

// Stop a release package/bundle that would be signed with the debug key.
// (Configuration of debug builds, `flutter run`, tests and analyze is unaffected.)
if (releaseSigningProblem != null) {
    val problem = releaseSigningProblem
    if (allowDebugSigning) {
        logger.warn(
            "ReadIn: ALLOW_DEBUG_SIGNING=true → this release build is signed with the DEBUG key. " +
                "Never give it to users. ($problem)",
        )
    } else {
        val releasePackaging = Regex("^(package(Direct|Play)Release|sign(Direct|Play)ReleaseBundle)$")
        tasks.matching { releasePackaging.matches(it.name) }
            .configureEach {
                doFirst {
                    throw GradleException(
                        "ReadIn release signing is not set up: $problem\n" +
                            "Release APKs must be signed with the ReadIn release key " +
                            "(see project/docs/PLAY_AND_DISTRIBUTION.md §2).\n" +
                            "For a local test build only, add: -P ALLOW_DEBUG_SIGNING=true",
                    )
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
    // FileProvider / NotificationCompat used by MainActivity + ReadAloudService
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
