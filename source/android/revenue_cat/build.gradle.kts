plugins {
    id("com.android.library") version "8.2.2"
    id("org.jetbrains.kotlin.android") version "2.1.0"
}

android {
    namespace = "com.godotx.revenuecat"
    compileSdk = 34

    defaultConfig {
        minSdk = 21
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

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.2.2.stable")
    
    // RevenueCat
    implementation("com.revenuecat.purchases:purchases:9.14.0")
    implementation("com.revenuecat.purchases:purchases-ui:9.14.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
}

