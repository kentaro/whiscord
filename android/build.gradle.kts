allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    
    // すべてのサブプロジェクトに共通のJava/Kotlin設定を追加
    plugins.withId("com.android.library") {
        // Androidライブラリプロジェクトに設定を適用
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.apply {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_1_8
                targetCompatibility = JavaVersion.VERSION_1_8
            }
        }
    }
    
    plugins.withId("org.jetbrains.kotlin.android") {
        // Kotlinプロジェクトに設定を適用
        extensions.findByType<org.jetbrains.kotlin.gradle.dsl.KotlinJvmOptions>()?.apply {
            jvmTarget = "1.8"
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
