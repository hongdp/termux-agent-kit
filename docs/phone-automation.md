# Letting Claude use apps on your phone

English | [简体中文](phone-automation.zh-CN.md)

Once `adb` in Termux is connected to the phone itself, Claude Code can operate any app the way a person does: read the screen, decide what to do, then tap, swipe or type. No root, no accessibility service, no extra app.

Tested on a Pixel 10 Pro Fold (Android 17): Claude opened a language-learning app, picked the current lesson and completed it end to end with no wrong answers (translation, matching pairs, fill-in-the-blank and typing exercises). Listening and speaking exercises were skipped with the app's own "can't listen/speak now" buttons, since Claude can't hear audio or speak.

> Respect each app's terms of service. Many apps forbid automated use of their service, so use this for your own experiments, testing and accessibility needs, not for farming points or rewards. Don't let Claude make payments, send money or message people on your behalf without checking each step.

## Setup

Pair and connect `adb` to `127.0.0.1` through Wireless debugging first; see section 5 of [android-dev.md](android-dev.md#5-local-adb-the-phone-connects-to-itself). Then find the display id (needed on foldables):

```sh
adb shell dumpsys SurfaceFlinger --display-id
```

## The loop: look, decide, act

Each step Claude takes a screenshot and a UI dump, decides on an action, and runs it. This helper does the "look" part. It saves a screenshot and prints every element that has text, a content description or is clickable, together with its tap center in screen pixels:

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

The text list is usually enough to act on, and it costs far fewer tokens than reading the screenshot. Claude only needs to look at the screenshot when the list is ambiguous, such as icon-only buttons, game-like screens or checking a result.

Actions:

```sh
adb shell input tap X Y            # tap (coordinates from look.sh)
adb shell input text hello         # type into the focused field
adb shell input swipe X1 Y1 X2 Y2 300
adb shell input keyevent BACK
adb shell am start -n <pkg>/<activity>   # or: monkey -p <pkg> -c android.intent.category.LAUNCHER 1
```

## Lessons learned

- **Wait between taps.** Many apps animate after each tap and drop taps that arrive mid-animation. In matching exercises, taps 0.6 s apart were partly lost, while 1.3 s apart worked every time. After a batch of taps, run `look.sh` again to confirm the state instead of assuming.
- **Never blind-tap through screens you haven't read.** After the lesson, a loop that kept tapping the bottom-center button ran through reward and upsell screens (gift gems, a free trial, "add friends to your family plan"), and it was no longer clear which choice each tap had made. Read every non-routine screen and tap the button by its text.
- **`uiautomator dump` doesn't see everything.** Content drawn in a canvas or game view shows up as one big node. Use the screenshot for those.
- **Coordinates are screen pixels.** `uiautomator` bounds and `input tap` use the same coordinate space, but a downscaled screenshot preview does not, so take coordinates from the dump.
- **The app takes over the screen.** You can't use the phone while Claude drives it, and switching away mid-run makes Claude tap the wrong app. Switch back to Termux at the end with `monkey -p com.termux -c android.intent.category.LAUNCHER 1`.
- **Some apps block screenshots** (`FLAG_SECURE`, common in banking and payment apps): screenshots come back black. `uiautomator` may still see the elements.
- **Audio is out of reach.** Claude can't hear the phone, so anything that depends on sound needs a text alternative.

## Limits

- Wireless debugging needs Wi-Fi, and the connect port changes after a reboot or network change, so this can't run unattended for long.
- It doesn't work while the screen is locked.
