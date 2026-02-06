plugins {
    id("com.android.application")
}

val compileSdkApi = (System.getenv("ANDROID_COMPILE_SDK")
    ?: System.getenv("ANDROID_MAX_API")
    ?: "36").toInt()
val targetSdkApi = (System.getenv("ANDROID_TARGET_SDK")
    ?: System.getenv("ANDROID_MAX_API")
    ?: "36").toInt()
val buildToolsVersionValue = System.getenv("ANDROID_BUILD_TOOLS_VERSION") ?: "36.1.0"

android {
    namespace = "com.example.devbox"
    compileSdk = compileSdkApi
    buildToolsVersion = buildToolsVersionValue

    defaultConfig {
        applicationId = "com.example.devbox"
        minSdk = 21
        targetSdk = targetSdkApi
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
}
