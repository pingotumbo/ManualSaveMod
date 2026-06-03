#!/bin/bash
# Launcher for ManualSaveMod's Linux/Steam Deck watcher. Double-click to start.
# First time only: chmod +x ManualSave_Watcher.sh   (or set executable in file properties).
cd "$(dirname "$0")"
python3 ManualSave_Watcher.py "$@"
