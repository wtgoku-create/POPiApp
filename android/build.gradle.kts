import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://artifact.bytedance.com/repository/AwemeOpenSDK")
            content { includeGroup("com.bytedance.ies.ugc.aweme") }
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
    // Fluwx assumes AGP 9 enables Kotlin, but Flutter disables built-in Kotlin.
    if (name == "fluwx") {
        pluginManager.withPlugin("com.android.library") {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
    if (name == "tobias") {
        // Tobias 5.3.4 bundles global ProGuard flags rejected by AGP 9.
        afterEvaluate {
            extensions.getByType<LibraryExtension>().defaultConfig.apply {
                consumerProguardFiles.clear()
                consumerProguardFiles(rootProject.file("alipay-consumer-rules.pro"))
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
