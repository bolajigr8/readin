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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
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
    }

    buildTypes {
        release {
            // Release keystore when configured. The debug key is used only when the
            // build explicitly allows it; otherwise the check below stops the build.
            signingConfig = if (releaseSigningProblem == null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
        tasks.matching { it.name == "packageRelease" || it.name == "signReleaseBundle" }
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
