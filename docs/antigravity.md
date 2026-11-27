# Antigravity CLI (Gemini) in Termux

English | [简体中文](antigravity.zh-CN.md)

Google's Antigravity CLI (`agy`) ships a native Android build, so it runs in Termux without glibc, proot or patches. Tested: `agy` 1.5.18 on a Pixel 10 Pro Fold (Android 17) with Gemini 4 Hydrogen.

## Install and sign in

```sh
curl -fsSL https://antigravity.google/cli/install.sh -o install-agy.sh
less install-agy.sh        # it detects Android, downloads the binary and checks its sha512
bash install-agy.sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
agy                        # first run: sign in with your Google account in the browser
agy models                 # list the models your account can use
```

The binary lands in `~/.local/bin/agy`. Google's install page still lists only desktop systems, but the installer handles Termux.

## What to expect

The install itself had no technical problems on the test phone. A few things look like errors and aren't:

- Every `agy` command prints `ERROR: logging before google.Init: ... Initialized Android local timezone to ...` first. It is a log line, not a failure.
- The installer warns that `~/.local/bin` is not in `PATH`. That is what the `export PATH=...` line above fixes; until then, run it as `~/.local/bin/agy`.
- `--mode auto` prints a warning and continues in the default mode (see below).

Unlike Claude Code, `agy` needs no glibc, no binary patching and no wrapper script, and it has its own `agy update` command (not tried on the phone yet).

## Permissions on Android

`--mode auto` is not available on Android: it depends on a terminal sandbox that doesn't exist here, and `agy` falls back to asking before every command. For phone automation that means one confirmation per tap.

`--dangerously-skip-permissions` removes the prompts, and with them the only check between the model and your phone. Use it only for a task you are watching, in a folder whose instruction file tells the agent where to stop, and never leave such a session running unattended.

## Instructions and memory

`agy` reads `AGENTS.md` and `GEMINI.md` from the folder it starts in, and `~/.gemini/GEMINI.md` for every session. Put [phone/AGENTS.md](../phone/AGENTS.md) in the project folder. Notes that should apply to every session, such as quirks of your phone, go in `~/.gemini/GEMINI.md`.

The first time you start `agy` in a folder it asks whether you trust it.

## Drive it from a browser (Remote Control)

Run `agy` in `tmux` so it keeps running when Termux is in the background:

```sh
pkg install -y tmux
tmux new -s agy -c ~/projects/phone 'agy --remote-control --model gemini-4-hydrogen-high'
# Ctrl+b d detaches; tmux attach -t agy comes back
```

`agy` prints a link like `https://antigravity.google.com/r/<id>`. Open it in a browser signed in to the same Google account, on the phone itself or on any other device, open the conversation and send prompts from there. The tunnel closes when `agy` exits.

In the web page, check the model picker before you send: it has its own selection and may not match the `--model` you started with.
