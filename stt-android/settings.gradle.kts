pluginManagement {
    repositories {
        maven { url = uri(rootDir.resolve("../vendor/maven")) }
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        maven { url = uri(rootDir.resolve("../vendor/maven")) }
        google()
        mavenCentral()
    }
}

rootProject.name = "stt-android"
include(":app")
