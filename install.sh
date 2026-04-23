#!/usr/bin/env bash
# Install or upgrade the llama-cpp-dials plasmoid.
set -euo pipefail

ID="org.kde.plasma.llamacppdials"
PKG="$(cd "$(dirname "$0")" && pwd)/package"

if command -v kpackagetool6 &>/dev/null; then
    TOOL=kpackagetool6
elif command -v kpackagetool5 &>/dev/null; then
    TOOL=kpackagetool5
else
    echo "Error: kpackagetool6 (or kpackagetool5) not found. Install plasma-framework." >&2
    exit 1
fi

echo "Using $TOOL"
if $TOOL --type Plasma/Applet --show "$ID" &>/dev/null; then
    echo "Upgrading existing installation…"
    $TOOL --type Plasma/Applet --upgrade "$PKG"
else
    echo "Installing new plasmoid…"
    $TOOL --type Plasma/Applet --install "$PKG"
fi

echo ""
echo "Done.  Add the widget via 'Add Widgets' (search for 'llama-cpp Dials')."
echo "Plasmoid ID: $ID"
echo ""
echo "Note: your llama.cpp server must be started with the --metrics flag:"
echo "  ./llama-server --metrics -m model.gguf ..."
