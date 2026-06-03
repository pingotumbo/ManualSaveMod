#!/bin/bash
# =============================================================================
# Launcher for ManualSaveMod's Watcher on Linux, Steam Deck and macOS.
# =============================================================================
#
# WHY .command INSTEAD OF .sh
#   Steam Workshop's uploader blocks files with a .sh extension, so this
#   launcher ships as .command (native on macOS, treated as a regular bash
#   script on Linux). The script content is plain bash.
#
# FIRST-RUN SETUP
#   macOS:
#     Just double-click ManualSave_Watcher.command. Terminal.app opens
#     and runs the script; the Watcher starts. Leave the window open.
#     On a clean macOS install you may see a popup asking to download
#     the Command Line Developer Tools (~700 MB) the first time python3
#     is called. Click Install, wait, then re-run this launcher.
#
#   Linux / Steam Deck (Desktop Mode):
#     Open a terminal in this folder once and run:
#         chmod +x ManualSave_Watcher.command
#     (Or right-click > Properties > Permissions > Allow executing as program.)
#     From then on, double-click works.
#
#   Steam Deck (Gaming Mode):
#     Gaming Mode cannot double-click files directly. In Desktop Mode add
#     this script as a Non-Steam Game in Steam (Games > Add a Non-Steam
#     Game to my Library > Browse > pick ManualSave_Watcher.command).
#     Return to Gaming Mode and launch the Watcher from your Steam library
#     BEFORE launching Project Zomboid. Both must be running together.
# =============================================================================

cd "$(dirname "$0")"

# Find a usable Python 3. Prefer python3, fall back to python (some macOS
# Homebrew setups and old Linux distros only ship the unsuffixed name).
if command -v python3 >/dev/null 2>&1; then
    PY=python3
elif command -v python >/dev/null 2>&1; then
    PY=python
else
    echo ""
    echo "[ManualSaveMod] ERROR: Python 3 is not installed on this system."
    echo ""
    echo "  Linux (Debian/Ubuntu/Mint/SteamOS):  sudo apt install python3"
    echo "  Linux (Fedora):                      sudo dnf install python3"
    echo "  Linux (Arch/Manjaro):                sudo pacman -S python"
    echo "  macOS:                               install from python.org"
    echo "                                       or 'brew install python'"
    echo ""
    echo "After installation, re-run this launcher."
    read -p "Press Enter to close this window..."
    exit 1
fi

"$PY" ManualSave_Watcher.py "$@"
