# claude-termux

[English](README.md) | 简体中文

**在安卓手机上原生运行 AI 编程 agent，并让它们操作这台手机。**

Claude Code 和 Antigravity CLI，跑在 Termux 里。不用 root，不用 proot，不用虚拟机。

## 起因

我以前把 agent 跑在 PC 和一台 Linux 工作站上，再从手机远程连过去。有一天我不在家，工作站因为网线松了突然掉线，我开始想：跑 agent 真的需要这么强的机器吗？为什么不能直接跑在手机上？

Termux 很多年前就能做这类事，但在手机上敲命令行实在太难受。有了 agent，这就不是问题了：打字的是 agent。

## 能做什么

- **在手机上运行 agent。** Claude Code 通过本仓库的 glibc 包装运行；Antigravity CLI 有原生 Android 版本。
- **用它们自己的 App 发指令。** 在 Termux 里启动 agent 并打开遥控，然后在同一台手机上用 Claude App 或 Antigravity 网页发提示词。
- **在手机上直接开发 Android 应用。** agent 改代码、用 Gradle 编译、通过本机 adb 安装，再截图检查结果。
- **让 agent 操作手机。** 用同一个 adb 连接，它可以打开任何 App、看屏幕、点击、打字。忙的时候它可以替你做完一节语言课保住连胜，或者把外卖订单准备好，停在结账页，最后一步由你自己点。

下面这句提示词，两个 agent 都从头到尾完成了，提示词是从手机上它们各自的客户端发出的：

> 打开 DoorDash，帮我在最近的糖水（Tong Sui）点一杯奶茶，种类你来选，停在结账页面。

它们各自找到店、选好饮品、设好选项、到达结账页后停下，然后切回自己的客户端。

## 快速上手

**1. 安装一个 agent**（aarch64 的 Termux）：

```sh
# Claude Code
pkg install -y git
git clone https://github.com/hongdp/claude-termux.git
cd claude-termux && bash install.sh
claude                     # 第一次运行时执行 /login
```

Antigravity CLI 见 [docs/antigravity.zh-CN.md](docs/antigravity.zh-CN.md)，只需要一个安装脚本和一次浏览器登录。

**2. 把 adb 连到手机自己。** 打开无线调试，配对并连接 `127.0.0.1`。步骤见 [docs/android-dev.zh-CN.md](docs/android-dev.zh-CN.md) 第 5 节。

**3. 给 agent 一份说明。** 把 [phone/AGENTS.zh-CN.md](phone/AGENTS.zh-CN.md) 复制到启动 agent 的目录里（Claude Code 用 `CLAUDE.md` 这个名字），并填好关于你这台手机的一节。

**4. 提一个要求。** 先从小事开始，比如“打开设置，告诉我 Android 版本”，看着它怎么做。

## 支持的 agent

| Agent | 在 Termux 里怎么运行 | 在手机上遥控 | 指南 |
| --- | --- | --- | --- |
| Claude Code | 官方 `linux-arm64` 二进制，由本仓库的 `install.sh` 改成使用 Termux 的 glibc | Claude App | [见下文](#termux-里的-claude-code) |
| Antigravity CLI（`agy`，Gemini） | 官方原生 Android 二进制 | 浏览器里的网页 | [docs/antigravity.zh-CN.md](docs/antigravity.zh-CN.md) |

其他 agent 没有在这里测试过。只要它能在 Termux 里运行、能执行 `adb`、能看 PNG 图片，这套操作手机的工具应该就能用。

## 指南和工具

| | |
| --- | --- |
| [docs/phone-automation.zh-CN.md](docs/phone-automation.zh-CN.md) | 操作 App：准备工作、“看、想、做”的循环、遥控、折叠屏分屏、实测结果，以及一路上踩过的坑 |
| [docs/android-dev.zh-CN.md](docs/android-dev.zh-CN.md) | 在手机上编译、安装、调试 Android 应用 |
| [docs/antigravity.zh-CN.md](docs/antigravity.zh-CN.md) | Termux 里的 Antigravity CLI：安装、权限、记忆、遥控 |
| [phone/AGENTS.zh-CN.md](phone/AGENTS.zh-CN.md) | 给 agent 的说明模板（[English](phone/AGENTS.md)） |
| [phone/act.sh](phone/act.sh) | 执行点击、滑动、粘贴，屏幕一稳定就返回 |

## 把手机交给 agent 之前

agent 是用你的账号、在你的手机上操作。

- 说明模板要求它在花钱或给别人发东西之前停下。请保留这条规则。
- 看着它操作，至少在你信得过某类任务之前。折叠屏和平板可以用分屏，让终端一直显示在 App 旁边。
- 很多 App 的用户协议不允许自动化使用。请把这套方法用在自己的实验、测试和无障碍需求上。
- 只在一台设备上测试过：Pixel 10 Pro Fold，Android 17。其他手机可能要做些小改动，比如屏幕 ID。

## Termux 里的 Claude Code

本页余下部分说明 Claude Code 是怎么在 Termux 里跑起来的，以及如何更新和卸载。

### 为什么需要包装

- npm 包 `@anthropic-ai/claude-code` 只是个安装器，真正的程序是按平台下载的预编译二进制。安装器里写了 `linux-arm64-android` 这个平台，但 npm 上没有对应的包（截至 2.1.332）。
- Termux 用的是 Android 的 bionic libc，官方 `linux-arm64` 二进制要的是 glibc（`/lib/ld-linux-aarch64.so.1`），直接跑会失败。

### 原理

1. 安装 Termux 社区的 glibc 运行环境（`glibc-repo` → `glibc`），装在 `$PREFIX/glibc`。
2. 从 npm 下载官方 `@anthropic-ai/claude-code-linux-arm64`，先做 sha512 校验，再用 `patchelf` 把 ELF 解释器和 rpath 改成 `$PREFIX/glibc`。改完后 `/proc/self/exe` 仍然是 claude 本身，Bun 内嵌的程序不受影响。
3. 包装脚本 `claude`：
   - 启动前去掉 `LD_PRELOAD`。Termux 的 bionic termux-exec 留着的话，glibc 加载器会报 `libc.so: invalid ELF header` 退出。
   - 把原来的值存到 `CLAUDE_TERMUX_LD_PRELOAD`，再用 `CLAUDE_CODE_SHELL` 指向 `shim-bash`。这样 Claude 的 Bash 工具执行命令时会恢复 termux-exec，`#!/usr/bin/env ...` 这类脚本能正常运行。
   - 设置 `DISABLE_AUTOUPDATER=1`。自带的自动更新会下载没 patch 过、跑不起来的版本，所以 `claude update` / `claude install` 被转去用 `claude-termux-update`。

### 安装

在 Termux 里执行（仅支持 aarch64）：

```sh
pkg install -y git
git clone https://github.com/hongdp/claude-termux.git
cd claude-termux && bash install.sh          # 默认 latest，也可以 bash install.sh stable
claude                                        # 首次进入后用 /login 登录
```

> 建议先跑一遍 `apt-get full-upgrade`，把 Termux 的包升级一致。分步升级如果中途断了，可能出现 libcurl 和 openssl 版本对不上，导致 curl 无法使用。

### 更新与回滚

```sh
claude-termux-update              # 更新到 latest
claude-termux-update stable       # 或 next / 具体版本号，如 2.1.326
claude-termux-update --list       # 列出已安装版本
claude-termux-update --rollback   # 切回上一个版本
claude update                     # 等同于 claude-termux-update
```

最多保留 2 个版本（当前版本加上一个），每个约 385 MB，装在 `~/.local/share/claude-native/`。

### 已验证 / 未验证

在 Pixel 10 Pro Fold（Android 17、内核 6.12、Termux）上测试了 2.1.332 和 2.1.326：

- ✅ `claude --version`、`claude auth status`，以及 `claude doctor`（API 和登录服务器连通、内置搜索正常）
- ✅ 安装、切换版本、回滚
- ✅ 登录后的交互界面、长对话、后台任务
- ✅ Bash 工具与 `shim-bash`：termux-exec 恢复正常，`./gradlew`（`#!/bin/sh`）这类脚本能直接运行
- ⚠️ Bash 工具里的 `grep` / `find`：见下方「已知问题」
- ⏳ hooks、MCP：还没测

`claude doctor` 会提示 `~/.local/bin` 不在 PATH 里、"install method unknown"。这是因为没走官方安装器，可以忽略。

#### 已知问题

- Claude Code 会在 Bash 工具里把 `grep`、`find` 替换成内置的 ugrep、bfs，实际是用 argv0 重新执行 claude 本体。因为 `shim-bash` 恢复了 bionic 的 `LD_PRELOAD`，glibc 版 claude 一启动就报 `error while loading shared libraries: .../glibc/lib/libc.so: invalid ELF header`。临时办法是改用 `command grep`、`command find`；你在 Termux 里自己用的 `grep` 不受影响。环境变量 `EMBEDDED_SEARCH_TOOLS=0` 实测无效。要根治，需要在启动内置工具时去掉 `LD_PRELOAD`。

### 文件

| 文件 | 作用 |
| --- | --- |
| `install.sh` | 安装依赖，部署下面三个文件，然后下载并激活一个版本 |
| `claude` | 包装脚本，装到 `$PREFIX/bin/claude` |
| `claude-termux-update` | 下载、校验、patch、切换版本，装到 `$PREFIX/bin/` |
| `shim-bash` | 给 Bash 工具用的 bash 垫片，装到 `~/.local/share/claude-native/shim/bash` |

### 卸载

```sh
rm -rf ~/.local/share/claude-native "$PREFIX/bin/claude" "$PREFIX/bin/claude-termux-update"
# 可选：pkg uninstall glibc glibc-repo；登录信息和配置在 ~/.claude 和 ~/.claude.json
```

本仓库只有安装脚本，不包含也不分发 Claude Code 本体。Claude Code 由你的设备直接从 npm 官方源下载，使用时须遵守 Anthropic 的条款。
