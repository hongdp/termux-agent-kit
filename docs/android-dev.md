# Building, testing and debugging Android apps on the phone

English | [简体中文](android-dev.zh-CN.md)

Develop an Android app entirely on the phone: build with Termux + Gradle, install and debug with adb over wireless debugging, driven by Claude Code.

This guide was walked through end to end on a Pixel 10 Pro Fold (Android 17, aarch64) with an existing Kotlin + Jetpack Compose project (AGP 9.1.1, Gradle 9.3.1, compileSdk 36.1, with Room/KSP, CameraX and Retrofit): it was built, installed and launched on the phone, and its JVM tests were run there. Only verified steps are described; anything not verified is marked as such.

No root and no computer needed.

## 0. Prerequisites

- Termux (aarch64) with an agent installed. The examples use Claude Code ([claude-code.md](claude-code.md)); any agent that can run shell commands works the same way.
- At least 3 GB of free storage: about 1 GB for the Android SDK and 1–2 GB for Gradle caches and dependencies.
- Memory: Gradle defaults to `-Xmx4g`. Close background apps before building, or the system may kill the build.
- The project must not contain native code (NDK / CMake / Rust). Native code is not covered here; see the end of this guide.

## 1. Toolchain

```sh
pkg install -y openjdk-21 aapt2 unzip android-tools
```

- `aapt2`: Termux's native aarch64 build. The aapt2 Gradle downloads from Maven by default is x86_64 and won't run on the phone, so it gets swapped for this one later.
- `android-tools`: provides `adb`, used in section 5.

### Android SDK

**Note**: the newest command-line tools (`commandlinetools-linux-16111833` and later) are x86_64 native binaries and fail on the phone with `Syntax error: "(" unexpected`. Use an older, Java-based release; **`13114758` is verified to work**.

```sh
export ANDROID_HOME=~/android-sdk
export JAVA_HOME=$PREFIX/lib/jvm/java-21-openjdk
mkdir -p $ANDROID_HOME/cmdline-tools && cd $TMPDIR
curl -LO https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
unzip -q commandlinetools-linux-13114758_latest.zip -d $ANDROID_HOME/cmdline-tools
mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest

yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses
# Pick the platform that matches the project's compileSdk
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platforms;android-36.1" "build-tools;36.1.0" "platform-tools"
```

- `sdkmanager` needs `JAVA_HOME` set, or it fails with `Please set the JAVA_HOME variable`.
- The native programs in `build-tools` are x86_64 too, but AGP only checks that they exist: the `aapt2` it actually runs is replaced by the setting below, and `d8` is written in Java. AGP may also install its own default build-tools version on top; that's expected.

## 2. Gradle configuration

Both settings live outside the project or in a git-ignored file, so no tracked project file changes and the same repository keeps working with a desktop setup.

`~/.gradle/gradle.properties` (user level, applies to every project):

```properties
# Use Termux's native aapt2 instead of the x86_64 one from Maven
android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2
org.gradle.java.home=/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk
```

`local.properties` in the project root (normally already in `.gitignore`):

```properties
sdk.dir=/data/data/com.termux/files/home/android-sdk
```

Gradle will warn `The option setting 'android.aapt2FromMavenOverride=...' is experimental.`; it's safe to ignore.

## 3. Build

```sh
cd your-project
chmod +x gradlew
./gradlew assembleDebug
```

- The first build downloads the Gradle distribution and all dependencies. The example project took **4 min 43 s** from scratch; incremental builds after that are much faster.
- The output is `app/build/outputs/apk/debug/app-debug.apk`.
- If the project uses a debug keystore, copy it over too. Otherwise the signature differs from your desktop builds and the APK can't be installed over them.

## 4. Tests (no device needed)

```sh
./gradlew testDebugUnitTest
```

These tests run on Termux's JVM and don't need a device. Results for the example project:

| Test type | Result |
| --- | --- |
| Plain JUnit unit tests | ✅ Pass as-is |
| Robolectric | ✅ Pass with Conscrypt turned off, see below |
| Roborazzi screenshot tests (Robolectric native graphics) | ❌ Not supported |

**Robolectric**: by default it loads Conscrypt's native library `conscrypt_openjdk_jni-linux-aarch_64`. That library is built for glibc, so Termux's bionic JDK can't load it and you get `UnsatisfiedLinkError`. Turn it off with a Gradle init script, without touching the project:

```groovy
// ~/.gradle/init.d/termux-robolectric.gradle
allprojects {
    tasks.withType(Test).configureEach {
        systemProperty 'robolectric.conscryptMode', 'OFF'
    }
}
```

With Conscrypt off, code that relies directly on Conscrypt's crypto implementation may behave differently; ordinary Robolectric tests are not affected.

**Roborazzi / native graphics**: fails with `The Robolectric native runtime is not supported on Linux (aarch64)`. Robolectric doesn't publish a native runtime for aarch64 Linux, and no setting fixes that. Take UI screenshots on the real device with adb instead (section 5).

## 5. Local adb: the phone connects to itself

Once Android's Wireless debugging is on, `adb` in Termux can connect to the phone itself. That lets you install apps, take screenshots, read logs and simulate taps, so Claude Code can run the whole "edit → build → install → check the result" loop by itself.

### Pairing and connecting

Pair once and connect as described in [setup.md](setup.md#4-connect-adb-to-the-phone-itself). The connect port changes after a reboot, a Wi-Fi change, or toggling Wireless debugging, so run `adb connect` again; pairing is kept.

Termux's `adb` doesn't support mDNS (`adb mdns` reports not supported), so the port can't be discovered automatically; read it off the screen. Scanning local ports 30000–49999 one by one is too slow to be practical.

### Common operations

```sh
export ANDROID_SERIAL=127.0.0.1:<connect-port>
PKG=com.example.app

adb install -r app/build/outputs/apk/debug/app-debug.apk        # install or replace, no tapping
adb shell am start -W -n $(adb shell cmd package resolve-activity --brief $PKG | tail -1)
adb logcat -c; adb logcat -d -b crash                            # crashes
adb shell pidof $PKG                                             # is the process alive
adb shell input tap X Y                                          # simulate a tap
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml  # UI elements and coordinates
```

### Screenshots: pick a display on foldables

On devices with more than one display (foldables), `screencap` without a display id prepends a warning text to the PNG and the file won't open:

```sh
adb shell dumpsys SurfaceFlinger --display-id        # list display ids
adb exec-out screencap -d <display-id> -p > shot.png
```

The Pixel 10 Pro Fold's two displays are 2076×2152 (inner) and 1080×2364 (outer), so the size tells you which one is in use.

### Sharing the screen with Termux

The app under test and Termux share one screen. While Claude runs in Termux, the app is usually in the background, and a plain screenshot captures Termux. The right sequence is: bring the app to the front, wait a moment, take the screenshot, then switch back to Termux.

```sh
adb shell am start -W -n <pkg>/<activity>
sleep 3
adb exec-out screencap -d <display-id> -p > shot.png
adb shell am start -n com.termux/.app.TermuxActivity   # back to Termux
```

Bringing the app to the front takes over your screen, so have Claude announce it before testing.

### Security

While Wireless debugging is on, adb has shell-level access: it can install and uninstall apps, screenshot anything on screen and read logs. Turn it off when you're not using it.

## 6. Installing an APK without adb

- `termux-open app.apk` launches the system installer, but in practice the installer may flash and close.
- The reliable way: run `termux-setup-storage` to grant storage access, copy the APK to `/storage/emulated/0/Download/`, then open it from the Files app to install.

After copying, the Files app may not show the file yet because the media index hasn't picked it up. Refresh it with:

```sh
am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///storage/emulated/0/Download/app.apk
```

## 7. Known issues when used with Claude Code

- Claude's Bash tool replaces `grep` and `find` with its embedded ugrep and bfs. With this repo's glibc setup, `shim-bash` restores `LD_PRELOAD` and those two tools fail with `libc.so: invalid ELF header`. Use `command grep` and `command find` instead; see [claude-code.md](claude-code.md).
- Don't stop background processes with `pkill -f <pattern>`: the pattern also appears in Claude's own command line, so the command kills itself (exit 144). Stop processes by PID.

## Not covered

- **NDK / native code**: Google doesn't ship an aarch64 Linux NDK. Projects with C/C++/Rust need another route, such as cross-compiling to `aarch64-linux-android` with Termux's own clang or rust and adjusting the Gradle tasks. Not verified here.
- **Instrumented tests** (`connectedAndroidTest`): should work once adb is connected, but not verified here.
- **Android Studio's layout preview and Profiler**: not available on the phone.
