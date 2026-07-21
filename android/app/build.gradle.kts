import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use {
        keystoreProperties.load(it)
    }
}

android {
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    namespace = "com.hamid.droidforge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        ndk {
            abiFilters += listOf("arm64-v8a")
        }

        applicationId = "com.hamid.droidforge"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("droidforgePermanent") {
                val configuredStoreFile =
                    keystoreProperties.getProperty("storeFile")
                        ?: error("storeFile is missing from key.properties")

                storeFile = file(configuredStoreFile)
                storePassword =
                    keystoreProperties.getProperty("storePassword")
                        ?: error("storePassword is missing from key.properties")
                keyAlias =
                    keystoreProperties.getProperty("keyAlias")
                        ?: error("keyAlias is missing from key.properties")
                keyPassword =
                    keystoreProperties.getProperty("keyPassword")
                        ?: error("keyPassword is missing from key.properties")
            }
        }
    }

    buildTypes {
        debug {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("droidforgePermanent")
            }
        }

        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("droidforgePermanent")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
