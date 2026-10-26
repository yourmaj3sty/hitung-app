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
    project.evaluationDependsOn(":app")
}

fun configureAndroid(proj: Project) {
    val android = proj.extensions.findByName("android") ?: return
    for (m in android.javaClass.methods) {
        if (m.name == "setCompileSdk" && m.parameterCount == 1) {
            try { m.invoke(android, 36) } catch (_: Exception) {}
        }
        if (m.name == "compileSdkVersion" && m.parameterCount == 1) {
            try { m.invoke(android, 36) } catch (_: Exception) {}
        }
    }
}

subprojects {
    if (project.state.executed) {
        configureAndroid(project)
    } else {
        project.afterEvaluate {
            configureAndroid(project)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
