# Termux 里的 Claude Code

[English](claude-code.md) | 简体中文

官方 Claude Code 二进制是怎么在 Termux 里跑起来的，以及如何安装、更新和卸载。

## 为什么需要包装

- npm 包 `@anthropic-ai/claude-code` 只是个安装器，真正的程序是按平台下载的预编译二进制。安装器里写了 `linux-arm64-android` 这个平台，但 npm 上没有对应的包（截至 2.1.332）。
- Termux 用的是 Android 的 bionic libc，官方 `linux-arm64` 二进制要的是 glibc（`/lib/ld-linux-aarch64.so.1`），直接跑会失败。

## 原理

1. 安装 Termux 社区的 glibc 运行环境（`glibc-repo` → `glibc`），装在 `$PREFIX/glibc`。
2. 从 npm 下载官方 `@anthropic-ai/claude-code-linux-arm64`，先做 sha512 校验，再用 `patchelf` 把 ELF 解释器和 rpath 改成 `$PREFIX/glibc`。改完后 `/proc/self/exe` 仍然是 claude 本身，Bun 内嵌的程序不受影响。
3. 包装脚本 `claude`：
   - 启动前去掉 `LD_PRELOAD`。Termux 的 bionic termux-exec 留着的话，glibc 加载器会报 `libc.so: invalid ELF header` 退出。
   - 把原来的值存到 `CLAUDE_TERMUX_LD_PRELOAD`，再用 `CLAUDE_CODE_SHELL` 指向 `shim-bash`。这样 Claude 的 Bash 工具执行命令时会恢复 termux-exec，`#!/usr/bin/env ...` 这类脚本能正常运行。
   - 设置 `DISABLE_AUTOUPDATER=1`。自带的自动更新会下载没 patch 过、跑不起来的版本，所以 `claude update` / `claude install` 被转去用 `claude-termux-update`。

## 安装

在 Termux 里执行（仅支持 aarch64）：

```sh
pkg install -y git
git clone https://github.com/hongdp/claude-termux.git
cd claude-termux && bash install.sh          # 默认 latest，也可以 bash install.sh stable
claude                                        # 首次进入后用 /login 登录
```

> 建议先跑一遍 `apt-get full-upgrade`，把 Termux 的包升级一致。分步升级如果中途断了，可能出现 libcurl 和 openssl 版本对不上，导致 curl 无法使用。

## 更新与回滚

```sh
claude-termux-update              # 更新到 latest
claude-termux-update stable       # 或 next / 具体版本号，如 2.1.326
claude-termux-update --list       # 列出已安装版本
claude-termux-update --rollback   # 切回上一个版本
claude update                     # 等同于 claude-termux-update
```

最多保留 2 个版本（当前版本加上一个），每个约 385 MB，装在 `~/.local/share/claude-native/`。

## 已验证 / 未验证

在 Pixel 10 Pro Fold（Android 17、内核 6.12、Termux）上测试了 2.1.332 和 2.1.326：

- ✅ `claude --version`、`claude auth status`，以及 `claude doctor`（API 和登录服务器连通、内置搜索正常）
- ✅ 安装、切换版本、回滚
- ✅ 登录后的交互界面、长对话、后台任务
- ✅ Bash 工具与 `shim-bash`：termux-exec 恢复正常，`./gradlew`（`#!/bin/sh`）这类脚本能直接运行
- ⚠️ Bash 工具里的 `grep` / `find`：见下方「已知问题」
- ⏳ hooks、MCP：还没测

`claude doctor` 会提示 `~/.local/bin` 不在 PATH 里、"install method unknown"。这是因为没走官方安装器，可以忽略。

### 已知问题

- Claude Code 会在 Bash 工具里把 `grep`、`find` 替换成内置的 ugrep、bfs，实际是用 argv0 重新执行 claude 本体。因为 `shim-bash` 恢复了 bionic 的 `LD_PRELOAD`，glibc 版 claude 一启动就报 `error while loading shared libraries: .../glibc/lib/libc.so: invalid ELF header`。临时办法是改用 `command grep`、`command find`；你在 Termux 里自己用的 `grep` 不受影响。环境变量 `EMBEDDED_SEARCH_TOOLS=0` 实测无效。要根治，需要在启动内置工具时去掉 `LD_PRELOAD`。

## 文件

| 文件 | 作用 |
| --- | --- |
| `install.sh` | 安装依赖，部署下面三个文件，然后下载并激活一个版本 |
| `claude` | 包装脚本，装到 `$PREFIX/bin/claude` |
| `claude-termux-update` | 下载、校验、patch、切换版本，装到 `$PREFIX/bin/` |
| `shim-bash` | 给 Bash 工具用的 bash 垫片，装到 `~/.local/share/claude-native/shim/bash` |

## 卸载

```sh
rm -rf ~/.local/share/claude-native "$PREFIX/bin/claude" "$PREFIX/bin/claude-termux-update"
# 可选：pkg uninstall glibc glibc-repo；登录信息和配置在 ~/.claude 和 ~/.claude.json
```

本仓库只有安装脚本，不包含也不分发 Claude Code 本体。Claude Code 由你的设备直接从 npm 官方源下载，使用时须遵守 Anthropic 的条款。
