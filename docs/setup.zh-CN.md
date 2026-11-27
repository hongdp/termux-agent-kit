# 从零开始配置

[English](setup.md) | 简体中文

从一台普通安卓手机，到 agent 跑在 Termux 里并能操作这台手机，需要的步骤都在这里，按顺序做。每一步最后都有一项检查，确认没问题再往下走。文末的[踩坑对照表](#踩坑对照表)列出了我们遇到过的问题和避开的办法。

测试设备是 Pixel 10 Pro Fold（Android 17，aarch64）。其他手机应该也能用，可能不一样的地方文中会提到。

## 1. 需要准备什么

- 一台 64 位 ARM 处理器（`aarch64`）的安卓手机，现在的手机基本都是。
- Wi-Fi。无线调试只在 Wi-Fi 打开时可用，即使 adb 连的是手机自己。
- 装一个 agent 大约需要 1 GB 空间（Claude Code 最多保留两个版本，每个约 385 MB）。
- 你要用的 agent 的账号：Claude Code 需要 Claude 订阅，Antigravity CLI 需要 Google 账号。

## 2. Termux 和 Termux:API

两个 App 要从**同一个来源**安装：都用 [Termux 的 GitHub releases](https://github.com/termux/termux-app/releases) 和 [Termux:API 的 releases](https://github.com/termux/termux-api/releases)，或者都用 F-Droid。不同来源的签名不一样，混装的话两个 App 互相连不上。本文用的是 GitHub 版本。

在 Termux 里：

```sh
apt-get update && apt-get full-upgrade -y     # 把所有包升级到互相匹配的版本
pkg install -y git android-tools termux-api tmux
```

- `android-tools` 提供 `adb`。
- `termux-api` 提供 `termux-clipboard-set`，agent 靠它输入文字。它需要 Termux:API 这个 App。
- `tmux` 让 agent 在 Termux 切到后台时继续运行。

**检查：** `termux-clipboard-set hello && termux-clipboard-get` 输出 `hello`。如果卡住不动，说明 Termux:API App 没装，或者和 Termux 不是同一个来源。

## 3. 安装一个 agent

**Claude Code：**

```sh
git clone https://github.com/hongdp/claude-termux.git
cd claude-termux && bash install.sh
claude                     # 第一次运行时执行 /login
```

**Antigravity CLI：** 见 [antigravity.zh-CN.md](antigravity.zh-CN.md)。

**检查：** `claude --version` 或 `agy --version` 能输出版本号。

## 4. 把 adb 连到手机自己

1. 打开开发者选项：设置 → 关于手机 → 连续点 **版本号** 七次。
2. 设置 → 系统 → 开发者选项 → 打开 **无线调试**。
3. 点 **使用配对码配对设备**。弹窗会显示 6 位配对码和一个端口，弹窗一关配对码就失效。用分屏把设置和 Termux 并排放，或者用小窗，然后运行：

   ```sh
   adb pair 127.0.0.1:<配对端口> <配对码>
   ```

4. 回到无线调试页面，读 **IP 地址和端口** 下面的端口（和配对端口不是同一个）：

   ```sh
   adb connect 127.0.0.1:<连接端口>
   ```

**检查：** `adb devices` 列出 `127.0.0.1:<端口>   device`。

重启、切换 Wi-Fi、或者把无线调试关掉再打开之后，连接端口会变。用新端口重新 `adb connect` 即可，配对不用重做。

### 屏幕 ID（折叠屏等多屏设备）

```sh
adb exec-out screencap -p > $TMPDIR/s.png; head -c 60 $TMPDIR/s.png
```

如果文件开头是 `[Warning] Multiple displays were found`，说明手机有不止一块屏幕，每次 `screencap` 都要加 `-d <ID>`。用 `adb shell dumpsys SurfaceFlinger --display-id` 列出 ID。折叠屏的外屏和内屏 ID 不同，要告诉 agent 当前用的是哪一块。

## 5. 给 agent 准备目录和说明

在单独的项目目录里启动 agent，不要在主目录里启动。

```sh
mkdir -p ~/projects/phone ~/bin
cp phone/AGENTS.zh-CN.md ~/projects/phone/AGENTS.md      # 在 claude-termux 目录里执行
cp phone/AGENTS.zh-CN.md ~/projects/phone/CLAUDE.md      # Claude Code 读的是 CLAUDE.md
cp phone/act.sh ~/bin/act.sh
```

编辑文件末尾“这台手机”一节：有屏幕 ID 的话填上，再写上你打算用的 App。

## 6. 第一次运行

```sh
cd ~/projects/phone && claude        # 或者：agy
```

接受目录信任提示，然后先让它做一件不会出岔子的小事：

> 打开设置，告诉我这台手机的 Android 版本，然后切回 Termux。

**检查：** 设置 App 打开了，agent 报出了版本号，Termux 回到了前台。

## 7. 用 agent 自己的 App 发指令（可选）

**Claude Code。** 先在这个目录里运行过一次 `claude` 并接受信任提示，然后：

```sh
cd ~/projects/phone && claude remote-control --name phone
```

接着打开手机上的 Claude App，进入 Code，新建会话，环境选这台设备。agent 执行的每条命令都需要你批准，除非你用 `--permission-mode` 选了别的权限模式；选之前先读一下 `claude remote-control --help`。

**Antigravity CLI。** 在 `tmux` 里运行 `agy --remote-control`，然后在浏览器里打开它打印的链接。见 [antigravity.zh-CN.md](antigravity.zh-CN.md)。

## 8. 让手机保持唤醒

屏幕锁住时 agent 没法操作，Android 也可能把后台的 Termux 停掉。

- 长任务开始前运行 `termux-wake-lock`（结束后 `termux-wake-unlock`）。
- 任务期间在 设置 → 显示 里把熄屏时间调长。
- 在 设置 → 应用 → Termux → 应用电池用量 里选 **无限制**。

## 踩坑对照表

| 现象 | 原因 | 怎么办 |
| --- | --- | --- |
| 屏幕方向锁定总是自己被解开 | `adb shell monkey` 退出时会打开自动旋转 | 用 `adb shell am start -n <包名>/<Activity>` 启动 App |
| 输入的文字不对，或者没进输入框 | `input text` 会经过输入法：自动纠错会改字，中文输入状态会把字吞掉 | 改用粘贴：`termux-clipboard-set "文字"; adb shell input keyevent 279` |
| agent 的会话自己停了 | 按键事件落到了 agent 自己的客户端上；`keyevent 111`（Esc）会按到它的停止按钮 | 绝不发送 `keyevent 111` |
| `claude remote-control` 提示 “Workspace not trusted” | 在主目录里启动；主目录的信任状态不会被保存 | 换成项目目录，并先在里面运行一次 `claude` |
| Claude Code 的 Bash 工具里 `grep`、`find` 报 `invalid ELF header` | 内置的替代品会带着 Termux 的 `LD_PRELOAD` 重新执行 glibc 二进制 | 用 `command grep` 和 `command find` |
| agent 读一个长列表要好几分钟 | 屏幕有动画时 `uiautomator dump` 一次要 10 秒以上 | 让它用截图和 App 自带的搜索（模板里已经写了） |
| 点击好像没反应 | App 还在播动画 | 用 `act.sh`，或者两次点击之间等一秒左右 |
| 截图文件里是 `Multiple displays were found` | 有不止一块屏幕 | 加 `-d <屏幕ID>` |
| 重启后 `adb devices` 是空的 | 连接端口变了 | `adb connect 127.0.0.1:<新端口>` |
| `agy` 每条命令都要确认 | Android 上没有沙箱，不能用 auto 模式 | 见 [antigravity.zh-CN.md](antigravity.zh-CN.md) |
| 装完包之后 `curl` 坏了 | 升级只做了一半，libcurl 和 openssl 版本不一致 | `apt-get full-upgrade` |
