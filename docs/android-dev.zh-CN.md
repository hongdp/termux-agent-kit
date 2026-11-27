# 在手机上开发、编译、调试 Android 应用

[English](android-dev.md) | 简体中文

全程在手机上开发 Android 应用：用 Termux + Gradle 编译，用无线调试的 adb 安装和调试，由 Claude Code 来操作。

这份攻略在 Pixel 10 Pro Fold（Android 17、aarch64）上走通过一遍：拿一个现成的 Kotlin + Jetpack Compose 项目（AGP 9.1.1、Gradle 9.3.1、compileSdk 36.1，依赖有 Room/KSP、CameraX、Retrofit），在手机上完成编译、安装和启动，并跑了 JVM 测试。本文只写验证过的步骤，没验证的会注明。

不需要 root，也不需要电脑。

## 0. 前提

- Termux（aarch64），并且已经装好一个 agent。本文的例子用的是 Claude Code（见 [claude-code.zh-CN.md](claude-code.zh-CN.md)）；其他能执行 shell 命令的 agent 用法相同。
- 至少 3 GB 空闲存储：Android SDK 约 1 GB，Gradle 缓存和依赖约 1–2 GB。
- 内存：Gradle 默认 `-Xmx4g`。编译前最好关掉后台 App，否则可能被系统杀掉。
- 项目里不能有原生代码（NDK / CMake / Rust）。原生部分本文没有覆盖，见文末。

## 1. 工具链

```sh
pkg install -y openjdk-21 aapt2 unzip android-tools
```

- `aapt2`：Termux 打包的 aarch64 原生版。Gradle 默认从 Maven 下载的 aapt2 是 x86_64 的，在手机上跑不了，后面要换成这个。
- `android-tools`：提供 `adb`，第 5 节用。

### Android SDK

**注意**：最新版 command-line tools（`commandlinetools-linux-16111833` 及之后）改成了 x86_64 原生程序，在手机上会报 `Syntax error: "(" unexpected`。要用还是 Java 实现的旧版，**`13114758` 验证可用**。

```sh
export ANDROID_HOME=~/android-sdk
export JAVA_HOME=$PREFIX/lib/jvm/java-21-openjdk
mkdir -p $ANDROID_HOME/cmdline-tools && cd $TMPDIR
curl -LO https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip
unzip -q commandlinetools-linux-13114758_latest.zip -d $ANDROID_HOME/cmdline-tools
mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest

yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses
# 平台版本按项目的 compileSdk 选
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platforms;android-36.1" "build-tools;36.1.0" "platform-tools"
```

- `sdkmanager` 必须设置 `JAVA_HOME`，否则会报 `Please set the JAVA_HOME variable`。
- `build-tools` 里的原生程序也是 x86_64 的，但 AGP 只检查它们在不在，真正用到的 `aapt2` 会被下面的配置换掉，`d8` 是 Java 写的。AGP 有时还会自动再装一份它默认的 build-tools 版本，属于正常现象。

## 2. Gradle 配置

两处配置都放在项目外面或者被 git 忽略的文件里，不改项目里被 git 跟踪的文件，方便和电脑上的开发环境共用一个仓库。

`~/.gradle/gradle.properties`（用户级，对所有项目生效）：

```properties
# 用 Termux 原生 aapt2 代替 Maven 上的 x86_64 版
android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2
org.gradle.java.home=/data/data/com.termux/files/usr/lib/jvm/java-21-openjdk
```

项目根目录的 `local.properties`（一般已经在 `.gitignore` 里）：

```properties
sdk.dir=/data/data/com.termux/files/home/android-sdk
```

编译时 Gradle 会提示 `The option setting 'android.aapt2FromMavenOverride=...' is experimental.`，可以忽略。

## 3. 编译

```sh
cd your-project
chmod +x gradlew
./gradlew assembleDebug
```

- 第一次要下载 Gradle 发行版和全部依赖。示例项目从零开始用了 **4 分 43 秒**，之后的增量编译会快很多。
- 产物在 `app/build/outputs/apk/debug/app-debug.apk`。
- 项目用了 debug keystore 的话，记得把它一起拷过来，否则签名和电脑上编的不一样，没法覆盖安装。

## 4. 测试（不用连手机）

```sh
./gradlew testDebugUnitTest
```

测试跑在 Termux 的 JVM 上，不需要设备。示例项目的实测结果：

| 测试类型 | 结果 |
| --- | --- |
| 普通 JUnit 单元测试 | ✅ 直接通过 |
| Robolectric | ✅ 关掉 Conscrypt 后通过，见下 |
| Roborazzi 截图测试（Robolectric native graphics） | ❌ 不支持 |

**Robolectric**：默认会加载 Conscrypt 的原生库 `conscrypt_openjdk_jni-linux-aarch_64`。这个库是给 glibc 编译的，Termux 的 bionic JDK 加载不了，会报 `UnsatisfiedLinkError`。用一个 Gradle 初始化脚本关掉它，不用改项目：

```groovy
// ~/.gradle/init.d/termux-robolectric.gradle
allprojects {
    tasks.withType(Test).configureEach {
        systemProperty 'robolectric.conscryptMode', 'OFF'
    }
}
```

关掉之后，代码里如果直接用到 Conscrypt 提供的加密实现，可能会有差异，一般的 Robolectric 测试不受影响。

**Roborazzi / native graphics**：会报 `The Robolectric native runtime is not supported on Linux (aarch64)`。Robolectric 没有发布 aarch64 Linux 的原生运行库，配置解决不了。界面截图请改用第 5 节的 adb 在真机上截。

## 5. 本机 adb：自己连自己

打开 Android 的「无线调试」后，Termux 里的 `adb` 可以连到手机本身。连上以后就能装 App、截屏、看日志、模拟点击，Claude Code 可以自己完成「改代码 → 编译 → 安装 → 看效果」整个循环。

### 配对和连接

配对（只需一次）和连接的步骤见 [setup.zh-CN.md](setup.zh-CN.md) 第 4 节。重启手机、换 Wi-Fi，或者关掉再打开无线调试后，连接端口都会变，要重新 `adb connect`；配对不用重做。

Termux 的 `adb` 不支持 mDNS（`adb mdns` 会提示 not supported），所以不能靠它发现端口。[phone/adb-connect.sh](../phone/adb-connect.sh) 用 `nmap` 扫本机端口范围来找，只要几秒。

### 常用操作

```sh
export ANDROID_SERIAL=127.0.0.1:<连接端口>
PKG=com.example.app

adb install -r app/build/outputs/apk/debug/app-debug.apk        # 装或覆盖，不用手点
adb shell am start -W -n $(adb shell cmd package resolve-activity --brief $PKG | tail -1)
adb logcat -c; adb logcat -d -b crash                            # 看崩溃
adb shell pidof $PKG                                             # 进程还在不在
adb shell input tap X Y                                          # 模拟点击
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml  # 界面元素和坐标
```

### 截屏：折叠屏要指定屏幕

有多块屏幕的设备（折叠屏）上，`screencap` 不指定屏幕的话，会在 PNG 开头输出一段警告文字，得到的文件打不开：

```sh
adb shell dumpsys SurfaceFlinger --display-id        # 列出屏幕 ID
adb exec-out screencap -d <display-id> -p > shot.png
```

Pixel 10 Pro Fold 的两块屏幕分别是 2076×2152（内屏）和 1080×2364（外屏），按尺寸就能认出当前用的是哪块。

### 和 Termux 共用屏幕

被测 App 和 Termux 在同一块屏幕上。Claude 在 Termux 里运行时，被测 App 一般在后台，直接截屏截到的是 Termux。正确顺序是：把 App 切到前台，等一两秒，截屏，再切回 Termux。

```sh
adb shell am start -W -n <pkg>/<activity>
sleep 3
adb exec-out screencap -d <display-id> -p > shot.png
adb shell am start -n com.termux/.app.TermuxActivity   # 切回 Termux
```

App 切到前台时会占用你的屏幕，所以让 Claude 先打招呼再测。

### 安全

无线调试开着时，adb 有 shell 级别的权限：能装卸 App、给任意画面截屏、读日志。不用的时候关掉。

## 6. 不用 adb 怎么装 APK

- `termux-open app.apk` 会调起系统安装器，但实测安装器可能一闪就关。
- 可靠的办法：运行 `termux-setup-storage` 授权访问存储，把 APK 复制到 `/storage/emulated/0/Download/`，再用「文件」App 点开安装。

复制完「文件」App 可能看不到这个文件，因为还没被媒体库收录。可以这样刷新：

```sh
am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///storage/emulated/0/Download/app.apk
```

## 7. 和 Claude Code 一起用时的已知问题

- Claude 的 Bash 工具会把 `grep`、`find` 换成内置的 ugrep、bfs。在本仓库的 glibc 方案下，`shim-bash` 恢复了 `LD_PRELOAD`，这两个内置工具会报 `libc.so: invalid ELF header`。改用 `command grep`、`command find` 就行，详见 [claude-code.zh-CN.md](claude-code.zh-CN.md)。
- 不要用 `pkill -f <模式>` 停后台进程：模式字符串也会出现在 Claude 自己的命令行里，会把这条命令自己也杀掉（exit 144）。用 PID 停。

## 没覆盖到的

- **NDK / 原生代码**：Google 没有 aarch64 Linux 版 NDK。有 C/C++/Rust 的项目要另找办法，比如用 Termux 自带的 clang、rust 交叉编译到 `aarch64-linux-android`，再改 Gradle 任务。本文没有验证。
- **Instrumented 测试**（`connectedAndroidTest`）：理论上连上 adb 就能跑，本文没有验证。
- **Android Studio 的布局预览、Profiler**：手机上没有。
