# Setup from scratch

English | [简体中文](setup.zh-CN.md)

Everything needed to go from a stock Android phone to an agent that runs in Termux and operates the phone, in order. Each step ends with a check, so you know it worked before moving on. The [pitfalls table](#pitfalls) at the end lists what went wrong for us and how to avoid it.

Tested on a Pixel 10 Pro Fold (Android 17, aarch64). Other phones should work; the notes say where they may differ.

## 1. What you need

- An Android phone with a 64-bit ARM processor (`aarch64`), which covers nearly all current phones.
- Wi-Fi. Wireless debugging only works while Wi-Fi is on, even though adb connects to the phone itself.
- About 1 GB of free storage for one agent (Claude Code keeps up to two versions at about 385 MB each).
- An account for the agent you want to use: a Claude subscription for Claude Code, or a Google account for Antigravity CLI.

## 2. Termux and Termux:API

Install both apps from the **same source**: the [Termux GitHub releases](https://github.com/termux/termux-app/releases) and [Termux:API releases](https://github.com/termux/termux-api/releases), or F-Droid for both. They are signed per source, and a mismatched pair won't talk to each other. This guide was tested with the GitHub builds.

In Termux:

```sh
apt-get update && apt-get full-upgrade -y     # bring all packages to matching versions
pkg install -y git android-tools termux-api tmux
```

- `android-tools` provides `adb`.
- `termux-api` provides `termux-clipboard-set`, which the agent uses to type text. It needs the Termux:API app.
- `tmux` keeps an agent running while Termux is in the background.

**Check:** `termux-clipboard-set hello && termux-clipboard-get` prints `hello`. If it hangs, the Termux:API app is missing or from a different source.

## 3. Install an agent

**Claude Code:**

```sh
git clone https://github.com/hongdp/claude-termux.git
cd claude-termux && bash install.sh
claude                     # run /login the first time
```

**Antigravity CLI:** see [antigravity.md](antigravity.md).

**Check:** `claude --version` or `agy --version` prints a version.

## 4. Connect adb to the phone itself

1. Enable Developer options: Settings → About phone → tap **Build number** seven times.
2. Settings → System → Developer options → turn on **Wireless debugging**.
3. Tap **Pair device with pairing code**. A dialog shows a 6-digit code and a port, and the code stops working when the dialog closes. Put Settings and Termux side by side in split screen, or use a floating window, then run:

   ```sh
   adb pair 127.0.0.1:<pairing-port> <code>
   ```

4. Back on the Wireless debugging page, read the port under **IP address & Port** (it differs from the pairing port):

   ```sh
   adb connect 127.0.0.1:<connect-port>
   ```

**Check:** `adb devices` lists `127.0.0.1:<port>   device`.

The connect port changes after a reboot, a Wi-Fi change, or turning Wireless debugging off and on. Run `adb connect` again with the new port; pairing is kept.

### Display id (foldables and other multi-display devices)

```sh
adb exec-out screencap -p > $TMPDIR/s.png; head -c 60 $TMPDIR/s.png
```

If the file starts with `[Warning] Multiple displays were found`, the phone has more than one display and every `screencap` needs `-d <id>`. List the ids with `adb shell dumpsys SurfaceFlinger --display-id`. On a foldable the outer and inner screens have different ids, so tell the agent which one is in use.

## 5. A folder and instructions for the agent

Start the agent in its own project folder, not in your home directory.

```sh
mkdir -p ~/projects/phone ~/bin
cp phone/AGENTS.md ~/projects/phone/AGENTS.md      # run from the claude-termux folder
cp phone/AGENTS.md ~/projects/phone/CLAUDE.md      # Claude Code reads CLAUDE.md
cp phone/act.sh ~/bin/act.sh
```

Edit the "This phone" section at the end of the file: your display id if you have one, and the apps you expect to use.

## 6. First run

```sh
cd ~/projects/phone && claude        # or: agy
```

Accept the folder trust prompt, then try a harmless request:

> Open Settings and tell me which Android version this phone runs. Then switch back to Termux.

**Check:** the Settings app opens, the agent reports the version, and Termux comes back to the front.

## 7. Send prompts from the agent's own app (optional)

**Claude Code.** After you have run `claude` once in the folder and accepted the trust prompt:

```sh
cd ~/projects/phone && claude remote-control --name phone
```

Then open the Claude app on the phone, go to Code, start a new session and pick this device as the environment. Each command the agent runs needs your approval unless you choose a permission mode with `--permission-mode`; read `claude remote-control --help` before choosing one.

**Antigravity CLI.** `agy --remote-control` inside `tmux`, then open the printed link in a browser. See [antigravity.md](antigravity.md).

## 8. Keep the phone awake

The agent can't act while the screen is locked, and Android may stop Termux in the background.

- Run `termux-wake-lock` before a long task (`termux-wake-unlock` afterwards).
- Raise the screen timeout in Settings → Display for the duration of the task.
- In Settings → Apps → Termux → App battery usage, choose **Unrestricted**.

## Pitfalls

| What you see | Cause | What to do |
| --- | --- | --- |
| Rotation lock keeps turning itself off | `adb shell monkey` turns auto-rotate on when it exits | Launch apps with `adb shell am start -n <pkg>/<activity>` |
| Typed text is wrong, or doesn't appear in the field | `input text` goes through the keyboard app: autocorrect changes it, and a non-Latin input mode swallows it | Paste instead: `termux-clipboard-set "text"; adb shell input keyevent 279` |
| The agent's session stops by itself | A key event landed on the agent's own client; `keyevent 111` (Escape) presses its stop button | Never send `keyevent 111` |
| `claude remote-control`: "Workspace not trusted" | Started in the home directory, where trust is never saved | Use a project folder and run `claude` there once first |
| `grep` or `find` fail in Claude Code's Bash tool with `invalid ELF header` | The built-in replacements re-run the glibc binary with Termux's `LD_PRELOAD` | Use `command grep` and `command find` |
| The agent takes minutes on a long list | `uiautomator dump` takes 10 s or more while the screen animates | Tell it to use screenshots and the app's own search (the template does) |
| Taps seem to be ignored | The app was still animating | Use `act.sh`, or wait about a second between taps |
| Screenshot file contains `Multiple displays were found` | More than one display | Add `-d <display id>` |
| `adb devices` is empty after a reboot | The connect port changed | `adb connect 127.0.0.1:<new port>` |
| `agy` asks before every command | No sandbox on Android, so auto mode is unavailable | See [antigravity.md](antigravity.md#permissions-on-android) |
| `curl` breaks after installing packages | A partial upgrade left libcurl and openssl out of sync | `apt-get full-upgrade` |
| A second run behaves differently from the first | State left behind, such as an item in a cart | Reset the app's state before repeating a task |
