# Operating this Android phone

You are running in Termux on an Android phone. `adb` is connected to the phone itself (wireless debugging), so you can operate any app the way a person does. Confirm with `adb devices` first.

Copy this file into the folder you start your agent in. Most agents read `AGENTS.md`; Claude Code reads `CLAUDE.md` and Antigravity CLI also reads `GEMINI.md`, so copy or symlink it under those names as needed. Edit the "This phone" section for your device.

## How to operate

- Launch apps with `adb shell am start -n <package>/<activity>`. Find the activity with `adb shell cmd package resolve-activity --brief <package>`.
- Look at the screen with a screenshot and your image-reading tool: `adb exec-out screencap -p > $TMPDIR/s.png` (add `-d <display id>` on multi-display devices).
- Act with `adb shell input tap X Y`, `input swipe X1 Y1 X2 Y2 300`, `input keyevent BACK`.
- Type by pasting, also for plain English: `termux-clipboard-set "text"; adb shell input keyevent 279`. `input text` goes through the keyboard app, which autocorrects it or swallows it in a non-Latin input mode.
- Put action, wait and screenshot in one shell command to save round trips, for example `adb shell input tap 540 1200; sleep 2; adb exec-out screencap -p > $TMPDIR/s.png`. `./act.sh` in this folder does this and returns as soon as the screen stops changing, for example `./act.sh tap 540 1200`.
- Read every screen before you tap. Don't tap through screens you haven't looked at.

## Rules

- **Stop before anything that spends money or sends something to another person.** Go as far as the checkout or review page, then stop and let the user press the final button.
- Don't change system settings the user didn't ask you to change.
- Never send `keyevent 111` (Escape): if the app in front is the agent's own client, it interrupts your session.
- When you stop (finished, blocked or waiting for an answer), bring the app the user talks to you through back to the front, and say what state you left the other app in.
- If you find the wrong app in front, the user probably switched away to look at something. Reopen the target app and continue.

## Speed

- Use screenshots. `uiautomator dump` takes 10 seconds or more while a screen is animating and sees little inside canvas or web views, so keep it for when a screenshot is not enough.
- Don't crawl a whole menu or list. Use the app's own search, pick from the first screen of results, and move on.

## This phone

- Device and display: <for example: Pixel foldable, outer display id 4619827677550801153>
- Apps you may be asked to use, with launch activities: <package/activity>
- Anything broken in this Termux setup: <for example: no python>
