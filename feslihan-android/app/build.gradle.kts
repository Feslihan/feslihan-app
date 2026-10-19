plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.kotlin.kapt)
    alias(libs.plugins.hilt)
}

android {
    namespace = "com.feslihan.app"
    // 36 — required by the Clerk/coil3/browser/navigation3 AARs. The emulator stays
    // API 34; compileSdk and the device API level are independent.
    compileSdk = 36

    defaultConfig {
        applicationId = "com.feslihan.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // UI language is Turkish — keep tr as the only locale we ship strings for.
        androidResources.localeFilters += "tr"

        // Backend base URL (mirrors APIService.baseURL on iOS). Overridable per build type.
        buildConfigField("String", "API_BASE_URL", "\"https://api.feslihan.com.tr\"")

        // Clerk publishable key — client-safe (the iOS app hardcodes the same test
        // key in FeslihanApp.swift). Override with -PCLERK_PUBLISHABLE_KEY=... for prod.
        val clerkKey = (project.findProperty("CLERK_PUBLISHABLE_KEY") as String?)
            ?: "pk_test_d2FudGVkLWxpZ2VyLTQ3LmNsZXJrLmFjY291bnRzLmRldiQ"
        buildConfigField("String", "CLERK_PUBLISHABLE_KEY", "\"$clerkKey\"")
    }

    buildTypes {
        debug {
            buildConfigField("String", "API_BASE_URL", "\"https://api.feslihan.com.tr\"")
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

// Hilt generates stubs that reference not-yet-generated types; correctErrorTypes lets
// KAPT resolve them instead of failing. Required for the Hilt + KAPT path.
kapt {
    correctErrorTypes = true
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.graphics)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    implementation(libs.androidx.material.icons.extended)
    debugImplementation(libs.androidx.ui.tooling)

    implementation(libs.androidx.navigation.compose)
    implementation(libs.hilt.navigation.compose)

    implementation(libs.hilt.android)
    kapt(libs.hilt.compiler)
    // Hilt 2.57.2 bundles a kotlin-metadata-jvm that only reads metadata <= 2.2.0, but our
    // classes compile with Kotlin 2.4.21 (metadata 2.4.0). Force the newer reader onto the
    // kapt classpath so Hilt can parse them. (Hilt 2.59+ ships this but requires AGP 9.)
    kapt("org.jetbrains.kotlin:kotlin-metadata-jvm:2.4.21")

    implementation(libs.retrofit)
    implementation(libs.retrofit.kotlinx.serialization)
    implementation(libs.okhttp)
    implementation(libs.okhttp.logging)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)

    implementation(libs.room.runtime)
    implementation(libs.room.ktx)
    kapt(libs.room.compiler)

    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.work.runtime.ktx)
    implementation(libs.coil.compose)

    implementation(libs.revenuecat)

    implementation(libs.clerk.android.api)
    implementation(libs.clerk.android.ui)
}
