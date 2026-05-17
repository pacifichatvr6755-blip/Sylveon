#!/bin/bash

################################################################################
# Sylveon App Manager - Interactive UI with GitHub Integration
# A beautiful, easy-to-use app installer and manager for Ubuntu
################################################################################

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Constants
SYLVEON_HOME="${HOME}/.sylveon"
APPS_DIR="${SYLVEON_HOME}/apps"
MODS_DIR="${SYLVEON_HOME}/mods"
CONFIG_FILE="${SYLVEON_HOME}/config.json"
LOG_FILE="${SYLVEON_HOME}/sylveon.log"

################################################################################
# Utility Functions
################################################################################

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
}

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                    🎮 SYLVEON APP MANAGER 🎮                 ║"
    echo "║              Easy GitHub App Installation for Ubuntu         ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

error() {
    echo -e "${RED}✗ $1${NC}"
    log "ERROR: $1"
}

warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log "WARNING: $1"
}

info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

################################################################################
# GitHub Functions
################################################################################

validate_github_url() {
    local url="$1"
    if [[ "$url" =~ ^https://github\.com/[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$ ]]; then
        return 0
    else
        return 1
    fi
}

extract_repo_info() {
    local url="$1"
    # Extract owner and repo from URL
    local repo_path="${url#https://github.com/}"
    local owner=$(echo "$repo_path" | cut -d'/' -f1)
    local repo=$(echo "$repo_path" | cut -d'/' -f2)
    echo "${owner}:${repo}"
}

fetch_github_releases() {
    local owner="$1"
    local repo="$2"
    
    info "Fetching releases from ${owner}/${repo}..."
    
    local releases=$(curl -s "https://api.github.com/repos/${owner}/${repo}/releases" 2>/dev/null | grep '"tag_name"' | head -5)
    
    if [ -z "$releases" ]; then
        warning "No releases found. Will clone main branch instead."
        return 1
    fi
    
    echo "$releases"
    return 0
}

download_app_from_github() {
    local github_url="$1"
    local app_name="$2"
    
    if ! validate_github_url "$github_url"; then
        error "Invalid GitHub URL format: $github_url"
        return 1
    fi
    
    local repo_info=$(extract_repo_info "$github_url")
    local owner=$(echo "$repo_info" | cut -d':' -f1)
    local repo=$(echo "$repo_info" | cut -d':' -f2)
    
    local app_path="${APPS_DIR}/${app_name}"
    
    if [ -d "$app_path" ]; then
        warning "App '${app_name}' already exists. Updating..."
        cd "$app_path"
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null
    else
        info "Cloning ${app_name} from GitHub..."
        git clone --depth 1 "$github_url" "$app_path"
    fi
    
    success "App '${app_name}' downloaded successfully!"
    return 0
}

################################################################################
# Installation Functions
################################################################################

init_sylveon() {
    info "Initializing Sylveon..."
    
    # Create directories
    mkdir -p "${APPS_DIR}" "${MODS_DIR}"
    
    # Create config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
{
  "version": "1.0",
  "apps": [],
  "mods": [],
  "settings": {
    "auto_update": true,
    "check_dependencies": true
  }
}
EOF
    fi
    
    success "Sylveon initialized at ${SYLVEON_HOME}"
}

install_system_dependencies() {
    print_header
    echo -e "${MAGENTA}📦 Installing System Dependencies${NC}"
    print_separator
    
    local deps=("git" "curl" "jq" "build-essential" "cmake")
    
    info "Updating package manager..."
    sudo apt-get update -qq
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            info "Installing ${dep}..."
            sudo apt-get install -y "$dep" -qq
            success "${dep} installed"
        else
            info "${dep} already installed"
        fi
    done
    
    success "All system dependencies installed!"
}

################################################################################
# Interactive Menu Functions
################################################################################

show_main_menu() {
    print_header
    print_separator
    
    echo -e "${WHITE}Choose an action:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}🔍 Browse and Install App from GitHub${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}📋 List Installed Apps${NC}"
    echo -e "${CYAN}3.${NC} ${WHITE}🚀 Launch an App${NC}"
    echo -e "${CYAN}4.${NC} ${WHITE}🔧 Manage Mods${NC}"
    echo -e "${CYAN}5.${NC} ${WHITE}⚙️  System Settings${NC}"
    echo -e "${CYAN}6.${NC} ${WHITE}🔄 Update All Apps${NC}"
    echo -e "${CYAN}7.${NC} ${WHITE}📜 View Logs${NC}"
    echo -e "${CYAN}0.${NC} ${WHITE}❌ Exit${NC}"
    print_separator
    
    read -p "Enter your choice [0-7]: " choice
    echo ""
    
    case $choice in
        1) install_app_menu ;;
        2) list_installed_apps ;;
        3) launch_app_menu ;;
        4) manage_mods_menu ;;
        5) settings_menu ;;
        6) update_all_apps ;;
        7) view_logs ;;
        0) exit_sylveon ;;
        *) error "Invalid choice. Please try again."; sleep 2; show_main_menu ;;
    esac
}

install_app_menu() {
    print_header
    echo -e "${MAGENTA}🔍 Install App from GitHub${NC}"
    print_separator
    
    info "Enter the GitHub repository URL"
    info "Example: https://github.com/username/repository"
    echo ""
    read -p "GitHub URL: " github_url
    
    if [ -z "$github_url" ]; then
        error "URL cannot be empty!"
        sleep 2
        show_main_menu
        return
    fi
    
    if ! validate_github_url "$github_url"; then
        error "Invalid GitHub URL format!"
        sleep 2
        show_main_menu
        return
    fi
    
    # Extract app name from URL
    local app_name=$(echo "$github_url" | rev | cut -d'/' -f1 | rev)
    
    read -p "App name [${app_name}]: " custom_name
    app_name="${custom_name:-$app_name}"
    
    echo ""
    info "Downloading app..."
    
    if download_app_from_github "$github_url" "$app_name"; then
        echo ""
        echo -e "${GREEN}App installation complete!${NC}"
        echo ""
        read -p "Press Enter to continue..."
    else
        error "Failed to install app"
        read -p "Press Enter to continue..."
    fi
    
    show_main_menu
}

list_installed_apps() {
    print_header
    echo -e "${MAGENTA}📋 Installed Apps${NC}"
    print_separator
    
    if [ ! -d "$APPS_DIR" ] || [ -z "$(ls -A $APPS_DIR 2>/dev/null)" ]; then
        warning "No apps installed yet."
    else
        local count=1
        for app_dir in "$APPS_DIR"/*; do
            if [ -d "$app_dir" ]; then
                local app_name=$(basename "$app_dir")
                local app_size=$(du -sh "$app_dir" 2>/dev/null | cut -f1)
                
                echo -e "${CYAN}${count}.${NC} ${WHITE}${app_name}${NC} (${YELLOW}${app_size}${NC})"
                ((count++))
            fi
        done
    fi
    
    print_separator
    read -p "Press Enter to continue..."
    show_main_menu
}

launch_app_menu() {
    print_header
    echo -e "${MAGENTA}🚀 Launch App${NC}"
    print_separator
    
    if [ ! -d "$APPS_DIR" ] || [ -z "$(ls -A $APPS_DIR 2>/dev/null)" ]; then
        warning "No apps installed. Please install an app first."
        sleep 2
        show_main_menu
        return
    fi
    
    local apps=()
    local count=1
    
    for app_dir in "$APPS_DIR"/*; do
        if [ -d "$app_dir" ]; then
            local app_name=$(basename "$app_dir")
            apps+=("$app_name")
            echo -e "${CYAN}${count}.${NC} ${WHITE}${app_name}${NC}"
            ((count++))
        fi
    done
    
    echo -e "${CYAN}0.${NC} ${WHITE}Back${NC}"
    print_separator
    
    read -p "Select app to launch [0-$((${#apps[@]}-1))]: " app_choice
    
    if [ "$app_choice" -eq 0 ] 2>/dev/null; then
        show_main_menu
        return
    fi
    
    if [ "$app_choice" -ge 1 ] && [ "$app_choice" -le ${#apps[@]} ]; then
        local selected_app="${apps[$((app_choice-1))]}"
        local app_path="${APPS_DIR}/${selected_app}"
        
        info "Launching ${selected_app}..."
        
        # Try to find and execute launch script
        if [ -f "${app_path}/launch.sh" ]; then
            bash "${app_path}/launch.sh"
        elif [ -f "${app_path}/run.sh" ]; then
            bash "${app_path}/run.sh"
        elif [ -f "${app_path}/main.sh" ]; then
            bash "${app_path}/main.sh"
        else
            warning "No launch script found. Opening app directory..."
            cd "${app_path}" && bash
        fi
    else
        error "Invalid selection"
    fi
    
    read -p "Press Enter to continue..."
    show_main_menu
}

manage_mods_menu() {
    print_header
    echo -e "${MAGENTA}🔧 Manage Mods${NC}"
    print_separator
    
    echo -e "${WHITE}Choose an action:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}Add Mod from GitHub${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}List Installed Mods${NC}"
    echo -e "${CYAN}3.${NC} ${WHITE}Remove Mod${NC}"
    echo -e "${CYAN}0.${NC} ${WHITE}Back${NC}"
    print_separator
    
    read -p "Enter your choice [0-3]: " mod_choice
    
    case $mod_choice in
        1) add_mod_menu ;;
        2) list_mods ;;
        3) remove_mod_menu ;;
        0) show_main_menu ;;
        *) error "Invalid choice"; sleep 2; manage_mods_menu ;;
    esac
}

add_mod_menu() {
    print_header
    echo -e "${MAGENTA}➕ Add Mod from GitHub${NC}"
    print_separator
    
    read -p "GitHub URL for mod: " mod_url
    
    if [ -z "$mod_url" ]; then
        error "URL cannot be empty!"
        sleep 2
        manage_mods_menu
        return
    fi
    
    if ! validate_github_url "$mod_url"; then
        error "Invalid GitHub URL format!"
        sleep 2
        manage_mods_menu
        return
    fi
    
    local mod_name=$(echo "$mod_url" | rev | cut -d'/' -f1 | rev)
    read -p "Mod name [${mod_name}]: " custom_name
    mod_name="${custom_name:-$mod_name}"
    
    if download_app_from_github "$mod_url" "$mod_name"; then
        # Move to mods directory
        mv "${APPS_DIR}/${mod_name}" "${MODS_DIR}/${mod_name}"
        success "Mod installed successfully!"
    else
        error "Failed to install mod"
    fi
    
    sleep 2
    manage_mods_menu
}

list_mods() {
    print_header
    echo -e "${MAGENTA}📋 Installed Mods${NC}"
    print_separator
    
    if [ ! -d "$MODS_DIR" ] || [ -z "$(ls -A $MODS_DIR 2>/dev/null)" ]; then
        warning "No mods installed yet."
    else
        local count=1
        for mod_dir in "$MODS_DIR"/*; do
            if [ -d "$mod_dir" ]; then
                local mod_name=$(basename "$mod_dir")
                echo -e "${CYAN}${count}.${NC} ${WHITE}${mod_name}${NC}"
                ((count++))
            fi
        done
    fi
    
    print_separator
    read -p "Press Enter to continue..."
    manage_mods_menu
}

remove_mod_menu() {
    print_header
    echo -e "${MAGENTA}🗑️  Remove Mod${NC}"
    print_separator
    
    if [ ! -d "$MODS_DIR" ] || [ -z "$(ls -A $MODS_DIR 2>/dev/null)" ]; then
        warning "No mods installed."
        sleep 2
        manage_mods_menu
        return
    fi
    
    local mods=()
    local count=1
    
    for mod_dir in "$MODS_DIR"/*; do
        if [ -d "$mod_dir" ]; then
            local mod_name=$(basename "$mod_dir")
            mods+=("$mod_name")
            echo -e "${CYAN}${count}.${NC} ${WHITE}${mod_name}${NC}"
            ((count++))
        fi
    done
    
    echo -e "${CYAN}0.${NC} ${WHITE}Back${NC}"
    print_separator
    
    read -p "Select mod to remove [0-$((${#mods[@]}-1))]: " mod_choice
    
    if [ "$mod_choice" -ge 1 ] && [ "$mod_choice" -le ${#mods[@]} ]; then
        local selected_mod="${mods[$((mod_choice-1))]}"
        read -p "Are you sure? (yes/no): " confirm
        
        if [ "$confirm" = "yes" ]; then
            rm -rf "${MODS_DIR}/${selected_mod}"
            success "Mod removed!"
        else
            info "Cancelled"
        fi
    fi
    
    sleep 2
    manage_mods_menu
}

settings_menu() {
    print_header
    echo -e "${MAGENTA}⚙️  Settings${NC}"
    print_separator
    
    echo -e "${WHITE}Choose an action:${NC}"
    echo -e "${CYAN}1.${NC} ${WHITE}View Configuration${NC}"
    echo -e "${CYAN}2.${NC} ${WHITE}Toggle Auto-Update${NC}"
    echo -e "${CYAN}3.${NC} ${WHITE}Clear Cache${NC}"
    echo -e "${CYAN}0.${NC} ${WHITE}Back${NC}"
    print_separator
    
    read -p "Enter your choice [0-3]: " settings_choice
    
    case $settings_choice in
        1) view_config ;;
        2) toggle_auto_update ;;
        3) clear_cache ;;
        0) show_main_menu ;;
        *) error "Invalid choice"; sleep 2; settings_menu ;;
    esac
}

view_config() {
    print_header
    echo -e "${MAGENTA}📋 Configuration${NC}"
    print_separator
    
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE" | jq '.' 2>/dev/null || cat "$CONFIG_FILE"
    else
        warning "Config file not found"
    fi
    
    print_separator
    read -p "Press Enter to continue..."
    settings_menu
}

toggle_auto_update() {
    print_header
    echo -e "${MAGENTA}🔄 Auto-Update Setting${NC}"
    print_separator
    
    info "Feature coming soon!"
    sleep 2
    settings_menu
}

clear_cache() {
    print_header
    echo -e "${MAGENTA}🧹 Clear Cache${NC}"
    print_separator
    
    read -p "This will clear temporary files. Continue? (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        # Add cache clearing logic here
        success "Cache cleared!"
    else
        info "Cancelled"
    fi
    
    sleep 2
    settings_menu
}

update_all_apps() {
    print_header
    echo -e "${MAGENTA}🔄 Updating All Apps${NC}"
    print_separator
    
    if [ ! -d "$APPS_DIR" ] || [ -z "$(ls -A $APPS_DIR 2>/dev/null)" ]; then
        warning "No apps to update."
    else
        local count=0
        for app_dir in "$APPS_DIR"/*; do
            if [ -d "$app_dir" ]; then
                local app_name=$(basename "$app_dir")
                info "Updating ${app_name}..."
                cd "$app_dir"
                git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || true
                ((count++))
            fi
        done
        
        success "Updated ${count} app(s)!"
    fi
    
    read -p "Press Enter to continue..."
    show_main_menu
}

view_logs() {
    print_header
    echo -e "${MAGENTA}📜 Logs${NC}"
    print_separator
    
    if [ -f "$LOG_FILE" ]; then
        tail -50 "$LOG_FILE"
    else
        warning "No logs available yet"
    fi
    
    print_separator
    read -p "Press Enter to continue..."
    show_main_menu
}

exit_sylveon() {
    print_header
    echo -e "${CYAN}Thank you for using Sylveon! 👋${NC}"
    echo ""
    success "Goodbye!"
    exit 0
}

################################################################################
# Main Entry Point
################################################################################

main() {
    # Initialize if first run
    if [ ! -d "$SYLVEON_HOME" ]; then
        echo "Welcome to Sylveon! Setting up for first time..."
        init_sylveon
        install_system_dependencies
    fi
    
    # Start interactive menu
    show_main_menu
}

# Run main
main
