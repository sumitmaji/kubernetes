#!/bin/bash

# GOK Exec Command Module - Remote VM Execution
# This module implements remote command execution on VMs via SSH

# Global variables for remote host configuration
declare -A REMOTE_HOSTS REMOTE_USERS REMOTE_KEYS REMOTE_SUDOS
DEFAULT_REMOTE_HOST=""
DEFAULT_REMOTE_USER=""  
DEFAULT_REMOTE_KEY=""
DEFAULT_REMOTE_SUDO=""

# Configuration file paths
REMOTE_CONFIG_DIR="${GOK_CONFIG_DIR:-${GOK_ROOT}/.config}"
REMOTE_CONFIG_FILE="${REMOTE_CONFIG_DIR}/remote-hosts"
DEFAULT_CONFIG_FILE="${REMOTE_CONFIG_DIR}/default-remote"

# Main exec command function
execCmd() {
    local action="${1:-}"
    
    # Load remote configuration
    load_remote_configuration
    
    case "$action" in
        --help|-h|help)
            show_exec_help
            ;;
        "")
            log_error "Missing command to execute"
            echo ""
            echo "Usage: gok-new exec <command>"
            echo "       gok-new exec <target> <command>"
            echo ""
            echo "Run 'gok-new exec --help' for detailed usage information"
            return 1
            ;;
        *)
            # Handle different execution patterns
            if [[ "$1" != *" "* ]] && [[ -n "$2" ]] && [[ "$1" != *":"* ]] && [[ "$1" =~ ^[a-zA-Z0-9._-]+$ ]]; then
                # Pattern: gok-new exec <target> <command>
                local target="$1"
                shift
                smart_remote_exec "$target" "$*"
            else
                # Pattern: gok-new exec "<command>"  
                simple_remote_exec "$*"
            fi
            ;;
    esac
}

# Show exec command help
show_exec_help() {
    log_header "GOK Remote Execution"
    
    echo "Execute commands on remote VMs via SSH"
    echo ""
    echo "Usage:"
    echo "  gok-new exec <command>                    # Execute on default remote host"
    echo "  gok-new exec <target> <command>           # Execute on specific target"
    echo ""
    echo "Simple usage (after setup):"
    echo "  gok-new exec \"kubectl get pods\"             # Use default remote host"
    echo "  gok-new exec \"docker ps\"                    # Use default remote host"
    echo "  gok-new exec \"systemctl status docker\"      # Use default remote host"
    echo ""
    echo "Advanced usage with targets:"
    echo "  gok-new exec master 'kubectl get nodes'      # Use configured alias"
    echo "  gok-new exec 10.0.0.244:sumit 'kubectl get pods'  # Auto-setup sumit@10.0.0.244"
    echo "  gok-new exec 192.168.1.100 'docker ps'       # Auto-setup root@192.168.1.100"
    echo "  gok-new exec all 'systemctl status docker'   # Execute on all configured hosts"
    echo ""
    echo "Setup commands:"
    echo "  gok-new remote setup <host> <user> [key_file] # Configure remote host"
    echo "  gok-new remote list                           # Show configured hosts"
    echo ""
    echo "Examples:"
    echo "  # First-time setup"
    echo "  gok-new remote setup 10.0.0.244 sumit"
    echo ""
    echo "  # Simple execution"
    echo "  gok-new exec \"kubectl get pods\""
    echo "  gok-new exec \"docker images\""
    echo ""
    echo "  # Target-specific execution"
    echo "  gok-new exec master \"kubectl get nodes\""
    echo "  gok-new exec worker1 \"docker ps\""
    echo ""
    echo "  # Auto-configuration"
    echo "  gok-new exec 192.168.1.100 \"ls -la\""
    echo "  gok-new exec server.example.com:ubuntu \"whoami\""
    echo ""
    echo "Notes:"
    echo "  • Commands are executed with sudo when needed (automatic detection)"
    echo "  • SSH keys are used for authentication (password-less login)"
    echo "  • MOUNT_PATH=/root is automatically set for gok commands"
    echo "  • Complex commands with pipes/redirections are wrapped properly"
}

# Load remote configuration from files
load_remote_configuration() {
    # Create config directory if it doesn't exist
    mkdir -p "$REMOTE_CONFIG_DIR"
    
    # Load remote hosts configuration
    if [[ -f "$REMOTE_CONFIG_FILE" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            
            # Parse configuration
            if [[ "$key" == "HOST_"* ]]; then
                local alias="${key#HOST_}"
                REMOTE_HOSTS["$alias"]="$value"
            elif [[ "$key" == "USER_"* ]]; then
                local alias="${key#USER_}"
                REMOTE_USERS["$alias"]="$value"
            elif [[ "$key" == "KEY_"* ]]; then
                local alias="${key#KEY_}"
                REMOTE_KEYS["$alias"]="$value"
            elif [[ "$key" == "SUDO_"* ]]; then
                local alias="${key#SUDO_}"
                REMOTE_SUDOS["$alias"]="$value"
            fi
        done < "$REMOTE_CONFIG_FILE"
    fi
    
    # Load default remote configuration
    if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        source "$DEFAULT_CONFIG_FILE"
    fi
}

# Load default remote configuration (for backward compatibility)
load_default_remote_config() {
    if [[ -f "$DEFAULT_CONFIG_FILE" ]]; then
        source "$DEFAULT_CONFIG_FILE"
        
        # Check if we have minimum required config
        if [[ -n "$DEFAULT_REMOTE_HOST" && -n "$DEFAULT_REMOTE_USER" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Simple remote execution using default configuration
simple_remote_exec() {
    local commands="$*"
    
    # Load default configuration
    if ! load_default_remote_config; then
        log_error "No default remote configuration found!"
        echo ""
        echo "Please set up your default remote host first:"
        echo "  gok-new remote setup <host> <user> [key_file]"
        echo ""
        echo "Example:"
        echo "  gok-new remote setup 10.0.0.244 sumit"
        return 1
    fi
    
    # Use stored sudo preference, fall back to environment variable, then default to auto
    local use_sudo="${DEFAULT_REMOTE_SUDO:-${GOK_REMOTE_SUDO:-auto}}"
    
    # Determine if sudo should be used and handle shell redirections
    local final_commands="$commands"
    
    # Automatically set MOUNT_PATH=/root for gok commands
    if [[ "$commands" == *"./gok"* ]] || [[ "$commands" == *"gok-new"* ]]; then
        final_commands="export MOUNT_PATH=/root && $commands"
    fi
    
    if [[ "$use_sudo" == "always" ]] || [[ "$use_sudo" == "auto" && $(needs_sudo "$final_commands") == "true" ]]; then
        if [[ "$final_commands" != sudo* ]]; then
            # Check if command contains shell redirections or pipes
            if [[ "$final_commands" == *">"* ]] || [[ "$final_commands" == *">>"* ]] || [[ "$final_commands" == *"|"* ]] || [[ "$final_commands" == *"&&"* ]] || [[ "$final_commands" == *"||"* ]]; then
                # Wrap complex commands in bash -c to ensure proper sudo context for redirections
                final_commands="sudo bash -c \"$final_commands\""
            else
                final_commands="sudo $final_commands"
            fi
        fi
    fi
    
    log_info "Executing on default remote ($DEFAULT_REMOTE_USER@$DEFAULT_REMOTE_HOST): $final_commands"
    
    # Execute command using SSH
    local ssh_options="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [[ -n "$DEFAULT_REMOTE_KEY" ]]; then
        ssh_options="$ssh_options -i $DEFAULT_REMOTE_KEY"
    fi
    
    ssh $ssh_options "$DEFAULT_REMOTE_USER@$DEFAULT_REMOTE_HOST" "$final_commands"
}

# Remote execution on specific configured host
remote_exec() {
    local alias="$1"
    shift
    local commands="$*"
    
    if [[ -z "${REMOTE_HOSTS[$alias]}" ]]; then
        log_error "Remote host '$alias' not configured"
        if [[ ${#REMOTE_HOSTS[@]} -gt 0 ]]; then
            log_info "Available hosts: ${!REMOTE_HOSTS[*]}"
        else
            log_info "No remote hosts configured. Use 'gok-new remote setup' to configure hosts."
        fi
        return 1
    fi
    
    local host="${REMOTE_HOSTS[$alias]}"
    local user="${REMOTE_USERS[$alias]}"
    local key_file="${REMOTE_KEYS[$alias]}"
    local use_sudo="${REMOTE_SUDOS[$alias]:-${GOK_REMOTE_SUDO:-auto}}"
    
    # Determine if sudo should be used and handle shell redirections
    local final_commands="$commands"
    
    # Automatically set MOUNT_PATH=/root for gok commands
    if [[ "$commands" == *"./gok"* ]] || [[ "$commands" == *"gok-new"* ]]; then
        final_commands="export MOUNT_PATH=/root && $commands"
    fi
    
    if [[ "$use_sudo" == "always" ]] || [[ "$use_sudo" == "auto" && $(needs_sudo "$final_commands") == "true" ]]; then
        if [[ "$final_commands" != sudo* ]]; then
            # Check if command contains shell redirections or pipes
            if [[ "$final_commands" == *">"* ]] || [[ "$final_commands" == *">>"* ]] || [[ "$final_commands" == *"|"* ]] || [[ "$final_commands" == *"&&"* ]] || [[ "$final_commands" == *"||"* ]]; then
                # Wrap complex commands in bash -c to ensure proper sudo context for redirections
                final_commands="sudo bash -c \"$final_commands\""
            else
                final_commands="sudo $final_commands"
            fi
        fi
    fi
    
    log_info "Executing on $alias ($user@$host): $final_commands"
    
    local ssh_options="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [[ -n "$key_file" ]]; then
        ssh_options="$ssh_options -i $key_file"
    fi
    
    ssh $ssh_options "$user@$host" "$final_commands"
}

# Execute command on multiple remote hosts
remote_exec_all() {
    local commands="$*"
    local failed_hosts=()
    
    log_info "Executing on all configured hosts: $commands"
    
    for alias in "${!REMOTE_HOSTS[@]}"; do
        echo
        log_info "Executing on $alias..."
        if ! remote_exec "$alias" "$commands"; then
            failed_hosts+=("$alias")
        fi
    done
    
    if [[ ${#failed_hosts[@]} -gt 0 ]]; then
        echo
        log_warning "Command failed on hosts: ${failed_hosts[*]}"
        return 1
    else
        echo
        log_success "Command executed successfully on all hosts"
        return 0
    fi
}

# Smart remote execution with auto-configuration
smart_remote_exec() {
    local target="$1"
    shift
    local commands="$*"
    
    # If target looks like host:user format, auto-configure it
    if [[ "$target" == *":"* ]]; then
        local host="${target%:*}"
        local user="${target#*:}"
        local alias="${host//\./_}_${user}"
        
        log_info "Auto-configuring new remote host: $user@$host as '$alias'"
        if auto_setup_remote_host "$host" "$user" "$alias"; then
            target="$alias"
        else
            log_error "Failed to auto-configure $user@$host"
            return 1
        fi
    fi
    
    # Check if target is configured, if not try to auto-configure as root@target
    if [[ -z "${REMOTE_HOSTS[$target]}" ]] && [[ "$target" != "all" ]]; then
        # If target looks like an IP or hostname, try to auto-configure it
        if [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [[ "$target" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            log_info "Auto-configuring new remote host: root@$target"
            if ! auto_setup_remote_host "$target" "root" "$target"; then
                log_error "Failed to auto-configure root@$target"
                return 1
            fi
        fi
    fi
    
    # Now execute the command using the standard remote_exec
    if [[ "$target" == "all" ]]; then
        remote_exec_all "$commands"
    else
        remote_exec "$target" "$commands"
    fi
}

# Auto-setup remote host configuration
auto_setup_remote_host() {
    local host="$1"
    local user="$2"
    local alias="$3"
    
    # Default SSH key
    local key_file="${HOME}/.ssh/id_rsa"
    
    # Test SSH connectivity
    if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$key_file" "$user@$host" "echo 'Connection test successful'" >/dev/null 2>&1; then
        log_error "Cannot connect to $user@$host"
        log_info "Please ensure:"
        log_info "  • Host is reachable"
        log_info "  • SSH key is configured"
        log_info "  • User has appropriate permissions"
        return 1
    fi
    
    # Store configuration
    REMOTE_HOSTS["$alias"]="$host"
    REMOTE_USERS["$alias"]="$user"
    REMOTE_KEYS["$alias"]="$key_file"
    REMOTE_SUDOS["$alias"]="auto"
    
    log_success "Auto-configured $alias -> $user@$host"
    return 0
}

# Check if command needs sudo
needs_sudo() {
    local command="$1"
    
    # Commands that typically need sudo
    local sudo_commands=(
        "systemctl" "service" "journalctl" "mount" "umount"
        "apt" "apt-get" "yum" "dnf" "zypper" "pacman"
        "docker" "kubectl" "kubeadm" "crictl"
        "iptables" "ip" "ifconfig" "netstat" "ss"
        "modprobe" "lsmod" "insmod" "rmmod"
        "fdisk" "parted" "mkfs" "fsck" "lsblk"
        "useradd" "userdel" "usermod" "groupadd" "passwd"
        "chown" "chmod" "chgrp" "setfacl" "getfacl"
        "crontab" "at" "batch"
        "nano" "vim" "vi" "emacs"
        "find" "locate" "updatedb"
        "dmesg" "lscpu" "lsusb" "lspci" "hwinfo"
        "./gok" "gok" "gok-new"
    )
    
    # Extract the first word (command) from the command string
    local first_command=$(echo "$command" | awk '{print $1}' | sed 's|.*/||')
    
    # Check if command is in sudo_commands list
    for sudo_cmd in "${sudo_commands[@]}"; do
        if [[ "$first_command" == "$sudo_cmd" ]]; then
            echo "true"
            return 0
        fi
    done
    
    # Check for file operations that might need sudo
    if [[ "$command" == *"/etc/"* ]] || [[ "$command" == *"/var/"* ]] || [[ "$command" == *"/usr/"* ]] || [[ "$command" == *"/opt/"* ]] || [[ "$command" == *"/sys/"* ]] || [[ "$command" == *"/proc/"* ]] || [[ "$command" == *"/root/"* ]]; then
        echo "true"
        return 0
    fi
    
    # Check if command already starts with sudo
    if [[ "$command" == sudo* ]]; then
        echo "false"
        return 1
    fi
    
    echo "false"
    return 1
}

# =============================================================================
# REMOTE COMMAND IMPLEMENTATION
# =============================================================================

# Main remote command dispatcher
remoteCmd() {
    local action="${1:-}"
    
    # Load remote configuration
    load_remote_configuration
    
    case "$action" in
        setup)
            remote_setup "${@:2}"
            ;;
        add)
            remote_add "${@:2}"
            ;;
        list|show)
            show_remote_hosts
            ;;
        exec)
            # This delegates to execCmd which we already implemented
            execCmd "${@:2}"
            ;;
        copy)
            remote_copy_cmd "${@:2}"
            ;;
        status)
            remote_status "${2:-all}"
            ;;
        install-gok)
            remote_install_gok "${2:-all}"
            ;;
        setup-ssh|setup-keys)
            setup_ssh_keys "${2:-$HOME/.ssh/id_rsa}"
            ;;
        copy-key)
            remote_copy_key "${@:2}"
            ;;
        setup-sudo|passwordless-sudo)
            remote_setup_sudo "${@:2}"
            ;;
        test-connection)
            remote_test_connection "${@:2}"
            ;;
        --help|-h|help)
            show_remote_help
            ;;
        "")
            show_remote_help
            ;;
        *)
            log_error "Unknown remote action: $action"
            echo "Run 'gok-new remote --help' for available actions"
            return 1
            ;;
    esac
}

# Setup default remote host with full configuration
remote_setup() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: gok-new remote setup <host> <user> [key_file] [sudo_mode]"
        echo ""
        echo "Set up default remote host with automatic SSH keys and sudo configuration."
        echo ""
        echo "Parameters:"
        echo "  host       - Remote host IP/hostname"
        echo "  user       - Username for SSH connection"  
        echo "  key_file   - SSH key file path (optional, default: ~/.ssh/id_rsa)"
        echo "  sudo_mode  - Sudo behavior: 'always', 'auto', 'never' (optional, will prompt if not provided)"
        echo ""
        echo "Examples:"
        echo "  gok-new remote setup 10.0.0.244 sumit                    # Interactive sudo setup"
        echo "  gok-new remote setup 192.168.1.100 ubuntu ~/.ssh/id_rsa always"
        echo "  gok-new remote setup 10.0.0.244 sumit ~/.ssh/id_rsa never"
        echo ""
        echo "After setup, you can simply use:"
        echo "  gok-new exec \"kubectl get pods\"                       # Uses configured settings"
        echo "  gok-new exec \"docker ps\"                             # Automatically adds sudo if needed"
        return 1
    fi
    
    local host="$1"
    local user="$2"
    local key_file="${3:-$HOME/.ssh/id_rsa}"
    local sudo_mode="$4"
    
    # If sudo_mode not provided, ask user interactively
    if [[ -z "$sudo_mode" ]]; then
        echo ""
        echo "🔐 Sudo Configuration for $user@$host"
        echo ""
        echo "How should commands be executed on the remote host?"
        echo "  1) always  - Always prepend 'sudo' to all commands (for non-root users)"
        echo "  2) auto    - Automatically detect when sudo is needed (recommended)"
        echo "  3) never   - Never use sudo (for root user or when not needed)"
        echo ""
        while true; do
            read -p "Choose sudo mode [1-3] (default: auto): " choice
            case $choice in
                1|always) sudo_mode="always"; break;;
                2|auto|"") sudo_mode="auto"; break;;
                3|never) sudo_mode="never"; break;;
                *) echo "Please choose 1, 2, or 3";;
            esac
        done
    fi
    
    log_info "Setting up default remote host: $user@$host (sudo: $sudo_mode)"
    
    # Setup SSH keys and access
    setup_ssh_keys "$key_file"
    copy_ssh_key "$host" "$user" "$key_file"
    if [ $? -ne 0 ]; then
        log_error "Failed to setup SSH access"
        return 1
    fi
    
    # Setup passwordless sudo if needed
    if [[ "$sudo_mode" == "always" ]] || [[ "$sudo_mode" == "auto" ]]; then
        log_info "Setting up passwordless sudo for root commands..."
        if ! setup_passwordless_sudo "$host" "$user" "$key_file"; then
            log_warning "Passwordless sudo setup failed"
            echo ""
            echo "You can retry passwordless sudo setup later with:"
            echo "  gok-new remote setup-sudo $host $user"
        fi
    fi
    
    # Save configuration as default with sudo preference
    save_default_remote_config "$host" "$user" "$key_file" "$sudo_mode"
    
    # Test the configuration
    log_info "Testing remote configuration..."
    if simple_remote_exec "echo 'Remote setup successful! Host:' \$(hostname) '| User:' \$(whoami)"; then
        log_success "Remote setup completed successfully!"
        echo ""
        echo "✅ You can now use:"
        echo "  gok-new exec \"any-command\"               # Executes with configured sudo settings"
        echo "  gok-new exec \"docker ps\"                 # Will use sudo if mode is 'always' or 'auto'"
        echo "  gok-new exec \"kubectl get pods\"          # Will use sudo if mode is 'always' or 'auto'"
        echo "  gok-new remote copy file.txt              # Copy files to remote host"
    else
        log_error "Setup test failed"
        return 1
    fi
}

# Add remote host alias
remote_add() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: gok-new remote add <alias> <host> [user] [key_file] [sudo_mode]"
        echo ""
        echo "Examples:"
        echo "  gok-new remote add master 192.168.1.100 ubuntu"
        echo "  gok-new remote add node1 192.168.1.101 root ~/.ssh/id_rsa never"
        echo "  gok-new remote add debug 10.0.0.244 sumit ~/.ssh/id_rsa always"
        return 1
    fi
    
    local alias="$1"
    local host="$2"
    local user="${3:-root}"
    local key_file="${4:-$HOME/.ssh/id_rsa}"
    local sudo_mode="${5:-auto}"
    
    configure_remote_host "$alias" "$host" "$user" "$key_file" "$sudo_mode" "true"
}

# Copy files to remote hosts
remote_copy_cmd() {
    # Support both alias-based copy and default remote copy
    if [[ -n "$3" ]]; then
        # Full syntax: gok-new remote copy <alias> <local_file> <remote_path>
        remote_copy "$1" "$2" "$3"
    elif [[ -n "$1" ]]; then
        # Default remote syntax: gok-new remote copy <local_file> [remote_path]
        if ! load_default_remote_config; then
            log_error "No default remote configuration found!"
            echo ""
            echo "Please set up your default remote host first:"
            echo "  gok-new remote setup <host> <user> [key_file]"
            return 1
        fi
        
        local local_file="$1"
        local remote_path="${2:-~/$(basename "$local_file")}"
        
        log_info "Copying $local_file to default remote ($DEFAULT_REMOTE_USER@$DEFAULT_REMOTE_HOST):$remote_path"
        
        local ssh_options="-o StrictHostKeyChecking=no"
        if [[ -n "$DEFAULT_REMOTE_KEY" ]]; then
            ssh_options="$ssh_options -i $DEFAULT_REMOTE_KEY"
        fi
        
        scp $ssh_options "$local_file" "$DEFAULT_REMOTE_USER@$DEFAULT_REMOTE_HOST:$remote_path"
    else
        echo "Usage: gok-new remote copy <local_file> [remote_path]"
        echo "   or: gok-new remote copy <alias> <local_file> <remote_path>"
        echo ""
        echo "Examples:"
        echo "  gok-new remote copy ./script.sh                                   # Copy to default remote home"
        echo "  gok-new remote copy ./script.sh /tmp/script.sh                    # Copy to specific path"
        echo "  gok-new remote copy master ./config.yaml /etc/app/config.yaml    # Copy to specific alias"
        return 1
    fi
}

# Copy SSH key to remote host
remote_copy_key() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: gok-new remote copy-key <host> <user> [key_file]"
        echo ""
        echo "Examples:"
        echo "  gok-new remote copy-key 10.0.0.244 sumit"
        echo "  gok-new remote copy-key 192.168.1.100 ubuntu ~/.ssh/id_rsa"
        return 1
    fi
    copy_ssh_key "$1" "$2" "${3:-$HOME/.ssh/id_rsa}"
}

# Setup passwordless sudo on remote host
remote_setup_sudo() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: gok-new remote setup-sudo <host> <user> [key_file] [password]"
        echo ""
        echo "Configure passwordless sudo for root commands."
        echo ""
        echo "Examples:"
        echo "  gok-new remote setup-sudo 10.0.0.244 sumit"
        echo "  gok-new remote setup-sudo 192.168.1.100 ubuntu ~/.ssh/id_rsa mypassword"
        echo ""
        echo "Note: If password is not provided, you'll be prompted for it."
        return 1
    fi
    setup_passwordless_sudo "$1" "$2" "${3:-$HOME/.ssh/id_rsa}" "$4"
}

# Test connection to remote host
remote_test_connection() {
    if [[ -z "$1" ]]; then
        echo "Usage: gok-new remote test-connection <alias>"
        echo ""
        echo "Examples:"
        echo "  gok-new remote test-connection master"
        echo "  gok-new remote test-connection node1"
        return 1
    fi
    
    if [[ -z "${REMOTE_HOSTS[$1]}" ]]; then
        log_error "Remote host '$1' not configured"
        if [[ ${#REMOTE_HOSTS[@]} -gt 0 ]]; then
            log_info "Available hosts: ${!REMOTE_HOSTS[*]}"
        else
            log_info "No remote hosts configured. Use 'gok-new remote add' to configure hosts."
        fi
        return 1
    fi
    
    local host="${REMOTE_HOSTS[$1]}"
    local user="${REMOTE_USERS[$1]}"
    local key_file="${REMOTE_KEYS[$1]}"
    
    log_info "Testing connection to $1 ($user@$host)..."
    
    local ssh_options="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
    if [[ -n "$key_file" ]]; then
        ssh_options="$ssh_options -i $key_file"
    fi
    
    ssh $ssh_options "$user@$host" "echo 'SSH connection successful'; hostname; date"
    if [ $? -eq 0 ]; then
        log_success "Connection test successful for $1"
    else
        log_error "Connection test failed for $1"
        return 1
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Save default remote configuration
save_default_remote_config() {
    local host="$1"
    local user="$2"
    local key_file="${3:-$HOME/.ssh/id_rsa}"
    local sudo_mode="${4:-auto}"
    
    mkdir -p "$REMOTE_CONFIG_DIR"
    
    cat > "$DEFAULT_CONFIG_FILE" << EOF
# GOK Default Remote Configuration
DEFAULT_REMOTE_HOST="$host"
DEFAULT_REMOTE_USER="$user"
DEFAULT_REMOTE_KEY="$key_file"
DEFAULT_REMOTE_SUDO="$sudo_mode"
EOF
    
    log_success "Default remote configuration saved: $user@$host (sudo: $sudo_mode)"
}

# Setup SSH keys for passwordless authentication
setup_ssh_keys() {
    local key_file="${1:-$HOME/.ssh/id_rsa}"
    
    log_info "Setting up SSH keys for remote access..."
    
    # Generate SSH key if it doesn't exist
    if [ ! -f "$key_file" ]; then
        log_info "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "$key_file" -N ""
        if [ $? -eq 0 ]; then
            log_success "SSH key pair generated: $key_file"
        else
            log_error "Failed to generate SSH key pair"
            return 1
        fi
    else
        log_info "SSH key already exists: $key_file"
    fi
    
    # Set proper permissions
    chmod 600 "$key_file"
    chmod 644 "${key_file}.pub"
    
    log_success "SSH keys are ready for use"
}

# Copy SSH key to remote host
copy_ssh_key() {
    local host="$1"
    local user="${2:-root}"
    local key_file="${3:-$HOME/.ssh/id_rsa}"
    
    log_info "Copying SSH key to $user@$host..."
    
    # Ensure SSH key exists
    if [ ! -f "$key_file" ]; then
        log_warning "SSH key not found, generating it first..."
        setup_ssh_keys "$key_file"
    fi
    
    # Copy the key
    ssh-copy-id -i "${key_file}.pub" "$user@$host"
    if [ $? -eq 0 ]; then
        log_success "SSH key successfully copied to $user@$host"
        
        # Test the connection
        log_info "Testing SSH connection..."
        ssh -i "$key_file" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$user@$host" "echo 'SSH connection successful'; hostname; date"
        if [ $? -eq 0 ]; then
            log_success "SSH connection test successful"
        else
            log_warning "SSH connection test failed, but key was copied"
        fi
    else
        log_error "Failed to copy SSH key to $user@$host"
        return 1
    fi
}

# Configure passwordless sudo for remote user
setup_passwordless_sudo() {
    local host="$1"
    local user="${2:-root}"
    local key_file="${3:-$HOME/.ssh/id_rsa}"
    local user_password="$4"
    
    log_info "Setting up passwordless sudo for $user@$host..."
    
    # Skip if user is already root
    if [ "$user" = "root" ]; then
        log_info "User is root, passwordless sudo not needed"
        return 0
    fi
    
    # Test if passwordless sudo is already working
    ssh -i "$key_file" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "$user@$host" "sudo -n whoami" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        log_info "Passwordless sudo already configured for $user"
        return 0
    fi
    
    # If no password provided, prompt for it
    if [ -z "$user_password" ]; then
        echo -n "Enter password for $user on $host: "
        read -s user_password
        echo
    fi
    
    # Configure passwordless sudo
    log_info "Configuring passwordless sudo..."
    ssh -i "$key_file" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
        "$user@$host" "echo '$user_password' | sudo -S bash -c 'echo \"$user ALL=(ALL) NOPASSWD: ALL\" > /etc/sudoers.d/$user && chmod 440 /etc/sudoers.d/$user'" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        # Test passwordless sudo
        ssh -i "$key_file" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
            "$user@$host" "sudo whoami" >/dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            log_success "Passwordless sudo configured successfully for $user"
            return 0
        else
            log_error "Passwordless sudo configuration failed - testing failed"
            return 1
        fi
    else
        log_error "Failed to configure passwordless sudo (wrong password?)"
        return 1
    fi
}

# Configure remote host
configure_remote_host() {
    local alias="$1"
    local host="$2"
    local user="${3:-root}"
    local key_file="${4:-$HOME/.ssh/id_rsa}"
    local sudo_mode="${5:-auto}"
    local auto_setup="${6:-true}"
    
    log_info "Configuring remote host: $alias ($user@$host, sudo: $sudo_mode)"
    
    # Automatically setup SSH keys if requested
    if [ "$auto_setup" = "true" ]; then
        setup_ssh_keys "$key_file"
        copy_ssh_key "$host" "$user" "$key_file"
        if [ $? -ne 0 ]; then
            log_error "Failed to setup SSH access to $user@$host"
            return 1
        fi
    fi
    
    REMOTE_HOSTS["$alias"]="$host"
    REMOTE_USERS["$alias"]="$user"
    REMOTE_KEYS["$alias"]="$key_file"
    REMOTE_SUDOS["$alias"]="$sudo_mode"
    
    # Persist configuration
    mkdir -p "$REMOTE_CONFIG_DIR"
    {
        echo "HOST_${alias}=${host}"
        echo "USER_${alias}=${user}"
        echo "KEY_${alias}=${key_file}"
        echo "SUDO_${alias}=${sudo_mode}"
    } >> "$REMOTE_CONFIG_FILE"
    
    log_success "Configured remote host: $alias ($user@$host, sudo: $sudo_mode)"
}

# Show configured remote hosts
show_remote_hosts() {
    log_header "Configured Remote Hosts"
    
    # Show default configuration first
    if load_default_remote_config; then
        echo "🎯 Default Remote Host:"
        echo "  Host: $DEFAULT_REMOTE_USER@$DEFAULT_REMOTE_HOST"
        echo "  Key:  $DEFAULT_REMOTE_KEY"
        echo "  Sudo: $DEFAULT_REMOTE_SUDO"
        echo
    fi
    
    if [[ ${#REMOTE_HOSTS[@]} -eq 0 ]]; then
        log_warning "No remote host aliases configured"
        echo
        echo "To configure remote hosts:"
        echo "  gok-new remote setup <host> <user>        # Setup default remote"
        echo "  gok-new remote add <alias> <host> <user>  # Add alias"
        return 0
    fi
    
    echo "📡 Remote Host Aliases:"
    for alias in "${!REMOTE_HOSTS[@]}"; do
        local host="${REMOTE_HOSTS[$alias]}"
        local user="${REMOTE_USERS[$alias]}"
        local key_file="${REMOTE_KEYS[$alias]}"
        local sudo_mode="${REMOTE_SUDOS[$alias]}"
        
        echo "  $alias: $user@$host"
        echo "    Key:  $key_file"
        echo "    Sudo: $sudo_mode"
        
        # Test connectivity
        local ssh_options="-o StrictHostKeyChecking=no -o ConnectTimeout=5"
        if [[ -n "$key_file" ]]; then
            ssh_options="$ssh_options -i $key_file"
        fi
        
        if ssh $ssh_options "$user@$host" "echo 'Connection test'" >/dev/null 2>&1; then
            echo "    Status: ✅ Connected"
        else
            echo "    Status: ❌ Connection failed"
        fi
        echo
    done
}

# Remote status check
remote_status() {
    local alias="${1:-all}"
    
    local commands="
        echo '=== System Info ==='
        hostname && date
        echo '=== Kubernetes Status ==='
        kubectl get nodes 2>/dev/null || echo 'kubectl not available'
        echo '=== Docker Status ==='
        systemctl is-active docker 2>/dev/null || echo 'Docker not running'
        echo '=== Load Average ==='
        uptime
        echo '=== Disk Usage ==='
        df -h / | tail -1
    "
    
    if [[ "$alias" == "all" ]]; then
        remote_exec_all "$commands"
    else
        remote_exec "$alias" "$commands"
    fi
}

# Install GOK on remote hosts
remote_install_gok() {
    local alias="${1:-all}"
    
    local commands="
        # Download GOK script
        curl -fsSL https://raw.githubusercontent.com/sumitmaji/kubernetes/main/install_k8s/gok-new -o /tmp/gok-new
        chmod +x /tmp/gok-new
        sudo mv /tmp/gok-new /usr/local/bin/gok-new
        
        # Verify installation
        gok-new --version || echo 'GOK-new installation completed'
    "
    
    if [[ "$alias" == "all" ]]; then
        remote_exec_all "$commands"
    else
        remote_exec "$alias" "$commands"
    fi
}

# Show comprehensive remote help
show_remote_help() {
    log_header "GOK Remote Management"
    
    echo "Comprehensive remote execution and file management system"
    echo ""
    echo "🎯 QUICK START (Recommended):"
    echo ""
    echo "Step 1 - Setup default remote host with full configuration:"
    echo "  gok-new remote setup <host> <user> [key_file] [sudo_mode]"
    echo ""
    echo "Step 2 - Execute commands seamlessly:"
    echo "  gok-new exec \"<command>\"                       # Runs with configured sudo settings"
    echo "  gok-new remote copy <file> [path]               # Copy files to remote host"
    echo ""
    echo "✨ Complete Setup Example:"
    echo "  gok-new remote setup 10.0.0.244 sumit          # Interactive sudo setup"
    echo "  gok-new exec \"docker ps\"                       # Automatically uses sudo"
    echo "  gok-new exec \"kubectl get pods\"                # Automatically uses sudo"
    echo "  gok-new remote copy script.sh /tmp/             # Copy files"
    echo ""
    echo "🔧 COMMANDS:"
    echo ""
    echo "Setup & Configuration:"
    echo "  setup <host> <user> [key] [sudo]   Setup default remote host"
    echo "  add <alias> <host> [user] [key]     Add remote host alias"
    echo "  list                                Show configured hosts"
    echo ""
    echo "Execution & File Operations:"
    echo "  exec \"<command>\"                    Execute on default remote"
    echo "  exec <target> \"<command>\"          Execute on specific target"
    echo "  copy <file> [path]                  Copy to default remote"
    echo "  copy <alias> <file> <path>          Copy to specific alias"
    echo ""
    echo "System Management:"
    echo "  status [alias]                      Show system status"
    echo "  test-connection <alias>             Test SSH connection"
    echo "  install-gok [alias]                 Install GOK remotely"
    echo ""
    echo "SSH Management:"
    echo "  setup-ssh [key_file]                Generate SSH keys"
    echo "  copy-key <host> <user> [key]        Copy SSH key to host"
    echo "  setup-sudo <host> <user> [key]      Setup passwordless sudo"
    echo ""
    echo "🔐 SUDO MODES:"
    echo ""
    echo "  always  - Every command gets 'sudo' prefix"
    echo "  auto    - Smart detection of commands that need root (recommended)"
    echo "  never   - Never add sudo automatically"
    echo ""
    echo "💡 Examples:"
    echo ""
    echo "  # Quick setup"
    echo "  gok-new remote setup 192.168.1.100 ubuntu"
    echo ""
    echo "  # Execute commands"
    echo "  gok-new exec \"kubectl get nodes\""
    echo "  gok-new exec \"systemctl status docker\""
    echo ""
    echo "  # Copy files"
    echo "  gok-new remote copy ./config.yaml /etc/"
    echo "  gok-new remote copy script.sh"
    echo ""
    echo "  # Multi-host management"
    echo "  gok-new remote add master 192.168.1.100 ubuntu"
    echo "  gok-new remote add node1 192.168.1.101 ubuntu"
    echo "  gok-new exec all \"systemctl status docker\""
}