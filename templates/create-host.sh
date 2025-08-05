#!/usr/bin/env bash

# NixOS Host Creation Script
# This script helps create a new host from templates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTS_DIR="$(dirname "$SCRIPT_DIR")/hosts"
TEMPLATES_DIR="$SCRIPT_DIR/hosts"
FLAKE_FILE="$(dirname "$SCRIPT_DIR")/flake.nix"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_question() {
    echo -e "${PURPLE}[QUESTION]${NC} $1"
}

# Show usage information
show_usage() {
    echo -e "${CYAN}NixOS Host Creation Script${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -l, --list          List available templates"
    echo "  -t, --template      Specify template (workstation, server, laptop)"
    echo "  -n, --name          Specify hostname"
    echo "  -u, --user          Specify username"
    echo "  -g, --gpu           Specify GPU type (amd, nvidia, intel, none)"
    echo "  --interactive       Interactive mode (default)"
    echo "  --non-interactive   Non-interactive mode (requires all options)"
    echo ""
    echo "Examples:"
    echo "  $0 --interactive"
    echo "  $0 -t workstation -n myhost -u myuser -g nvidia"
    echo "  $0 --list"
}

# List available templates
list_templates() {
    echo -e "${CYAN}Available Templates:${NC}"
    echo ""
    
    for template_dir in "$TEMPLATES_DIR"/*; do
        if [[ -d "$template_dir" ]]; then
            template_name=$(basename "$template_dir")
            readme_file="$template_dir/README.md"
            
            echo -e "${GREEN}$template_name${NC}"
            
            if [[ -f "$readme_file" ]]; then
                # Extract first line of description from README
                description=$(grep -m 1 "^[A-Za-z]" "$readme_file" | head -1)
                echo "  $description"
            fi
            echo ""
        fi
    done
}

# Validate inputs
validate_hostname() {
    local hostname="$1"
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9-]+$ ]]; then
        log_error "Invalid hostname. Use only letters, numbers, and hyphens."
        return 1
    fi
    if [[ ${#hostname} -gt 63 ]]; then
        log_error "Hostname too long. Maximum 63 characters."
        return 1
    fi
    return 0
}

validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then
        log_error "Invalid username. Use lowercase letters, numbers, underscore, and hyphen."
        return 1
    fi
    return 0
}

validate_template() {
    local template="$1"
    if [[ ! -d "$TEMPLATES_DIR/$template" ]]; then
        log_error "Template '$template' not found."
        log_info "Available templates:"
        list_templates
        return 1
    fi
    return 0
}

validate_gpu() {
    local gpu="$1"
    case "$gpu" in
        amd|nvidia|intel|none)
            return 0
            ;;
        *)
            log_error "Invalid GPU type. Use: amd, nvidia, intel, or none"
            return 1
            ;;
    esac
}

# Check if host already exists
check_host_exists() {
    local hostname="$1"
    if [[ -d "$HOSTS_DIR/$hostname" ]]; then
        log_error "Host '$hostname' already exists in $HOSTS_DIR"
        return 1
    fi
    return 0
}

# Interactive mode functions
prompt_template() {
    echo -e "${CYAN}Available Templates:${NC}"
    echo "1) workstation - Full desktop with development tools"
    echo "2) server      - Headless server configuration"
    echo "3) laptop      - Mobile-optimized configuration"
    echo ""
    
    while true; do
        read -p "Select template (1-3): " choice
        case $choice in
            1) echo "workstation"; return 0 ;;
            2) echo "server"; return 0 ;;
            3) echo "laptop"; return 0 ;;
            *) log_error "Invalid choice. Please select 1, 2, or 3." ;;
        esac
    done
}

prompt_hostname() {
    while true; do
        read -p "Enter hostname: " hostname
        if validate_hostname "$hostname" && check_host_exists "$hostname"; then
            echo "$hostname"
            return 0
        fi
    done
}

prompt_username() {
    while true; do
        read -p "Enter username: " username
        if validate_username "$username"; then
            echo "$username"
            return 0
        fi
    done
}

prompt_gpu() {
    echo -e "${CYAN}GPU Types:${NC}"
    echo "1) amd    - AMD GPUs with ROCm support"
    echo "2) nvidia - NVIDIA GPUs with CUDA support"
    echo "3) intel  - Intel integrated graphics"
    echo "4) none   - Headless/no GPU configuration"
    echo ""
    
    while true; do
        read -p "Select GPU type (1-4): " choice
        case $choice in
            1) echo "amd"; return 0 ;;
            2) echo "nvidia"; return 0 ;;
            3) echo "intel"; return 0 ;;
            4) echo "none"; return 0 ;;
            *) log_error "Invalid choice. Please select 1, 2, 3, or 4." ;;
        esac
    done
}

prompt_additional_info() {
    local hostname="$1"
    local template="$2"
    local gpu="$3"
    
    echo ""
    log_info "Additional configuration:"
    
    read -p "Full name (for git config): " fullname
    read -p "Email address: " email
    read -p "GitHub username (optional): " github_username
    read -p "Timezone (e.g., Europe/London): " timezone
    read -p "Locale (e.g., en_GB.UTF-8): " locale
    
    # Set defaults if empty
    fullname=${fullname:-"User Name"}
    email=${email:-"user@example.com"}
    github_username=${github_username:-"username"}
    timezone=${timezone:-"UTC"}
    locale=${locale:-"en_US.UTF-8"}
    
    echo "$fullname|$email|$github_username|$timezone|$locale"
}

# File manipulation functions
copy_template() {
    local template="$1"
    local hostname="$2"
    
    log_info "Copying template '$template' to '$hostname'..."
    
    cp -r "$TEMPLATES_DIR/$template" "$HOSTS_DIR/$hostname"
    
    log_success "Template copied successfully"
}

customize_variables() {
    local hostname="$1"
    local username="$2"
    local gpu="$3"
    local template="$4"
    local additional_info="$5"
    
    local variables_file="$HOSTS_DIR/$hostname/variables.nix"
    
    log_info "Customizing variables.nix..."
    
    # Parse additional info
    IFS='|' read -r fullname email github_username timezone locale <<< "$additional_info"
    
    # Determine acceleration type
    local acceleration="none"
    case "$gpu" in
        amd) acceleration="rocm" ;;
        nvidia) acceleration="cuda" ;;
        intel|none) acceleration="none" ;;
    esac
    
    # Replace placeholders in variables.nix
    sed -i "s/USERNAME/$username/g" "$variables_file"
    sed -i "s/HOSTNAME/$hostname/g" "$variables_file"
    sed -i "s/FULL NAME/$fullname/g" "$variables_file"
    sed -i "s/GITHUB_USERNAME/$github_username/g" "$variables_file"
    sed -i "s/user@example.com/$email/g" "$variables_file"
    sed -i "s/Europe\/London/$timezone/g" "$variables_file"
    sed -i "s/en_GB.UTF-8/$locale/g" "$variables_file"
    sed -i "s/gpu = \"nvidia\"/gpu = \"$gpu\"/g" "$variables_file"
    sed -i "s/acceleration = \"cuda\"/acceleration = \"$acceleration\"/g" "$variables_file"
    
    # Update host mappings
    sed -i "s/\"192.168.1.100\" = \"HOSTNAME\"/\"192.168.1.100\" = \"$hostname\"/g" "$variables_file"
    
    # Update paths
    sed -i "s|/home/USERNAME|/home/$username|g" "$variables_file"
    
    log_success "Variables customized successfully"
}

generate_hardware_config() {
    local hostname="$1"
    
    log_info "Generating hardware configuration..."
    
    local hardware_file="$HOSTS_DIR/$hostname/nixos/hardware-configuration.nix"
    
    if command -v nixos-generate-config >/dev/null 2>&1; then
        nixos-generate-config --show-hardware-config > "$hardware_file"
        log_success "Hardware configuration generated"
    else
        log_warning "nixos-generate-config not found. You'll need to generate hardware-configuration.nix manually."
        log_info "Run: nixos-generate-config --show-hardware-config > $hardware_file"
    fi
}

update_flake() {
    local hostname="$1"
    local username="$2"
    local template="$3"
    
    log_info "Instructions for updating flake.nix:"
    echo ""
    echo -e "${YELLOW}Add the following to your flake.nix nixosConfigurations:${NC}"
    echo ""
    echo "    $hostname = lib.nixosSystem {"
    echo "      inherit system;"
    echo "      specialArgs = {"
    echo "        inherit inputs system;"
    echo "        hostUsers = [ \"$username\" ];"
    echo "      };"
    echo "      modules = ["
    echo "        ./hosts/$hostname/configuration.nix"
    echo "        home-manager.nixosModules.home-manager"
    echo "        {"
    echo "          home-manager.useGlobalPkgs = true;"
    echo "          home-manager.useUserPackages = true;"
    echo "          home-manager.users.$username = import ./Users/$username/${hostname}_home.nix;"
    echo "        }"
    echo "        agenix.nixosModules.default"
    echo "      ];"
    echo "    };"
    echo ""
    echo -e "${YELLOW}Then create the home-manager configuration:${NC}"
    echo "mkdir -p Users/$username"
    echo "cp Users/olafkfreund/p620_home.nix Users/$username/${hostname}_home.nix"
    echo ""
}

# Main execution
main() {
    local template=""
    local hostname=""
    local username=""
    local gpu=""
    local interactive=true
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -l|--list)
                list_templates
                exit 0
                ;;
            -t|--template)
                template="$2"
                shift 2
                ;;
            -n|--name)
                hostname="$2"
                shift 2
                ;;
            -u|--user)
                username="$2"
                shift 2
                ;;
            -g|--gpu)
                gpu="$2"
                shift 2
                ;;
            --interactive)
                interactive=true
                shift
                ;;
            --non-interactive)
                interactive=false
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Interactive mode
    if [[ "$interactive" == true ]]; then
        echo -e "${CYAN}NixOS Host Creation Script${NC}"
        echo ""
        
        if [[ -z "$template" ]]; then
            template=$(prompt_template)
        fi
        
        if [[ -z "$hostname" ]]; then
            hostname=$(prompt_hostname)
        fi
        
        if [[ -z "$username" ]]; then
            username=$(prompt_username)
        fi
        
        if [[ -z "$gpu" ]]; then
            gpu=$(prompt_gpu)
        fi
        
        additional_info=$(prompt_additional_info "$hostname" "$template" "$gpu")
    else
        # Non-interactive mode - validate all required parameters
        if [[ -z "$template" ]] || [[ -z "$hostname" ]] || [[ -z "$username" ]] || [[ -z "$gpu" ]]; then
            log_error "Non-interactive mode requires all parameters: --template, --name, --user, --gpu"
            show_usage
            exit 1
        fi
        
        additional_info="User Name|user@example.com|username|UTC|en_US.UTF-8"
    fi
    
    # Validate inputs
    validate_template "$template" || exit 1
    validate_hostname "$hostname" || exit 1
    validate_username "$username" || exit 1
    validate_gpu "$gpu" || exit 1
    check_host_exists "$hostname" || exit 1
    
    # Show summary
    echo ""
    log_info "Creating host with the following configuration:"
    echo "  Template: $template"
    echo "  Hostname: $hostname"
    echo "  Username: $username"
    echo "  GPU Type: $gpu"
    echo ""
    
    if [[ "$interactive" == true ]]; then
        read -p "Proceed with host creation? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Host creation cancelled"
            exit 0
        fi
    fi
    
    # Create the host
    copy_template "$template" "$hostname"
    customize_variables "$hostname" "$username" "$gpu" "$template" "$additional_info"
    generate_hardware_config "$hostname"
    
    log_success "Host '$hostname' created successfully!"
    echo ""
    
    update_flake "$hostname" "$username" "$template"
    
    echo ""
    log_info "Next steps:"
    echo "1. Update flake.nix as shown above"  
    echo "2. Test the configuration: just test-host $hostname"
    echo "3. Deploy: just $hostname"
    echo ""
    log_success "Host creation complete!"
}

# Run main function
main "$@"