# claude-termux

English | [简体中文](README.zh-CN.md)

**Run AI coding agents natively on your Android phone, and let them use the phone.**

Claude Code and Antigravity CLI, running in Termux. No root, no proot, no VM.

## Why

I used to run my agents on a PC and a Linux workstation and connect to them from my phone. Then one day, while I was away, the workstation went offline because of a loose network cable, and I started to wonder: do I really need a beefy machine just to run agents? Why can't they run on the phone directly?

Termux has been able to do this kind of thing for years, but working in a CLI on a phone is painful. With an agent, that stops being a problem: the agent does the typing.

## What you can do

- **Run the agents on the phone.** Claude Code runs through the glibc wrapper in this repo. Antigravity CLI has a native Android build.
- **Talk to them from their own apps.** Start the agent in Termux with remote control on, then send prompts from the Claude app or the Antigravity web page on the same phone.
- **Build Android apps on the phone itself.** The agent edits the code, builds with Gradle, installs over a local adb connection and takes a screenshot to check its work.
- **Let the agent operate the phone.** With the same adb connection it can open any app, read the screen, tap and type. It can finish a language lesson when you're too busy to keep your streak, or get a food order ready and stop at checkout so you press the final button yourself.

One prompt both agents handled from start to finish, sent from their client on the phone:

> Open DoorDash, order a milk tea from the nearest Tong Sui, you pick the drink, stop at the checkout page.

Each one found the store, picked a drink, set the options, reached the checkout page, stopped there and switched back to its client.

## Quick start

**1. Install an agent** (Termux on aarch64):

```sh
# Claude Code
pkg install -y git
git clone https://github.com/hongdp/claude-termux.git
cd claude-termux && bash install.sh
claude                     # run /login the first time
```

For Antigravity CLI, follow [docs/antigravity.md](docs/antigravity.md); it takes one install script and a browser sign-in.

**2. Connect adb to the phone itself.** Turn on Wireless debugging, then pair and connect to `127.0.0.1`. The steps are in [docs/android-dev.md](docs/android-dev.md#5-local-adb-the-phone-connects-to-itself).

**3. Give the agent its instructions.** Copy [phone/AGENTS.md](phone/AGENTS.md) into the folder you start the agent in (as `CLAUDE.md` for Claude Code) and fill in the section about your phone.

**4. Ask for something.** Start small, for example "open Settings and tell me the Android version", and watch what it does.

## Agents

| Agent | How it runs in Termux | Remote control from the phone | Guide |
| --- | --- | --- | --- |
| Claude Code | Official `linux-arm64` binary, patched to use Termux's glibc by `install.sh` in this repo | Claude app | [below](#claude-code-in-termux) |
| Antigravity CLI (`agy`, Gemini) | Official native Android binary | Web page in a browser | [docs/antigravity.md](docs/antigravity.md) |

Other agents have not been tested here. If one runs in Termux, can run `adb` and can look at a PNG, the phone kit should work with it.

## Guides and tools

| | |
| --- | --- |
| [docs/phone-automation.md](docs/phone-automation.md) | Operating apps: setup, the look-decide-act loop, remote control, split screen on foldables, test results, and what went wrong along the way |
| [docs/android-dev.md](docs/android-dev.md) | Building, installing and debugging Android apps on the phone |
| [docs/antigravity.md](docs/antigravity.md) | Antigravity CLI in Termux: install, permissions, memory, remote control |
| [phone/AGENTS.md](phone/AGENTS.md) | Instruction template for the agent ([中文](phone/AGENTS.zh-CN.md)) |
| [phone/act.sh](phone/act.sh) | Runs taps, swipes and pastes, then returns as soon as the screen settles |

## Before you hand over your phone

The agent acts with your accounts, on your phone.

- The instruction template tells it to stop before anything that spends money or sends something to another person. Keep that rule.
- Watch it work, at least until you trust a task. On a foldable or tablet, split screen keeps the terminal visible next to the app.
- Many apps forbid automated use in their terms of service. Use this for your own experiments, testing and accessibility needs.
- Tested on one device, a Pixel 10 Pro Fold on Android 17. Other phones may need small changes, such as display ids.

## Claude Code in Termux

The rest of this page explains how Claude Code is made to run in Termux, and how to update or remove it.

### Why a wrapper is needed

- The npm package `@anthropic-ai/claude-code` is only an installer; the real program is a prebuilt binary downloaded per platform. The installer knows a `linux-arm64-android` platform, but no such package is published on npm (as of 2.1.332).
- Termux uses Android's bionic libc, while the official `linux-arm64` binary expects glibc (`/lib/ld-linux-aarch64.so.1`), so it fails to start as-is.

### How it works

1. Install Termux's community glibc runtime (`glibc-repo` → `glibc`) into `$PREFIX/glibc`.
2. Download the official `@anthropic-ai/claude-code-linux-arm64` from npm, verify its sha512, then use `patchelf` to point the ELF interpreter and rpath at `$PREFIX/glibc`. `/proc/self/exe` is still the claude binary itself, so Bun's embedded program keeps working.
3. The `claude` wrapper script:
   - Drops `LD_PRELOAD` before starting. If Termux's bionic termux-exec is left in place, the glibc loader exits with `libc.so: invalid ELF header`.
   - Saves the original value in `CLAUDE_TERMUX_LD_PRELOAD` and points `CLAUDE_CODE_SHELL` at `shim-bash`, so commands run by Claude's Bash tool get termux-exec back and `#!/usr/bin/env ...` scripts work.
   - Sets `DISABLE_AUTOUPDATER=1`. The built-in updater would fetch an unpatched binary that can't start, so `claude update` / `claude install` are routed to `claude-termux-update`.

### Install

In Termux (aarch64 only):

```sh
pkg install -y git
git clone https://github.com/hongdp/claude-termux.git
cd claude-termux && bash install.sh          # latest by default; or: bash install.sh stable
claude                                        # run /login the first time
```

> Run `apt-get full-upgrade` first so all Termux packages are on matching versions. An interrupted partial upgrade can leave libcurl and openssl out of sync and break curl.

### Update and roll back

```sh
claude-termux-update              # update to latest
claude-termux-update stable       # or next / an exact version, e.g. 2.1.326
claude-termux-update --list       # list installed versions
claude-termux-update --rollback   # switch back to the previous version
claude update                     # same as claude-termux-update
```

At most 2 versions are kept (current plus previous), about 385 MB each, under `~/.local/share/claude-native/`.

### Verified / not yet verified

Tested 2.1.332 and 2.1.326 on a Pixel 10 Pro Fold (Android 17, kernel 6.12, Termux):

- ✅ `claude --version`, `claude auth status`, and `claude doctor` (API and login servers reachable, built-in search OK)
- ✅ Install, switching versions, rollback
- ✅ Interactive UI after login, long sessions, background tasks
- ✅ Bash tool with `shim-bash`: termux-exec is restored, and scripts like `./gradlew` (`#!/bin/sh`) run directly
- ⚠️ `grep` / `find` inside the Bash tool: see "Known issues" below
- ⏳ Hooks, MCP: not tested yet

`claude doctor` reports that `~/.local/bin` is not in PATH and "install method unknown". That's because the official installer wasn't used; it's safe to ignore.

#### Known issues

- In the Bash tool, Claude Code replaces `grep` and `find` with its embedded ugrep and bfs, which re-exec the claude binary under a different argv0. Because `shim-bash` restores bionic's `LD_PRELOAD`, the glibc claude binary fails immediately with `error while loading shared libraries: .../glibc/lib/libc.so: invalid ELF header`. Workaround: use `command grep` and `command find`. The `grep` you use yourself in Termux is not affected. Setting `EMBEDDED_SEARCH_TOOLS=0` does not help (tested). A real fix needs `LD_PRELOAD` removed when the embedded tools start.

### Files

| File | Purpose |
| --- | --- |
| `install.sh` | Installs dependencies, deploys the three files below, then downloads and activates a version |
| `claude` | Wrapper script, installed to `$PREFIX/bin/claude` |
| `claude-termux-update` | Downloads, verifies, patches and switches versions; installed to `$PREFIX/bin/` |
| `shim-bash` | Bash shim for the Bash tool, installed to `~/.local/share/claude-native/shim/bash` |

### Uninstall

```sh
rm -rf ~/.local/share/claude-native "$PREFIX/bin/claude" "$PREFIX/bin/claude-termux-update"
# Optional: pkg uninstall glibc glibc-repo; login and settings live in ~/.claude and ~/.claude.json
```

This repository only contains install scripts; it does not include or redistribute Claude Code itself. Your device downloads Claude Code directly from the official npm registry, and its use is subject to Anthropic's terms.
