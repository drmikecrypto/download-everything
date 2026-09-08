plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.drmikecrypto.download_everything"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.drmikecrypto.download_everything"
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            val storePath = System.getenv("ANDROID_KEYSTORE_PATH")
            if (!storePath.isNullOrBlank()) {
                storeFile = file(storePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Explicit: keep R8 minify off; rules stay wired if Flutter/AGP ever flips the default.
            isMinifyEnabled = false
            isShrinkResources = false
            // Prefer CI/local release keystore when ANDROID_KEYSTORE_PATH is set; else debug
            // so unsigned/dev APKs still build without secrets.
            val releaseSigning = signingConfigs.findByName("release")
            signingConfig = if (releaseSigning?.storeFile != null) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            isMinifyEnabled = false
        }
    }

    packaging {
        jniLibs {
            // Required so youtubedl-android Python/FFmpeg natives can dlopen on device.
            useLegacyPackaging = true
            // zip.so payloads are not real ELF; stripping them breaks the release build.
            keepDebugSymbols += listOf(
                "**/libpython.zip.so",
                "**/libffmpeg.zip.so",
            )
            pickFirsts += listOf(
                "**/libc++_shared.so",
                "lib/armeabi-v7a/libc++_shared.so",
                "lib/arm64-v8a/libc++_shared.so",
                "lib/x86/libc++_shared.so",
                "lib/x86_64/libc++_shared.so",
            )
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // NIO desugar so commons-compress ZipFile works on API 24–25 (StandardOpenOption).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs_nio:2.1.5")

    val youtubedlAndroid = "0.18.1"
    implementation("io.github.junkfood02.youtubedl-android:library:$youtubedlAndroid")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:$youtubedlAndroid")
}

fun overwriteProjectLibcxx(logger: org.gradle.api.logging.Logger) {
    val jniRoot = file("src/main/jniLibs")
    if (!jniRoot.isDirectory) return

    val searchRoots = listOf(
        layout.buildDirectory.get().asFile,
        rootProject.layout.buildDirectory.get().asFile,
        file("../../build"),
    ).filter { it.isDirectory }

    val outLibs = mutableListOf<File>()
    for (root in searchRoots) {
        root.walkTopDown()
            .maxDepth(12)
            .filter { it.isDirectory && it.name == "lib" && it.parentFile?.name == "out" }
            .forEach { outLibs += it }
    }

    for (abiDir in jniRoot.listFiles().orEmpty().filter { it.isDirectory }) {
        val so = File(abiDir, "libc++_shared.so")
        if (!so.isFile) continue
        for (outLib in outLibs.distinctBy { it.absolutePath }) {
            val destDir = File(outLib, abiDir.name)
            if (!destDir.isDirectory) continue
            val dest = File(destDir, "libc++_shared.so")
            so.copyTo(dest, overwrite = true)
            logger.lifecycle("Overwrote ${dest.absolutePath} with project jniLibs libc++ (${so.length()} bytes)")
        }
    }
}

// Prefer project jniLibs libc++_shared.so over Flutter's smaller copy.
tasks.configureEach {
    val isMergeNative = name.startsWith("merge") && name.endsWith("NativeLibs")
    val isStripNative = name.startsWith("strip") && name.contains("DebugSymbols")
    if (!isMergeNative && !isStripNative) return@configureEach
    doLast { overwriteProjectLibcxx(logger) }
}
