#!/data/data/com.termux/files/usr/bin/bash
# adb-connect.sh: reconnect adb to this phone after the Wireless debugging port changed.
#
#   adb-connect.sh          print the connected serial, reconnecting if needed
#
# The connect port changes after a reboot, a Wi-Fi change, or toggling Wireless
# debugging. Pairing is kept, so the only thing missing is the new port. Termux's
# adb has no mDNS, so this scans the local port range Android picks from (a few
# seconds with nmap) and tries `adb connect` on each open port until one answers
# as an adb device.
#
# Needs: pkg install android-tools nmap. Pair once first (see docs/setup.md).
# The approach follows `adb-local` in github.com/bobbymac/termux-coding-agents.
set -u
HOST=127.0.0.1
STATE=${XDG_CACHE_HOME:-$HOME/.cache}/adb-connect-port

connected() { adb devices 2>/dev/null | awk -v h="$HOST:" 'index($1, h) == 1 && $2 == "device" { print $1; exit }'; }
try() { # try PORT: connect and confirm the device state
	timeout 4 adb connect "$HOST:$1" >/dev/null 2>&1
	[ "$(adb -s "$HOST:$1" get-state 2>/dev/null)" = device ]
}

s=$(connected); [ -n "$s" ] && { echo "$s"; exit 0; }
command -v nmap >/dev/null || { echo "adb-connect.sh: nmap is not installed (pkg install nmap)" >&2; exit 1; }
adb start-server >/dev/null 2>&1

# The last port that worked first, then every open port in Android's range.
ports=$( { cat "$STATE" 2>/dev/null; nmap -sT -p 30000-49999 --open -T5 -n "$HOST" 2>/dev/null | awk '/^[0-9]+\/tcp +open/ { split($1, a, "/"); print a[1] }'; } | awk '!seen[$0]++')
for p in $ports; do
	if try "$p"; then
		mkdir -p "$(dirname "$STATE")"; echo "$p" > "$STATE"
		echo "$HOST:$p"; exit 0
	fi
	adb disconnect "$HOST:$p" >/dev/null 2>&1
done
echo "adb-connect.sh: no adb port found on $HOST. Is Wireless debugging on (it needs Wi-Fi)? If this phone was never paired, pair first: adb pair $HOST:<pairing-port> <code>" >&2
exit 1
