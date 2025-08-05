#!/bin/bash


# VS Code settings path
VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


# Function to backup current settings
backup_settings() {
if [ -f "$VSCODE_SETTINGS" ]; then
cp "$VSCODE_SETTINGS" "$VSCODE_SETTINGS.backup"
echo "📦 Current settings backed up"
fi
}


# Function to switch to auto mode
switch_to_auto() {
backup_settings
cp "$SCRIPT_DIR/auto-settings.json" "$VSCODE_SETTINGS"
echo "✅ Auto Mode aktiviert"
echo "🔄 Auto-repeat prompts enabled"
echo "🤖 Auto-suggestions and auto-fixes active"
echo "⚡ 50 requests per session with 15s auto-accept"
}


# Function to switch to normal mode
switch_to_normal() {
backup_settings
cp "$SCRIPT_DIR/normal-settings.json" "$VSCODE_SETTINGS"
echo "✅ Normal Mode aktiviert"
echo "🔧 Basic Copilot features only"
echo "❌ Auto-repeat disabled"
}


# Main logic
case "$1" in
"auto")
switch_to_auto
;;
"normal")
switch_to_normal
;;
*)
echo "Usage: $0 {auto|normal}"
echo " auto - Enable super automated mode with auto-repeat"
echo " normal - Enable basic mode without automation"
exit 1
;;
esac


echo ""
echo "🔄 Please restart VS Code for changes to take effect"