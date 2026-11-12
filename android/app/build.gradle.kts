plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.dor.nowplaying"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.dor.nowplaying"
        minSdk = 26
        targetSdk = 34
        versionCode = 6
        versionName = "1.4"
    }

    // A fixed debug key kept in the repo, so every cloud build can be installed
    // over the previous one without uninstalling first.
    signingConfigs {
        getByName("debug") {
            storeFile = rootProject.file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
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
    // Official Garmin Connect IQ Mobile SDK for Android.
    implementation("com.garmin.connectiq:ciq-companion-app-sdk:2.3.0")
    testImplementation("junit:junit:4.13.2")
}
