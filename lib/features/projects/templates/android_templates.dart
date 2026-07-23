class AndroidTemplates {
  static String manifest({
    required String packageName,
    required String appName,
  }) {
    return '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="$packageName">

    <application
        android:allowBackup="true"
        android:label="$appName"
        android:supportsRtl="true"
        android:theme="@style/Theme.App">

        <activity
            android:name=".MainActivity"
            android:exported="true">

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>

                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

        </activity>

    </application>

</manifest>
''';
  }

  static String mainActivity({required String packageName}) {
    return '''
package $packageName

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
    }

}
''';
  }

  static String activityMain() {
    return '''
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:gravity="center"
    android:orientation="vertical">

    <TextView
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:text="Hello DroidForge!"
        android:textSize="24sp"/>

</LinearLayout>
''';
  }

  static String rootBuildGradle() {
    return '''
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}
''';
  }

  static String appBuildGradle({required String packageName}) {
    return '''
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "$packageName"
    compileSdk = 35
    buildToolsVersion = "35.0.0"

    defaultConfig {
        applicationId = "$packageName"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("com.google.android.material:material:1.12.0")
}
''';
  }

  static String settingsGradle({required String appName}) {
    return '''
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)

    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "$appName"
include(":app")
''';
  }

  static String gradleProperties() {
    return '''
org.gradle.daemon=false
org.gradle.native=false
org.gradle.internal.native=false
org.gradle.vfs.watch=false
org.gradle.workers.max=1
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
''';
  }

  static String libsVersionsToml() {
    return '''
[versions]
agp = "8.7.3"
kotlin = "2.0.21"
coreKtx = "1.13.1"
appcompat = "1.7.0"
material = "1.12.0"

[libraries]
androidx-core-ktx = { module = "androidx.core:core-ktx", version.ref = "coreKtx" }
androidx-appcompat = { module = "androidx.appcompat:appcompat", version.ref = "appcompat" }
material = { module = "com.google.android.material:material", version.ref = "material" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
''';
  }

  static String gradleWrapperProperties() {
    return '''
distributionBase=GRADLE_USER_HOME
distributionPath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.10-bin.zip
''';
  }

  static String colorsXml() {
    return '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="black">#FF000000</color>
    <color name="white">#FFFFFFFF</color>
    <color name="purple_500">#6200EE</color>
    <color name="purple_700">#3700B3</color>
    <color name="teal_200">#03DAC5</color>
</resources>
''';
  }

  static String stringsXml({required String appName}) {
    return '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">$appName</string>
</resources>
''';
  }

  static String themesXml() {
    return '''
<?xml version="1.0" encoding="utf-8"?>
<resources xmlns:tools="http://schemas.android.com/tools">

    <style name="Theme.App"
        parent="Theme.Material3.DayNight.NoActionBar">

        <item name="colorPrimary">@color/purple_500</item>
        <item name="colorPrimaryVariant">@color/purple_700</item>
        <item name="colorSecondary">@color/teal_200</item>

    </style>

</resources>
''';
  }

  static String gitignore() {
    return '''
*.iml
.gradle/
local.properties
.idea/
.DS_Store
/build/
/captures/
.externalNativeBuild/
.cxx/
''';
  }

  static String localProperties() {
    return '''
## This file is generated automatically.
## Do not commit this file to version control.

sdk.dir=
''';
  }

  static String proguardRules() {
    return '''
# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# Keep line numbers for stack traces.
-keepattributes SourceFile,LineNumberTable
''';
  }
}
