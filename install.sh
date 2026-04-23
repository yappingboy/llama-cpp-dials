#!/usr/bin/env bash
# Install or upgrade the llama-cpp-dials plasmoid.
# Uses remove + install (not --upgrade) to guarantee fresh code is loaded.
set -euo pipefail

ID="org.kde.plasma.llamacppdials"
PKG="$(cd "$(dirname "$0")" && pwd)/package"

if command -v kpackagetool6 &>/dev/null; then
    TOOL=kpackagetool6
elif command -v kpackagetool5 &>/dev/null; then
    TOOL=kpackagetool5
else
    echo "Error: kpackagetool6 (or kpackagetool5) not found." >&2
    exit 1
fi

echo "Removing old installation (if any)…"
$TOOL --type Plasma/Applet --remove "$ID" 2>/dev/null || true

echo "Installing fresh package…"
$TOOL --type Plasma/Applet --install "$PKG"

echo ""
echo "────────────────────────────────────────────────"
echo "Done.  To load the new code:"
echo "  1. Right-click the widget on your desktop → Remove Widget"
echo "  2. Right-click desktop → Add Widgets → search 'llama-cpp Dials'"
echo "  OR restart Plasma: kquitapp6 plasmashell && kstart6 plasmashell"
echo "────────────────────────────────────────────────"
echo ""
echo "Quick test (no install needed):"
echo "  plasmoidviewer -a $PKG"
echo ""
echo "Note: llama.cpp server must be started with --metrics:"
echo "  ./llama-server --metrics -m model.gguf"
