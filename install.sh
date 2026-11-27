#!/data/data/com.termux/files/usr/bin/bash
# claude-termux: run the official Claude Code linux-arm64 build natively in Termux.
#
# Claude Code has no Android build (the npm installer knows the platform key
# "linux-arm64-android", but that package is not published), and Termux uses
# bionic, so the official glibc binary can't start as-is. This installs:
#   - Termux's glibc userland (glibc-repo -> glibc), no proot
#   - the official @anthropic-ai/claude-code-linux-arm64 binary, ELF interpreter
#     and rpath patched to $PREFIX/glibc (so /proc/self/exe stays the binary)
#   - $PREFIX/bin/claude           wrapper (drops bionic LD_PRELOAD, routes updates)
#   - $PREFIX/bin/claude-termux-update  download/verify/patch/switch versions
#   - a bash shim for the Bash tool that restores termux-exec for child commands
#
# Usage: bash install.sh [version|latest|stable]
set -euo pipefail

if [[ "${PREFIX:-}" != /data/data/com.termux/files/usr ]]; then
	echo "claude-termux: run this inside Termux" >&2
	exit 1
fi
if [[ "$(uname -m)" != aarch64 ]]; then
	echo "claude-termux: only aarch64 is supported (got $(uname -m))" >&2
	exit 1
fi

ROOT="$HOME/.local/share/claude-native"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> installing dependencies"
export DEBIAN_FRONTEND=noninteractive
if ! dpkg -s glibc-repo >/dev/null 2>&1; then
	apt-get install -y glibc-repo
	apt-get update
fi
apt-get install -y glibc patchelf curl jq

echo "==> installing wrapper, updater and shell shim"
install -d "$ROOT/shim"
install -m 0755 "$HERE/claude" "$PREFIX/bin/claude"
install -m 0755 "$HERE/claude-termux-update" "$PREFIX/bin/claude-termux-update"
install -m 0755 "$HERE/shim-bash" "$ROOT/shim/bash"

"$PREFIX/bin/claude-termux-update" "${1:-latest}"

echo
echo "Done. Run: claude"
echo "First run: sign in with /login (open the URL in the phone browser, paste the code back)."
