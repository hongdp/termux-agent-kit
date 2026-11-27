# Letting an agent use apps on your phone

English | [简体中文](phone-automation.zh-CN.md)

Once `adb` in Termux is connected to the phone itself, a coding agent running in Termux can operate any app the way a person does: read the screen, decide what to do, then tap, swipe or type. No root, no accessibility service, no extra app. Any agent that can run shell commands and read images will do; this guide was tested with Claude Code and Antigravity CLI (Gemini), and "Claude" below stands for whichever agent you use.

Tested on a Pixel 10 Pro Fold (Android 17): Claude opened Duolingo, picked the current lesson and completed it end to end with no wrong answers (translation, matching pairs, fill-in-the-blank and typing exercises). Listening and speaking exercises were skipped with the app's own "can't listen/speak now" buttons, since Claude can't hear audio or speak. It was a fun test and a bad way to study: the streak survived, but the only one who learned anything was the model. We don't recommend it.

> Respect each app's terms of service. Many apps forbid automated use of their service, so use this for your own experiments, testing and accessibility needs, not for farming points or rewards. Don't let Claude make payments, send money or message people on your behalf without checking each step.

## Setup

Follow [setup.md](setup.md) first: it covers Termux, the agent, pairing `adb` with the phone itself and the instruction file, with a check after each step. On a foldable, also find the display id:

```sh
adb shell dumpsys SurfaceFlinger --display-id
```

## The loop: look, decide, act

Each step the agent looks at the screen, decides on an action, and runs it.

**Look with a screenshot by default.** `adb exec-out screencap -p > $TMPDIR/s.png` takes well under a second and shows everything a person would see, including icons, images and web content.

**Add a UI dump when you need it.** `uiautomator dump` lists the elements on screen as text, with exact tap coordinates, and costs fewer tokens than an image. But it takes 10 seconds or more while anything on screen is animating, and it sees almost nothing inside canvas, game or web views. Use it for a static screen where you need precise coordinates or want to read a lot of text. This helper saves a screenshot and prints every element that has text, a content description or is clickable, together with its tap center in screen pixels:

```sh
#!/data/data/com.termux/files/usr/bin/bash
# look.sh: screenshot + compact UI element list with tap centers
# Usage: ANDROID_SERIAL=127.0.0.1:<port> DISPLAY_ID=<id> ./look.sh [out.png]
OUT=${1:-$TMPDIR/look.png}
adb exec-out screencap ${DISPLAY_ID:+-d $DISPLAY_ID} -p > "$OUT"
adb shell uiautomator dump --compressed /sdcard/ui.xml >/dev/null 2>&1
adb shell cat /sdcard/ui.xml | tr '>' '\n' | awk '
function attr(s,n){ if (match(s, n "=\"[^\"]*\"")) return substr(s,RSTART+length(n)+2,RLENGTH-length(n)-3); return "" }
/<node/ { t=attr($0,"text"); d=attr($0,"content-desc"); id=attr($0,"resource-id"); sub(/.*\//,"",id)
  c=attr($0,"clickable"); b=attr($0,"bounds")
  if (t=="" && d=="" && c!="true") next
  gsub(/[\[\]]/," ",b); split(b,p,/[ ,]+/)
  printf "%-38s | %-22s | %-24s %s (%d,%d)\n", substr(t,1,38), substr(d,1,22), substr(id,1,24), (c=="true"?"CLICK":""), (p[2]+p[4])/2, (p[3]+p[5])/2 }'
```

When the dump works, the text list is often enough to act on. Go back to the screenshot when the list is ambiguous, such as icon-only buttons or game-like screens, and to check a result.

Actions:

```sh
adb shell input tap X Y            # tap (screen pixel coordinates)
termux-clipboard-set "hello"; adb shell input keyevent 279   # type by pasting (see below)
adb shell input swipe X1 Y1 X2 Y2 300
adb shell input keyevent BACK
adb shell am start -n <pkg>/<activity>
```

## Give the agent its instructions

The agent needs to know how to operate the phone and where to stop. [phone/AGENTS.md](../phone/AGENTS.md) is a template with the method and the rules below; copy it into the folder you start the agent in (as `CLAUDE.md` for Claude Code, `AGENTS.md` or `GEMINI.md` for Antigravity CLI) and fill in the section about your phone.

## act.sh: act, then wait for the screen

[phone/act.sh](../phone/act.sh) (copied next to the instruction file during [setup](setup.md)) runs one or more actions and returns as soon as the screen stops changing, with a fresh screenshot. It replaces fixed `sleep`s, which are either too short (taps get lost) or too long.

```sh
./act.sh tap 540 1200                       # tap, wait until the screen settles, screenshot
./act.sh tap 540 300 paste "milk tea" key 66
./act.sh -u swipe 540 1800 540 600          # -u also prints the UI element list
```

In a four-step run through the Settings app it took 28.8 s, against 47.8 s for separate tap, sleep and screenshot commands.

## Send prompts from the phone itself (remote control)

You don't have to type into the terminal. Start the agent in Termux with remote control on, then talk to it from its own app or web page on the same phone. The agent opens the target app, works in it, and switches back to its client when it stops.

- **Claude Code**: `claude remote-control` in a project folder (run `claude` there once first to accept the trust prompt), then start a session on that device from the Claude app.
- **Antigravity CLI**: `agy --remote-control` inside `tmux`, then open the printed link in a browser. See [antigravity.md](antigravity.md).

Two things to know. The agent's client and the app it drives take turns on screen, so tell the agent to switch back when it stops (the template does). And a stray tap or key event that lands on the client can stop the session: on the phone, `keyevent 111` (Escape) hit the Claude app's stop button twice.

## What we tested

Same prompt both times, sent from the client on the phone: "Open DoorDash, order a milk tea from the nearest Tong Sui, you pick the drink, stop at the checkout page." Pixel 10 Pro Fold, folded, screenshots only.

| Agent | Model | Client | Result | Time |
| --- | --- | --- | --- | --- |
| Claude Code | Sonnet 5.5, high | Claude app | Reached checkout, did not order | about 1.5 min |
| Antigravity CLI 1.5.18 | Gemini 4 Hydrogen, high | Web page in Chrome | Reached checkout, did not order | about 5 min |

Each agent ran once, so treat the times as rough.

## Split screen: keep Termux visible (foldables and tablets)

On a large screen, put the app on the right half and keep Termux on the left, so you can watch what Claude is doing and interrupt at any time. Launch the app, look up its task id, then, with Termux in the foreground, move the app to the side stage:

```sh
adb shell am stack list | grep <pkg>          # "taskId=12345: <pkg>/..."
adb shell dumpsys activity service SystemUIService WMShell splitscreen moveToSideStage <taskId> 1
# 1 = right (or bottom), 0 = left (or top)
adb shell dumpsys activity service SystemUIService WMShell splitscreen exitSplitScreen <taskId>   # undo
```

On the Pixel 10 Pro Fold's inner display this gives Termux x 0–1026 and the app x 1050–2076. `uiautomator` still reports screen coordinates, so `look.sh` and `input tap` work unchanged. With `act.sh`, set `REGION="1050 2076"` (the app's columns) so that Termux's own spinner on the other half doesn't count as the screen still changing.

- **Mainly useful on foldables and tablets.** On a regular phone, half the screen is too narrow for most apps, so take over the full screen and switch back to Termux afterwards instead.
- **Watch the keyboard.** While Termux has focus, its soft keyboard covers the bottom part of *both* halves, which is often exactly where an app's Continue/Check buttons are. Check the screenshot before tapping low on the screen, or collapse the keyboard first.

## Lessons learned

- **Wait between taps.** Many apps animate after each tap and drop taps that arrive mid-animation. In matching exercises, taps 0.6 s apart were partly lost, while 1.3 s apart worked every time. After a batch of taps, run `look.sh` again to confirm the state instead of assuming.
- **Never blind-tap through screens you haven't read.** After the lesson, a loop that kept tapping the bottom-center button ran through reward and upsell screens (gift gems, a free trial, "add friends to your family plan"), and it was no longer clear which choice each tap had made. Read every non-routine screen and tap the button by its text.
- **`uiautomator dump` doesn't see everything.** Content drawn in a canvas or game view shows up as one big node. Use the screenshot for those.
- **Coordinates are screen pixels.** `uiautomator` bounds and `input tap` use the same coordinate space, but a downscaled screenshot preview does not. When you read a position off a screenshot, convert it back to full-resolution pixels before tapping; when you need exact coordinates, take them from a dump.
- **Without split screen, the app takes over the screen.** You can't use the phone while Claude drives it, and switching away mid-run makes Claude tap the wrong app. Switch back to Termux at the end with `adb shell am start -n com.termux/.app.TermuxActivity`. On a foldable or tablet, use split screen (above).
- **Type by pasting.** `input text` goes through the keyboard app. Autocorrect turned "Tang Shui" into "Tango Shui", and in a Chinese input mode the text ended up in the composing bar instead of the field. Setting the clipboard and sending `keyevent 279` (paste) avoids both.
- **Prefer screenshots to `uiautomator dump` for speed.** A dump takes 10 seconds or more while anything on screen animates. One run spent over three minutes dumping a long menu page by page; with screenshots and the app's own search, the same task took a minute and a half.
- **Some apps block screenshots** (`FLAG_SECURE`, common in banking and payment apps): screenshots come back black. `uiautomator` may still see the elements.
- **Audio is out of reach.** Claude can't hear the phone, so anything that depends on sound needs a text alternative.

## Limits

- Wireless debugging needs Wi-Fi, and the connect port changes after a reboot or network change, so this can't run unattended for long.
- It doesn't work while the screen is locked.
