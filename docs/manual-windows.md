# Windows setup

Build the Android app on this online PC. The H100 is not involved. Training and inference on that machine are `docs/manual-training.md` and `docs/manual-inference.md`.

This PC already has Git and an Android SDK at `%LOCALAPPDATA%\Android\Sdk` (platform `android-37.0`, build-tools `36.0.0`). It does not need a separate JDK or Python install. The fetch script downloads both into `vendor/`.

## 1. Download the bundle

From the repo root (`D:\Workshop\SR`) while this PC has internet, run the download script. This is the one script that stays on the online PC. The H100 never runs it.

```
powershell -ExecutionPolicy Bypass -File vendor\fetch-online.ps1
# Add -IncludeAndroid when you want the app build as well. The default downloads the training bundle only.
```

The script downloads Temurin JDK 17, Gradle 8.13, the sherpa-onnx 1.13.6 AAR, Windows training wheels, and the published speech packs. It then runs `assembleDebug` once, which fills `vendor/gradle-user-home`. That first build still contacts Google's Maven server for AndroidX. Later builds do not.

If the script stops with `CUDA13_WHEEL_MISSING.txt`, the Android build can still be used, but do not copy `vendor/h100` to the server until a `cu130` wheel exists. That wheel is what runs on the server's CUDA 13.2 toolkit. Do not downgrade driver 597.95.

## 2. Environment for a rebuild

Command Prompt, from the repo root:

```
set /p JAVA_HOME=<vendor\windows\jdk-home.txt
set ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk
set GRADLE_USER_HOME=%CD%\vendor\gradle-user-home
```

`stt-android/local.properties` is written by the fetch script and points `sdk.dir` at that SDK. If you moved the SDK, edit that one line. Use escaped backslashes, for example `sdk.dir=C:\\Android\\Sdk`.

## 3. Build

```
cd stt-android
.\gradlew.bat assembleDebug --offline --no-daemon
```

`--offline` is valid after step 1 has succeeded. Drop `--offline` only when you are changing dependencies and this PC is online again.

The debug APK is:

```
stt-android\app\build\outputs\apk\debug\app-debug.apk
```

The screen says the speech shell is up and that language packs are not loaded yet. Loading packs is a later task. The sherpa-onnx AAR is already on the compile classpath.

## 4. When something fails

- `java` is not recognized: `JAVA_HOME` is missing. Set it from `vendor\windows\jdk-home.txt`. Do not rely on a system Java install.
- SDK location not found: `local.properties` is missing or `sdk.dir` is wrong. Re-run the fetch script, or write `sdk.dir` yourself.
- Could not unzip the Gradle distribution: `vendor\gradle\gradle-8.13-bin.zip` is missing or its hash does not match `vendor\checksums.sha256`. Re-run the fetch script. The wrapper URL is a `file:///` path rewritten by that script. If you move the repo, run the script again so it rewrites `stt-android\gradle\wrapper\gradle-wrapper.properties`.
- sherpa-onnx not found: `vendor\maven\com\k2fsa\sherpa\sherpa-onnx\1.13.6\` must contain the AAR and the POM. Re-run the fetch script.
