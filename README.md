# claude-termux

English | [简体中文](README.zh-CN.md)

Run AI coding agents **natively** in Termux on Android and let them operate the phone: open apps, read the screen, tap and type, with you sending prompts from the agent's own app or web page on the same phone. No root, no proot, no accessibility service.

The repo started as a way to run Claude Code in Termux (hence the name) and now covers three things:

1. **Getting agents to run in Termux.** Claude Code needs the glibc wrapper in this repo; Antigravity CLI has a native Android build.
2. **A kit for operating the phone**, which works with any agent that can run shell commands and read images: an instruction file for the agent, a helper script, and a guide with the lessons learned.
3. **Building Android apps on the phone itself.**

## Agents

| Agent | How it runs in Termux | Remote control from the phone | Guide |
| --- | --- | --- | --- |
| Claude Code | Official `linux-arm64` binary, patched to use Termux's glibc by `install.sh` in this repo | Claude app | [below](#claude-code-in-termux) |
| Antigravity CLI (`agy`, Gemini) | Official native Android binary | Web page in a browser | [docs/antigravity.md](docs/antigravity.md) |

Other agents have not been tested here. If one runs in Termux, can run `adb` and can look at a PNG, the phone kit below should work with it.

## Operate the phone

Connect `adb` in Termux to the phone itself through Wireless debugging, drop [phone/AGENTS.md](phone/AGENTS.md) into the agent's folder, and ask for something:

> Open DoorDash, order a milk tea from the nearest Tong Sui, you pick the drink, stop at the checkout page.

Both tested agents did this from a prompt sent on the phone, stopped at checkout and switched back to their client. Claude Code with Sonnet 5.5 took about a minute and a half; Antigravity CLI with Gemini 4 Hydrogen took about five minutes, in one run each under slightly different conditions.

- [docs/phone-automation.md](docs/phone-automation.md): setup, the look-decide-act loop, remote control, split screen on foldables, and what went wrong along the way.
- [phone/AGENTS.md](phone/AGENTS.md): instruction template for the agent ([中文](phone/AGENTS.zh-CN.md)).
- [phone/act.sh](phone/act.sh): runs taps, swipes and pastes, then returns as soon as the screen settles.

The agent acts with your accounts on your phone. The template tells it to stop before anything that spends money or sends something to another person; keep that rule, watch what it does, and respect each app's terms of service.

## Build Android apps on the phone

With Termux, Gradle and the same local adb connection, an agent can run the whole "edit → build → install → screenshot to verify" loop on the phone. Full guide: [docs/android-dev.md](docs/android-dev.md).

## Claude Code in Termux

### Why

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
