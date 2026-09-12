allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    afterEvaluate {
        // Fix namespace
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val namespaceMethod = androidExt.javaClass.getMethod("getNamespace")
                val namespace = namespaceMethod.invoke(androidExt)
                if (namespace == null) {
                    var fallback = "com.example." + project.name.replace("-", "_")
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestContent = manifestFile.readText()
                        val match = Regex("package=\"([^\"]+)\"").find(manifestContent)
                        if (match != null) {
                            fallback = match.groupValues[1]
                        }
                    }
                    val setNamespaceMethod = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    setNamespaceMethod.invoke(androidExt, fallback)
                }
            } catch (e: Exception) {}
            
            // Only force compileSdkVersion to 35 for plugins that have an old target
            if (project.name == "screenshot_callback") {
                try {
                    androidExt.javaClass.getMethod("setCompileSdk", Int::class.java).invoke(androidExt, 35)
                } catch (e: Exception) {
                    try {
                        androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java).invoke(androidExt, 35)
                    } catch(e2: Exception) {}
                }
            }

            // Force Java 17 for compileOptions
            try {
                val compileOptions = androidExt.javaClass.getMethod("getCompileOptions").invoke(androidExt)
                val setSource = compileOptions.javaClass.getMethod("setSourceCompatibility", org.gradle.api.JavaVersion::class.java)
                val setTarget = compileOptions.javaClass.getMethod("setTargetCompatibility", org.gradle.api.JavaVersion::class.java)
                setSource.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
                setTarget.invoke(compileOptions, org.gradle.api.JavaVersion.VERSION_17)
            } catch(e: Exception) {}
        }
    }
    
    // Some older plugins (like screen_protector) use Kotlin but don't apply the plugin in AGP 9
    if (project.name == "screen_protector") {
        if (!plugins.hasPlugin("kotlin-android") && !plugins.hasPlugin("org.jetbrains.kotlin.android")) {
            plugins.apply("org.jetbrains.kotlin.android")
        }
    }
    
    // Force JVM target 17 for Kotlin tasks
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
