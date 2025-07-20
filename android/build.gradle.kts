// android/build.gradle.kts (Project Level - Corrected Again)

buildscript {
    repositories {
        google()
        mavenCentral() // Yahan bhi mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2") // Ya jo bhi latest stable version ho
    }
}

allprojects {
    repositories {
        google()
        mavenCentral() // <--- YEH WALI LINE SAHI KARNI HAI
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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}