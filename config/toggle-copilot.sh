#!/bin/bash

# /*
# SYSTEM: This setup switches between a super-automated Copilot bughunt mode and normal Copilot mode in VS Code with a single script toggle. Edit auto-settings.json for more/fewer automations or prompts.  
# Run: ./toggle-copilot.sh auto  — enables fully-automated mode  
# Run: ./toggle-copilot.sh normal — resets to default/manual safety.  
# Restart VS Code after switching!
# */

# ==========================================
# VS CODE COPILOT MODE SWITCHER
# ==========================================
# This script toggles between automated bug-hunting mode and normal Copilot operation
# for systematic code analysis and bug detection across your entire codebase.

# Configuration
VSCODE_SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_feature() {
    echo -e "${PURPLE}🔧 $1${NC}"
}

# Function to validate required files exist
validate_files() {
    if [ ! -f "$SCRIPT_DIR/auto-settings.json" ]; then
        print_error "auto-settings.json not found in $SCRIPT_DIR"
        exit 1
    fi
    
    if [ ! -f "$SCRIPT_DIR/normal-settings.json" ]; then
        print_error "normal-settings.json not found in $SCRIPT_DIR"
        exit 1
    fi
}

# Function to backup current settings with timestamp
backup_settings() {
    if [ -f "$VSCODE_SETTINGS" ]; then
        local backup_file="$VSCODE_SETTINGS.backup_$TIMESTAMP"
        cp "$VSCODE_SETTINGS" "$backup_file"
        print_status "Current settings backed up to: $backup_file"
    else
        print_warning "No existing VS Code settings found - creating new settings file"
        # Create the directory if it doesn't exist
        mkdir -p "$(dirname "$VSCODE_SETTINGS")"
    fi
}

# Function to switch to automated bug-hunting mode
switch_to_auto() {
    echo -e "${CYAN}🤖 ACTIVATING SUPER AUTOMATED BUG-HUNTING MODE${NC}"
    echo "=================================================="
    
    backup_settings
    cp "$SCRIPT_DIR/auto-settings.json" "$VSCODE_SETTINGS"
    
    print_status "AUTO MODE ACTIVATED"
    echo ""
    print_feature "Auto-approval of tools and terminal commands"
    print_feature "Automatic iteration without user confirmation" 
    print_feature "Auto-submission and acceptance of suggestions"
    print_feature "Systematic bug-hunting with repeat prompts"
    print_feature "100 requests per session with expanded limits"
    print_feature "Continuous mode for deep code analysis"
    echo ""
    print_info "Use this prompt to start systematic bug hunting:"
    echo -e "${YELLOW}🐛 SYSTEMATIC BUG HUNT: Analyze ALL code for logical bugs and fix them immediately. Check: logic errors, state management, data flow, async operations, error handling, edge cases, performance issues. Work methodically through every code file, one at a time and systematically. Take your time. Continue iterating until completely bug-free. Fix, don't just report.${NC}"
}

# Function to switch to normal/safe mode
switch_to_normal() {
    echo -e "${CYAN}🛡️  ACTIVATING NORMAL SAFE MODE${NC}"
    echo "================================="
    
    backup_settings
    cp "$SCRIPT_DIR/normal-settings.json" "$VSCODE_SETTINGS"
    
    print_status "NORMAL MODE ACTIVATED"
    echo ""
    print_feature "Manual control over all Copilot features"
    print_feature "No auto-iteration or auto-approval"
    print_feature "Standard GitHub Copilot suggestions only"
    print_feature "User confirmation required for all actions"
    print_feature "Conservative limits (30 requests per session)"
    echo ""
    print_info "Safe, manual operation restored"
}

# Function to show current mode status
show_status() {
    echo -e "${CYAN}📊 CURRENT COPILOT CONFIGURATION STATUS${NC}"
    echo "========================================"
    
    if [ -f "$VSCODE_SETTINGS" ]; then
        # Check for automation indicators
        if grep -q "autoAcceptSuggestions.*true" "$VSCODE_SETTINGS" 2>/dev/null; then
            echo -e "${GREEN}🤖 AUTO MODE - Automated bug-hunting active${NC}"
        else
            echo -e "${BLUE}🛡️  NORMAL MODE - Manual operation active${NC}"
        fi
        
        echo ""
        print_info "Settings file: $VSCODE_SETTINGS"
        print_info "Last modified: $(stat -f "%Sm" "$VSCODE_SETTINGS" 2>/dev/null || echo "Unknown")"
        
        # Show backup files
        local backup_count=$(ls -1 "$VSCODE_SETTINGS".backup_* 2>/dev/null | wc -l)
        if [ $backup_count -gt 0 ]; then
            print_info "Available backups: $backup_count"
        fi
    else
        print_warning "No VS Code settings file found"
    fi
}

# Function to restore from backup
restore_backup() {
    echo -e "${CYAN}🔄 AVAILABLE BACKUPS${NC}"
    echo "==================="
    
    local backups=($(ls -t "$VSCODE_SETTINGS".backup_* 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        print_error "No backup files found"
        return 1
    fi
    
    echo "Select a backup to restore:"
    for i in "${!backups[@]}"; do
        local date=$(echo "${backups[$i]}" | sed 's/.*backup_//' | sed 's/_/ /')
        echo "$((i+1)). $date (${backups[$i]})"
    done
    
    read -p "Enter backup number (1-${#backups[@]}): " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#backups[@]} ]; then
        local selected_backup="${backups[$((choice-1))]}"
        cp "$selected_backup" "$VSCODE_SETTINGS"
        print_status "Restored backup: $selected_backup"
    else
        print_error "Invalid selection"
        return 1
    fi
}

# Validate environment
validate_files

# Main logic
case "$1" in
    "auto"|"automated"|"bug-hunt")
        switch_to_auto
        ;;
    "normal"|"safe"|"manual")
        switch_to_normal
        ;;
    "status"|"info"|"current")
        show_status
        exit 0
        ;;
    "restore"|"backup")
        restore_backup
        exit 0
        ;;
    "help"|"-h"|"--help")
        echo -e "${CYAN}VS CODE COPILOT MODE SWITCHER${NC}"
        echo "============================="
        echo ""
        echo "Usage: $0 {auto|normal|status|restore|help}"
        echo ""
        echo -e "${GREEN}Commands:${NC}"
        echo "  auto     - Enable super automated bug-hunting mode"
        echo "  normal   - Enable safe manual mode without automation"  
        echo "  status   - Show current configuration status"
        echo "  restore  - Restore from a previous backup"
        echo "  help     - Show this help message"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo "  ./toggle-copilot.sh auto     # Start automated bug hunting"
        echo "  ./toggle-copilot.sh normal   # Return to safe manual mode"
        echo "  ./toggle-copilot.sh status   # Check current mode"
        echo ""
        exit 0
        ;;
    *)
        print_error "Invalid option: $1"
        echo ""
        echo "Usage: $0 {auto|normal|status|restore|help}"
        echo "  auto     - Enable super automated mode with auto-repeat"
        echo "  normal   - Enable basic mode without automation"
        echo "  status   - Show current configuration status"
        echo "  restore  - Restore from backup"
        echo "  help     - Show detailed help"
        echo ""
        echo "Run '$0 help' for more details"
        exit 1
        ;;
esac

echo ""
echo -e "${YELLOW}🔄 Please restart VS Code for changes to take effect${NC}"
echo ""
print_info "Tip: Use '$0 status' to check current mode anytime"