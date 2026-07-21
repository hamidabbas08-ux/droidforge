plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val droidForgeKeystorePath =
    System.getenv("DROIDFORGE_KEYSTORE_PATH")

val droidForgeStorePassword =
    System.getenv("DROIDFORGE_STORE_PASSWORD")

val droidForgeKeyPassword =
    System.getenv("DROIDFORGE_KEY_PASSWORD")

val droidForgeKeyAlias =
    System.getenv("DROIDFORGE_KEY_ALIAS")

val hasPermanentSigning =
    !droidForgeKeystorePath.isNullOrBlank() &&
        !droidForgeStorePassword.isNullOrBlank() &&
        !droidForgeKeyPassword.isNullOrBlank() &&
        !droidForgeKeyAlias.isNullOrBlank()

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
        if (hasPermanentSigning) {
            create("droidforgePermanent") {
                storeFile = rootProject.file(droidForgeKeystorePath!!)
                storePassword = droidForgeStorePassword
                keyAlias = droidForgeKeyAlias
                keyPassword = droidForgeKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            if (hasPermanentSigning) {
                signingConfig =
                    signingConfigs.getByName("droidforgePermanent")
            }
        }

        release {
            if (hasPermanentSigning) {
                signingConfig =
                    signingConfigs.getByName("droidforgePermanent")
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
