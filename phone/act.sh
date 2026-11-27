#!/data/data/com.termux/files/usr/bin/bash
# act.sh: run adb input actions, then return as soon as the screen settles.
#
#   act.sh [-u] [-t secs] ACTION...      ACTION is one of:
#     tap X Y | swipe X1 Y1 X2 Y2 [ms] | key KEYCODE | paste TEXT | sleep SECS
#   -u        also print a UI element list (uiautomator, capped at 5 s)
#   -t secs   max time to wait for the screen to settle (default 8)
#
# Settle detection: hash a raw screencap every ~0.3 s; done when two
# consecutive hashes match after the screen first changed (or never changed
# within 1.5 s). Prints timing and saves the final screenshot to $OUT.
# Env: ANDROID_SERIAL, DISPLAY_ID, OUT (default $TMPDIR/act.png)
set -u
OUT=${OUT:-$TMPDIR/act.png}
WANT_UI=0; MAX=8
while getopts "ut:" o; do case $o in u) WANT_UI=1 ;; t) MAX=$OPTARG ;; *) exit 2 ;; esac; done
shift $((OPTIND - 1))
D=${DISPLAY_ID:+-d $DISPLAY_ID}
now() { date +%s%N; }
ms() { echo $(( ($(now) - $1) / 1000000 )); }
# REGION="x0 x1" limits change detection to those columns (e.g. the app's half in
# split screen, so Termux's own spinner doesn't count as "still changing").
# About 20 rows are sampled, spread over the real screen height, because each row
# slice costs one dd on the device.
if [ -n "${REGION:-}" ]; then
	read -r RX0 RX1 <<<"$REGION"
	# Raw screencap header: width and height as 32-bit integers, then pixel data from byte 16.
	read -r W H <<<"$(adb exec-out screencap $D | head -c 8 | od -An -tu4)"
	ROWS=$(seq $((H / 36)) $((H / 20)) $((H - 12)) | tr '\n' ' ')
	hash() { adb shell "screencap $D > /data/local/tmp/act.raw && for r in $ROWS; do dd if=/data/local/tmp/act.raw bs=4 skip=\$((4 + r*$W + $RX0)) count=$((RX1 - RX0)) 2>/dev/null; done | md5sum" 2>/dev/null | cut -c1-12; }
else
	hash() { adb shell "screencap $D | md5sum" 2>/dev/null | cut -c1-12; }
fi

T0=$(now)
before=$(hash)
while [ $# -gt 0 ]; do
	case $1 in
	tap) adb shell input tap "$2" "$3"; shift 3 ;;
	swipe) adb shell input swipe "$2" "$3" "$4" "$5" "${6:-300}"; [ $# -ge 6 ] && [[ $6 =~ ^[0-9]+$ ]] && shift 6 || shift 5 ;;
	key) adb shell input keyevent "$2"; shift 2 ;;
	paste) printf '%s' "$2" | termux-clipboard-set; adb shell input keyevent 279; printf '' | termux-clipboard-set; shift 2 ;;
	sleep) sleep "$2"; shift 2 ;;
	*) echo "unknown action: $1" >&2; exit 2 ;;
	esac
	[ $# -gt 0 ] && sleep 0.4 # let animations register between chained actions
done
TA=$(ms "$T0")

# Wait for the screen to change, then to settle.
T1=$(now); prev=$before; changed=0; state="timeout"
while :; do
	h=$(hash)
	if [ "$h" != "$prev" ]; then changed=1
	elif [ $changed = 1 ]; then state="settled"; break
	elif [ "$(ms "$T1")" -gt 1500 ]; then state="unchanged"; break
	fi
	prev=$h
	[ "$(ms "$T1")" -gt $((MAX * 1000)) ] && break
	sleep 0.3
done
TW=$(ms "$T1")

adb exec-out screencap $D -p > "$OUT"
if [ $WANT_UI = 1 ]; then
	TU0=$(now)
	if timeout 5 adb shell uiautomator dump --compressed /sdcard/ui.xml >/dev/null 2>&1; then
		adb shell cat /sdcard/ui.xml | tr '>' '\n' | awk '
function attr(s,n){ if (match(s, n "=\"[^\"]*\"")) return substr(s,RSTART+length(n)+2,RLENGTH-length(n)-3); return "" }
/<node/ { t=attr($0,"text"); d=attr($0,"content-desc"); id=attr($0,"resource-id"); sub(/.*\//,"",id)
  c=attr($0,"clickable"); b=attr($0,"bounds")
  if (t=="" && d=="" && c!="true") next
  gsub(/[\[\]]/," ",b); split(b,p,/[ ,]+/)
  printf "%-38s | %-22s | %-24s %s (%d,%d)\n", substr(t,1,38), substr(d,1,22), substr(id,1,24), (c=="true"?"CLICK":""), (p[2]+p[4])/2, (p[3]+p[5])/2 }'
		echo "[ui ${TU0:+$(ms "$TU0")}ms]"
	else
		echo "[ui dump timed out after 5s: screen still animating, use the screenshot]"
	fi
fi
echo "[actions ${TA}ms, wait ${TW}ms ($state), total $(ms "$T0")ms] screenshot: $OUT"
