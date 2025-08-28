buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.10.0")
        classpath("com.google.gms:google-services:4.4.2")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.20")    
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory.set(rootProject.layout.buildDirectory.dir("../../build").get().asFile)

subprojects {
    layout.buildDirectory.set(rootProject.layout.buildDirectory.dir(project.name).get().asFile)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}