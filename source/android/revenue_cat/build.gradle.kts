plugins {
    id("com.android.library") version "8.13.2"
    id("org.jetbrains.kotlin.android") version "2.3.0"
}

android {
    namespace = "com.godotx.revenuecat"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        }
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.5.2.stable")

    // RevenueCat
    implementation("com.revenuecat.purchases:purchases:10.1.2")
    implementation("com.revenuecat.purchases:purchases-ui:10.1.2")
    implementation("androidx.appcompat:appcompat:1.7.1")
}

