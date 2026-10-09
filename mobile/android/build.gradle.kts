allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (file_picker, flutter_tts, ...) still compile against an older
// Android API than their dependency `flutter_plugin_android_lifecycle` allows
// ("requires ... compile against version 36 or later"). Raise compileSdk of
// every plugin module to 36. Written with reflection so it does not depend on
// the Android Gradle Plugin's (frequently changing) extension classes.
// NOTE: this block must stay BEFORE the `evaluationDependsOn(":app")` block.
subprojects {
    if (project.name != "app") {
        afterEvaluate {
            val android = extensions.findByName("android")
            if (android != null) {
                try {
                    val setter = android.javaClass.methods.firstOrNull {
                        it.name == "setCompileSdk" && it.parameterCount == 1
                    }
                    if (setter != null) {
                        setter.invoke(android, 36)
                    } else {
                        println("compileSdk override: no setCompileSdk on ${project.name}")
                    }
                } catch (e: Exception) {
                    println("compileSdk override failed for ${project.name}: $e")
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
