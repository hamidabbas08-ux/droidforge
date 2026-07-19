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
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
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
        android:text="Hello Android!"
        android:textSize="24sp"/>

</LinearLayout>
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
    compileSdk = 36

    defaultConfig {
        applicationId = "$packageName"
        minSdk = 24
        targetSdk = 36
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
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("com.google.android.material:material:1.12.0")
}
''';
  }

  static String rootBuildGradle() {
    return '''
plugins {
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.2.10" apply false
}
''';
  }

  static String settingsGradle({required String appName}) {
    return '''
rootProject.name = "$appName"
include(":app")
''';
  }

  static String gradleProperties() {
    return '''
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
android.nonTransitiveRClass=true
kotlin.code.style=official
''';
  }

  static String stringsXml({required String appName}) {
    return '''
<resources>
    <string name="app_name">$appName</string>
</resources>
''';
  }

  static String colorsXml() {
    return '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="purple_500">#6200EE</color>
    <color name="purple_700">#3700B3</color>
    <color name="teal_200">#03DAC5</color>
    <color name="black">#000000</color>
    <color name="white">#FFFFFF</color>
</resources>
''';
  }

  static String themesXml() {
    return '''
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="Theme.App" parent="Theme.Material3.DayNight.NoActionBar"/>
</resources>
''';
  }

  static String libsVersionsToml() {
    return '''
[versions]
agp = "8.13.0"
kotlin = "2.2.10"
coreKtx = "1.17.0"
appcompat = "1.7.1"
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
distributionUrl=https\\://services.gradle.org/distributions/gradle-8.13-bin.zip
zipStoreBase=GRADLE_USER_HOME
zipStorePath=wrapper/dists
''';
  }

  static String proguardRules() {
    return '''
# Project specific ProGuard rules.

# Keep line numbers for better stack traces.
-keepattributes SourceFile,LineNumberTable

# Preserve annotations.
-keepattributes *Annotation*

# Uncomment if you enable code shrinking.
#-dontobfuscate
#-dontoptimize
''';
  }

  static String gitignore() {
    return '''
.gradle/
build/
captures/
local.properties

*.iml
*.log

.idea/
.DS_Store

/app/release/
/app/debug/

.kotlin/
.cxx/
.externalNativeBuild/
''';
  }
}
