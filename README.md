<div align="center">

# claude-termux

**Run AI coding agents natively on your Android phone, and let them use the phone.**

Claude Code and Antigravity CLI, running in Termux. No root, no proot, no VM.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![Platform: Android (Termux)](https://img.shields.io/badge/platform-Android%20%28Termux%29-3DDC84)
![Arch: aarch64](https://img.shields.io/badge/arch-aarch64-informational)
![Agents: Claude Code | Antigravity CLI](https://img.shields.io/badge/agents-Claude%20Code%20%7C%20Antigravity%20CLI-8A2BE2)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#contributing)

English | [简体中文](README.zh-CN.md)

</div>

---

## Contents

- [Why](#why)
- [Features](#features)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Supported agents](#supported-agents)
- [Documentation](#documentation)
- [Before you hand over your phone](#before-you-hand-over-your-phone)
- [Troubleshooting](#troubleshooting)
- [Repository layout](#repository-layout)
- [Contributing](#contributing)
- [License and disclaimer](#license-and-disclaimer)

## Why

I used to run my agents on a PC and a Linux workstation and connect to them from my phone. Then one day, while I was away, the workstation went offline because of a loose network cable, and I started to wonder: do I really need a beefy machine just to run agents? Why can't they run on the phone directly?

Termux has been able to do this kind of thing for years, but working in a CLI on a phone is painful. With an agent, that stops being a problem: the agent does the typing.

## Features

- **Agents on the phone.** Claude Code runs through the glibc wrapper in this repo. Antigravity CLI has a native Android build.
- **Prompts from the agent's own app.** Start the agent in Termux with remote control on, then talk to it from the Claude app or the Antigravity web page on the same phone.
- **Android development on the phone.** The agent edits the code, builds with Gradle, installs over a local adb connection and takes a screenshot to check its work.
- **Phone automation.** With the same adb connection the agent can open any app, read the screen, tap and type. It can finish a language lesson when you're too busy to keep your streak, or get a food order ready and stop at checkout so you press the final button yourself.

One prompt both agents handled from start to finish, sent from their client on the phone:

> Open DoorDash, order a milk tea from the nearest Tong Sui, you pick the drink, stop at the checkout page.

Each one found the store, picked a drink, set the options, reached the checkout page, stopped there and switched back to its client.

## Requirements

- An Android phone with a 64-bit ARM processor (`aarch64`)
- [Termux](https://github.com/termux/termux-app/releases) and [Termux:API](https://github.com/termux/termux-api/releases), both from the same source
- Wi-Fi, for Wireless debugging
- An account for the agent you use: a Claude subscription or a Google account

No root and no computer.

## Quick start

The short version. [docs/setup.md](docs/setup.md) has every step with a check after each one.

```sh
# 1. Packages
pkg install -y git android-tools termux-api tmux

# 2. An agent (Claude Code shown; for Antigravity CLI see docs/antigravity.md)
git clone https://github.com/hongdp/claude-termux.git
cd claude-termux && bash install.sh

# 3. adb to the phone itself: turn on Wireless debugging in Developer options, then
adb pair 127.0.0.1:<pairing-port> <code>
adb connect 127.0.0.1:<connect-port>

# 4. A folder with instructions for the agent
mkdir -p ~/projects/phone && cp phone/AGENTS.md ~/projects/phone/CLAUDE.md

# 5. Go
cd ~/projects/phone && claude
```

Then ask for something small first:

> Open Settings and tell me which Android version this phone runs. Then switch back to Termux.

## Supported agents

| Agent | How it runs in Termux | Remote control from the phone | Guide |
| --- | --- | --- | --- |
| Claude Code | Official `linux-arm64` binary, patched to use Termux's glibc by `install.sh` | Claude app | [docs/claude-code.md](docs/claude-code.md) |
| Antigravity CLI (`agy`, Gemini) | Official native Android binary | Web page in a browser | [docs/antigravity.md](docs/antigravity.md) |

Other agents have not been tested here. If one runs in Termux, can run `adb` and can look at a PNG, the phone kit should work with it. Reports are welcome.

## Documentation

| Guide | What it covers |
| --- | --- |
| [Setup from scratch](docs/setup.md) | Every step from a stock phone to a working agent, with checks and a pitfalls table |
| [Phone automation](docs/phone-automation.md) | The look-decide-act loop, remote control, split screen on foldables, test results, lessons learned |
| [Android development](docs/android-dev.md) | Building, installing and debugging Android apps on the phone |
| [Claude Code in Termux](docs/claude-code.md) | How the wrapper works, updating, rolling back, known issues, uninstalling |
| [Antigravity CLI in Termux](docs/antigravity.md) | Install, permissions on Android, memory, remote control |

## Before you hand over your phone

The agent acts with your accounts, on your phone.

- The instruction template tells it to stop before anything that spends money or sends something to another person. Keep that rule.
- Watch it work, at least until you trust a task. On a foldable or tablet, split screen keeps the terminal visible next to the app.
- Many apps forbid automated use in their terms of service. Use this for your own experiments, testing and accessibility needs.
- Tested on one device, a Pixel 10 Pro Fold on Android 17. Other phones may need small changes, such as display ids.

## Troubleshooting

The ones people hit first. The full table is in [docs/setup.md](docs/setup.md#pitfalls).

| What you see | What to do |
| --- | --- |
| Rotation lock keeps turning itself off | Don't launch apps with `adb shell monkey`; use `am start -n <pkg>/<activity>` |
| Typed text is wrong or missing | Paste instead of `input text`: `termux-clipboard-set "text"; adb shell input keyevent 279` |
| `claude remote-control`: "Workspace not trusted" | Start it in a project folder, not the home directory, after running `claude` there once |
| `grep` / `find` fail inside Claude Code with `invalid ELF header` | Use `command grep` and `command find` |
| `adb devices` is empty after a reboot | The port changed: `adb connect 127.0.0.1:<new port>` |

## Repository layout

```
install.sh              Installs Claude Code for Termux (glibc, patched binary, wrapper)
claude                  Wrapper script, installed to $PREFIX/bin/claude
claude-termux-update    Update, list versions, roll back
shim-bash               Shell shim for Claude Code's Bash tool
phone/AGENTS.md         Instruction template for any agent (also in zh-CN)
phone/act.sh            Run taps, swipes and pastes, return when the screen settles
docs/                   Guides, each in English and Simplified Chinese
```

## Contributing

Issues and pull requests are welcome. The most useful contributions right now:

- **Device reports.** What worked or didn't on your phone and Android version.
- **Other agents.** Steps to run another coding agent in Termux, with what you tested.
- **Pitfalls.** A problem you hit and how you got past it, for the table in [docs/setup.md](docs/setup.md#pitfalls).

Please describe only what you actually ran, and keep both language versions of a doc in step when you change one.

## License and disclaimer

[MIT](LICENSE).

This repository contains install scripts, helper scripts and documentation. It does not include or redistribute Claude Code or Antigravity CLI: your device downloads them from their official sources, and their use is subject to Anthropic's and Google's terms. This project is not affiliated with Anthropic, Google, or any app mentioned in the docs.
