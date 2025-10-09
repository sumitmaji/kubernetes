#!/bin/bash
# lib/utils/ha_validation.sh
# High Availability (HA) Validation Utility for GOK-New Modular System
# 
# This utility provides comprehensive HA validation and management with:
# • HA proxy installation validation and diagnostics
# • Kubernetes HA dependency validation
# • Container status checking and troubleshooting
# • Network connectivity testing and validation
# • Configuration file validation and analysis
# • Detailed diagnostics and troubleshooting guidance
#
# Usage in components:
#   source_gok_utility "ha_validation"
#   validate_ha_proxy_installation [--verbose]
#   validate_ha_dependency_for_kubernetes [--verbose]
#
# Integration example:
#   if ! validate_ha_setup_for_component "kubernetes"; then
#       log_error "HA validation failed for kubernetes"
#       return 1
#   fi
# =============================================================================

# Ensure required utilities are available
if [[ "${GOK_UTILS_HA_VALIDATION_LOADED:-}" == "true" ]]; then
    return 0
fi

# Global configuration for HA validation
: ${HA_PROXY_PORT:=6643}
: ${HA_PROXY_HOSTNAME:=localhost}
: ${HA_PROXY_CONFIG_PATH:="/opt/haproxy.cfg"}
: ${HA_PROXY_CONTAINER_NAME:="master-proxy"}

# =============================================================================
# HA PROXY VALIDATION FUNCTIONS
# =============================================================================

# Comprehensive HA proxy installation validation
validate_ha_proxy_installation() {
    local verbose_mode=false
    local validation_passed=true
    local start_time=$(date +%s)
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                verbose_mode=true
                ;;
        esac
    done
    
    log_step "HA Proxy Validation" "Validating HA proxy installation and configuration"
    
    # Check Docker availability first
    if ! validate_docker_for_ha_proxy "$verbose_mode"; then
        validation_passed=false
    fi
    
    # Check HA proxy container status
    if ! validate_ha_proxy_container_status "$verbose_mode"; then
        validation_passed=false
    fi
    
    # Check HA proxy network connectivity
    if ! validate_ha_proxy_connectivity "$verbose_mode"; then
        validation_passed=false
    fi
    
    # Check HA proxy configuration
    if ! validate_ha_proxy_configuration "$verbose_mode"; then
        validation_passed=false
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Show detailed diagnostics if validation failed
    if [[ "$validation_passed" == "false" ]]; then
        show_ha_proxy_diagnostics "$verbose_mode"
        log_error "HA proxy installation validation failed (${duration}s)"
        return 1
    fi
    
    log_success "HA proxy installation validation passed (${duration}s)"
    return 0
}

# Validate Docker availability for HA proxy
validate_docker_for_ha_proxy() {
    local verbose_mode="$1"
    
    log_substep "Checking Docker availability for HA proxy"
    
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker not found - required for HA proxy container"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running or not accessible"
        if [[ "$verbose_mode" == "true" ]]; then
            log_info "Try: sudo systemctl start docker"
        fi
        return 1
    fi
    
    log_success "Docker is available and running"
    
    if [[ "$verbose_mode" == "true" ]]; then
        local docker_version=$(docker --version 2>/dev/null || echo "Unknown")
        log_info "Docker version: $docker_version"
    fi
    
    return 0
}

# Validate HA proxy container status
validate_ha_proxy_container_status() {
    local verbose_mode="$1"
    local container_name="${HA_PROXY_CONTAINER_NAME}"
    
    log_substep "Checking HA proxy container status"
    
    # Check if HA proxy container exists and is running
    local ha_container=$(docker ps --filter "name=$container_name" --format "{{.Names}}" 2>/dev/null || true)
    
    if [[ -z "$ha_container" ]]; then
        # Check if container exists but is stopped
        local ha_container_stopped=$(docker ps -a --filter "name=$container_name" --format "{{.Names}}" 2>/dev/null || true)
        
        if [[ -n "$ha_container_stopped" ]]; then
            log_error "HA proxy container '$container_name' exists but is not running"
            
            if [[ "$verbose_mode" == "true" ]]; then
                log_info "Container status details:"
                docker ps -a --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" 2>/dev/null || true
                
                # Show container logs for troubleshooting
                log_info "Recent container logs:"
                docker logs --tail 10 "$container_name" 2>&1 | while read line; do
                    log_info "  $line"
                done
            fi
            
            return 1
        else
            log_error "HA proxy container '$container_name' not found"
            
            if [[ "$verbose_mode" == "true" ]]; then
                log_info "Available containers:"
                docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null | head -5 || true
            fi
            
            return 1
        fi
    else
        log_success "HA proxy container '$container_name' is running"
        
        if [[ "$verbose_mode" == "true" ]]; then
            log_info "Container details:"
            docker ps --filter "name=$container_name" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}" 2>/dev/null || true
            
            # Show container resource usage
            local container_stats=$(docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}" "$container_name" 2>/dev/null || echo "N/A\tN/A")
            log_info "Resource usage: CPU: $(echo "$container_stats" | cut -f1), Memory: $(echo "$container_stats" | cut -f2)"
        fi
    fi
    
    return 0
}

# Validate HA proxy network connectivity
validate_ha_proxy_connectivity() {
    local verbose_mode="$1"
    local ha_port="${HA_PROXY_PORT}"
    local ha_host="${HA_PROXY_HOSTNAME}"
    
    log_substep "Testing HA proxy connectivity on ${ha_host}:${ha_port}"
    
    # Test port connectivity using multiple methods
    local connectivity_test_passed=false
    
    # Method 1: netcat (nc)
    if command -v nc >/dev/null 2>&1; then
        if timeout 5 nc -z "$ha_host" "$ha_port" 2>/dev/null; then
            connectivity_test_passed=true
            log_success "HA proxy port ${ha_port} is accessible (via nc)"
        fi
    fi
    
    # Method 2: bash TCP test (if nc failed)
    if [[ "$connectivity_test_passed" == "false" ]]; then
        if timeout 5 bash -c "</dev/tcp/${ha_host}/${ha_port}" 2>/dev/null; then
            connectivity_test_passed=true
            log_success "HA proxy port ${ha_port} is accessible (via bash TCP)"
        fi
    fi
    
    # Method 3: telnet (if previous methods failed)
    if [[ "$connectivity_test_passed" == "false" ]] && command -v telnet >/dev/null 2>&1; then
        if echo "" | timeout 5 telnet "$ha_host" "$ha_port" 2>&1 | grep -q "Connected"; then
            connectivity_test_passed=true
            log_success "HA proxy port ${ha_port} is accessible (via telnet)"
        fi
    fi
    
    if [[ "$connectivity_test_passed" == "false" ]]; then
        log_error "HA proxy port ${ha_port} is not accessible on ${ha_host}"
        
        if [[ "$verbose_mode" == "true" ]]; then
            # Show port binding information
            log_info "Port binding diagnostics:"
            netstat -tlnp 2>/dev/null | grep ":${ha_port}" || log_info "  Port ${ha_port} not bound to any process"
            
            # Show firewall status
            if command -v ufw >/dev/null 2>&1; then
                local ufw_status=$(ufw status 2>/dev/null | grep -i "status:" || echo "Unknown")
                log_info "Firewall status: $ufw_status"
            fi
            
            # Show network interfaces
            log_info "Network interfaces:"
            ip addr show | grep -E "(inet |UP)" | head -5 | while read line; do
                log_info "  $line"
            done
        fi
        
        return 1
    fi
    
    # Additional connectivity tests for verbose mode
    if [[ "$verbose_mode" == "true" ]]; then
        test_ha_proxy_endpoints "$ha_host" "$ha_port"
    fi
    
    return 0
}

# Test HA proxy endpoints and health checks
test_ha_proxy_endpoints() {
    local ha_host="$1"
    local ha_port="$2"
    
    log_info "Testing HA proxy endpoints:"
    
    # Test stats endpoint if available
    local stats_url="http://${ha_host}:${ha_port}/stats"
    if command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout 5 "$stats_url" >/dev/null 2>&1; then
            log_info "  ✓ Stats endpoint accessible: $stats_url"
        else
            log_info "  ✗ Stats endpoint not accessible: $stats_url"
        fi
    fi
    
    # Test health check endpoint
    local health_url="http://${ha_host}:${ha_port}/health"
    if command -v curl >/dev/null 2>&1; then
        local health_response=$(curl -s --connect-timeout 5 "$health_url" 2>/dev/null || echo "")
        if [[ -n "$health_response" ]]; then
            log_info "  ✓ Health endpoint accessible: $health_url"
        else
            log_info "  ✗ Health endpoint not accessible: $health_url"
        fi
    fi
}

# Validate HA proxy configuration file
validate_ha_proxy_configuration() {
    local verbose_mode="$1"
    local config_path="${HA_PROXY_CONFIG_PATH}"
    
    log_substep "Checking HA proxy configuration"
    
    if [[ -f "$config_path" ]]; then
        log_success "HA proxy configuration file exists: $config_path"
        
        # Validate configuration syntax if haproxy command is available
        if command -v haproxy >/dev/null 2>&1; then
            if haproxy -c -f "$config_path" >/dev/null 2>&1; then
                log_success "HA proxy configuration syntax is valid"
            else
                log_error "HA proxy configuration syntax validation failed"
                if [[ "$verbose_mode" == "true" ]]; then
                    log_info "Configuration errors:"
                    haproxy -c -f "$config_path" 2>&1 | while read line; do
                        log_error "  $line"
                    done
                fi
                return 1
            fi
        fi
        
        if [[ "$verbose_mode" == "true" ]]; then
            analyze_ha_proxy_configuration "$config_path"
        fi
    else
        log_warning "HA proxy configuration file not found at $config_path"
        
        # Check alternative common locations
        local alt_locations=("/etc/haproxy/haproxy.cfg" "/usr/local/etc/haproxy/haproxy.cfg" "/opt/haproxy/haproxy.cfg")
        for alt_path in "${alt_locations[@]}"; do
            if [[ -f "$alt_path" ]]; then
                log_info "Alternative configuration found at: $alt_path"
                break
            fi
        done
        
        return 1
    fi
    
    return 0
}

# Analyze HA proxy configuration file in detail
analyze_ha_proxy_configuration() {
    local config_path="$1"
    
    log_info "HA proxy configuration analysis:"
    
    # Extract key configuration sections
    local bind_addresses=$(grep -E "^\s*bind" "$config_path" 2>/dev/null | head -3)
    if [[ -n "$bind_addresses" ]]; then
        log_info "  Bind addresses:"
        echo "$bind_addresses" | while read line; do
            log_info "    $line"
        done
    fi
    
    local backend_servers=$(grep -E "^\s*server" "$config_path" 2>/dev/null | head -5)
    if [[ -n "$backend_servers" ]]; then
        log_info "  Backend servers:"
        echo "$backend_servers" | while read line; do
            log_info "    $line"
        done
    fi
    
    # Check for common configuration patterns
    if grep -q "mode http" "$config_path" 2>/dev/null; then
        log_info "  Mode: HTTP load balancing configured"
    fi
    
    if grep -q "mode tcp" "$config_path" 2>/dev/null; then
        log_info "  Mode: TCP load balancing configured"
    fi
    
    if grep -q "balance" "$config_path" 2>/dev/null; then
        local balance_method=$(grep "balance" "$config_path" | head -1 | awk '{print $2}')
        log_info "  Load balancing method: ${balance_method:-unknown}"
    fi
}

# =============================================================================
# KUBERNETES HA DEPENDENCY VALIDATION
# =============================================================================

# Comprehensive HA dependency validation for Kubernetes
validate_ha_dependency_for_kubernetes() {
    local verbose_mode=false
    local start_time=$(date +%s)
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --verbose|-v)
                verbose_mode=true
                ;;
        esac
    done
    
    log_step "HA Validation" "Validating HA dependencies for Kubernetes"
    
    # Collect system information for analysis
    local system_info=$(collect_system_info_for_ha)
    
    if [[ "$verbose_mode" == "true" ]]; then
        show_ha_system_analysis "$system_info"
    fi
    
    # Validate API_SERVERS configuration if set
    if ! validate_api_servers_configuration "$verbose_mode"; then
        log_error "API_SERVERS configuration validation failed"
        return 1
    fi
    
    # Validate HA proxy installation
    if ! validate_ha_proxy_installation "$verbose_mode"; then
        log_error "HA proxy validation failed"
        return 1
    fi
    
    # Validate HA network requirements
    if ! validate_ha_network_requirements "$verbose_mode"; then
        log_error "HA network requirements validation failed"
        return 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "HA dependency validation for Kubernetes passed (${duration}s)"
    return 0
}

# Collect system information for HA analysis
collect_system_info_for_ha() {
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)
    local network_interfaces=$(ip link show | grep -c "state UP" || echo 0)
    local disk_space=$(df -h / | awk 'NR==2 {print $4}')
    
    echo "memory_gb:${mem_gb}"
    echo "cpu_cores:${cpu_cores}"
    echo "network_interfaces:${network_interfaces}"
    echo "disk_space:${disk_space}"
}

# Show HA system analysis information
show_ha_system_analysis() {
    local system_info="$1"
    
    log_info "HA system analysis:"
    
    while IFS=: read -r key value; do
        case "$key" in
            "memory_gb")
                echo -e "${COLOR_DIM}  • Memory: ${value}GB${COLOR_RESET}"
                if [[ $value -lt 4 ]]; then
                    log_warning "    Low memory for HA setup (recommended: 4GB+)"
                fi
                ;;
            "cpu_cores")
                echo -e "${COLOR_DIM}  • CPU cores: ${value}${COLOR_RESET}"
                if [[ $value -lt 2 ]]; then
                    log_warning "    Limited CPU for HA setup (recommended: 2+ cores)"
                fi
                ;;
            "network_interfaces")
                echo -e "${COLOR_DIM}  • Active network interfaces: ${value}${COLOR_RESET}"
                ;;
            "disk_space")
                echo -e "${COLOR_DIM}  • Available disk space: ${value}${COLOR_RESET}"
                ;;
        esac
    done <<< "$system_info"
    
    # Show HA-specific environment variables
    echo -e "${COLOR_DIM}  • API_SERVERS: ${API_SERVERS:-'not set'}${COLOR_RESET}"
    echo -e "${COLOR_DIM}  • HA_PROXY_PORT: ${HA_PROXY_PORT:-'not set'}${COLOR_RESET}"
    echo -e "${COLOR_DIM}  • HA_PROXY_HOSTNAME: ${HA_PROXY_HOSTNAME:-'not set'}${COLOR_RESET}"
}

# Validate API_SERVERS configuration format
validate_api_servers_configuration() {
    local verbose_mode="$1"
    
    log_substep "Validating API_SERVERS configuration"
    
    if [[ -z "$API_SERVERS" ]]; then
        log_warning "API_SERVERS environment variable not set"
        log_info "This is optional for single-master setups"
        return 0
    fi
    
    # Validate API_SERVERS format: should be 'IP:hostname' or 'IP1:host1,IP2:host2'
    if [[ "$API_SERVERS" != *":"* ]]; then
        log_error "API_SERVERS is malformed: '$API_SERVERS'"
        log_error "Expected format: 'IP:hostname' or 'IP1:host1,IP2:host2'"
        
        if [[ "$verbose_mode" == "true" ]]; then
            log_info "Examples of valid API_SERVERS:"
            log_info "  • Single master: API_SERVERS='192.168.1.10:master1'"
            log_info "  • Multi master: API_SERVERS='192.168.1.10:master1,192.168.1.11:master2'"
        fi
        
        return 1
    fi
    
    # Parse and validate each server entry
    local valid_entries=0
    local invalid_entries=()
    
    IFS=',' read -ra server_entries <<< "$API_SERVERS"
    for entry in "${server_entries[@]}"; do
        if validate_single_api_server_entry "$entry" "$verbose_mode"; then
            valid_entries=$((valid_entries + 1))
        else
            invalid_entries+=("$entry")
        fi
    done
    
    if [[ ${#invalid_entries[@]} -gt 0 ]]; then
        log_error "Invalid API_SERVERS entries: ${invalid_entries[*]}"
        return 1
    fi
    
    log_success "API_SERVERS configuration valid ($valid_entries entries)"
    return 0
}

# Validate a single API server entry
validate_single_api_server_entry() {
    local entry="$1"
    local verbose_mode="$2"
    
    # Parse IP and hostname
    IFS=':' read -r ip hostname <<< "$entry"
    
    if [[ -z "$ip" ]] || [[ -z "$hostname" ]]; then
        log_error "Invalid entry format: '$entry' (missing IP or hostname)"
        return 1
    fi
    
    # Validate IP address format
    if ! validate_ip_address "$ip"; then
        log_error "Invalid IP address in entry: '$ip'"
        return 1
    fi
    
    # Validate hostname format
    if ! validate_hostname_format "$hostname"; then
        log_error "Invalid hostname in entry: '$hostname'"
        return 1
    fi
    
    if [[ "$verbose_mode" == "true" ]]; then
        log_info "  ✓ Valid entry: $ip -> $hostname"
        
        # Test connectivity if requested
        if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
            log_info "    Connectivity: $ip is reachable"
        else
            log_warning "    Connectivity: $ip is not reachable (may be normal)"
        fi
    fi
    
    return 0
}

# Validate IP address format
validate_ip_address() {
    local ip="$1"
    
    # Simple IPv4 validation
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        # Check each octet is valid (0-255)
        IFS='.' read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [[ $octet -gt 255 ]] || [[ $octet -lt 0 ]]; then
                return 1
            fi
        done
        return 0
    fi
    
    return 1
}

# Validate hostname format
validate_hostname_format() {
    local hostname="$1"
    
    # Basic hostname validation: alphanumeric, hyphens, dots
    if [[ $hostname =~ ^[a-zA-Z0-9.-]+$ ]]; then
        # Must not start or end with hyphen
        if [[ $hostname != -* ]] && [[ $hostname != *- ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Validate HA network requirements
validate_ha_network_requirements() {
    local verbose_mode="$1"
    
    log_substep "Validating HA network requirements"
    
    # Check if required ports are available
    local required_ports=("${HA_PROXY_PORT}" "6443" "2379" "2380")
    local blocked_ports=()
    
    for port in "${required_ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
            if [[ "$port" != "${HA_PROXY_PORT}" ]]; then  # HA proxy port should be bound
                blocked_ports+=("$port")
            fi
        fi
    done
    
    if [[ ${#blocked_ports[@]} -gt 0 ]]; then
        log_warning "Ports already in use (may conflict with HA setup): ${blocked_ports[*]}"
        if [[ "$verbose_mode" == "true" ]]; then
            for port in "${blocked_ports[@]}"; do
                local process=$(netstat -tlnp 2>/dev/null | grep ":${port} " | awk '{print $NF}' | head -1)
                log_info "  Port $port used by: ${process:-unknown}"
            done
        fi
    fi
    
    # Check network connectivity requirements
    if ! test_network_connectivity_for_ha "$verbose_mode"; then
        return 1
    fi
    
    log_success "HA network requirements satisfied"
    return 0
}

# Test network connectivity for HA setup
test_network_connectivity_for_ha() {
    local verbose_mode="$1"
    
    # Test localhost connectivity
    if ! ping -c 1 -W 2 localhost >/dev/null 2>&1; then
        log_error "Localhost connectivity test failed"
        return 1
    fi
    
    # Test external connectivity (for downloading packages)
    if ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        log_warning "External connectivity test failed (may affect package downloads)"
        if [[ "$verbose_mode" == "true" ]]; then
            log_info "This may be normal in restricted network environments"
        fi
    fi
    
    return 0
}

# =============================================================================
# HA DIAGNOSTICS AND TROUBLESHOOTING
# =============================================================================

# Show comprehensive HA proxy diagnostics
show_ha_proxy_diagnostics() {
    local verbose_mode="$1"
    
    echo -e "\n${COLOR_BRIGHT_YELLOW}${COLOR_BOLD}🔧 HA PROXY DIAGNOSTICS${COLOR_RESET}"
    echo -e "${COLOR_DIM}═══════════════════════════════════════════${COLOR_RESET}"
    
    # Container status diagnostics
    echo -e "${COLOR_YELLOW}Container Status:${COLOR_RESET}"
    local containers=$(docker ps -a --filter "name=${HA_PROXY_CONTAINER_NAME}" 2>/dev/null || echo "No containers found")
    if [[ "$containers" == "No containers found" ]]; then
        echo -e "  ${COLOR_RED}✗ No HA proxy container found${COLOR_RESET}"
    else
        echo "$containers"
    fi
    
    # Network diagnostics
    echo -e "\n${COLOR_YELLOW}Network Diagnostics:${COLOR_RESET}"
    echo -e "  Testing ${HA_PROXY_HOSTNAME}:${HA_PROXY_PORT}..."
    
    local port_test_result="Failed"
    if command -v nc >/dev/null 2>&1 && nc -z "${HA_PROXY_HOSTNAME}" "${HA_PROXY_PORT}" 2>/dev/null; then
        port_test_result="Success"
    fi
    echo -e "  Port connectivity: ${port_test_result}"
    
    # Port binding diagnostics
    echo -e "\n${COLOR_YELLOW}Port Bindings:${COLOR_RESET}"
    local port_bindings=$(netstat -tlnp 2>/dev/null | grep ":${HA_PROXY_PORT}" || echo "Port ${HA_PROXY_PORT} not bound")
    echo -e "  $port_bindings"
    
    # Docker service diagnostics
    echo -e "\n${COLOR_YELLOW}Docker Service:${COLOR_RESET}"
    if systemctl is-active --quiet docker 2>/dev/null; then
        echo -e "  ${COLOR_GREEN}✓ Docker service is active${COLOR_RESET}"
    else
        echo -e "  ${COLOR_RED}✗ Docker service is not active${COLOR_RESET}"
    fi
    
    # Configuration file diagnostics
    echo -e "\n${COLOR_YELLOW}Configuration:${COLOR_RESET}"
    if [[ -f "${HA_PROXY_CONFIG_PATH}" ]]; then
        echo -e "  ${COLOR_GREEN}✓ Configuration file exists: ${HA_PROXY_CONFIG_PATH}${COLOR_RESET}"
        local config_size=$(stat -f%z "${HA_PROXY_CONFIG_PATH}" 2>/dev/null || stat -c%s "${HA_PROXY_CONFIG_PATH}" 2>/dev/null || echo "unknown")
        echo -e "  Configuration size: ${config_size} bytes"
    else
        echo -e "  ${COLOR_RED}✗ Configuration file not found: ${HA_PROXY_CONFIG_PATH}${COLOR_RESET}"
    fi
    
    # Troubleshooting recommendations
    show_ha_troubleshooting_recommendations "$verbose_mode"
}

# Show HA troubleshooting recommendations
show_ha_troubleshooting_recommendations() {
    local verbose_mode="$1"
    
    echo -e "\n${COLOR_CYAN}${COLOR_BOLD}🔍 TROUBLESHOOTING RECOMMENDATIONS${COLOR_RESET}"
    echo -e "${COLOR_DIM}═══════════════════════════════════════════${COLOR_RESET}"
    
    echo -e "${COLOR_CYAN}1. Check Docker service:${COLOR_RESET}"
    echo -e "   ${COLOR_DIM}sudo systemctl status docker${COLOR_RESET}"
    echo -e "   ${COLOR_DIM}sudo systemctl start docker${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}2. Check container logs:${COLOR_RESET}"
    echo -e "   ${COLOR_DIM}docker logs ${HA_PROXY_CONTAINER_NAME}${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}3. Restart HA proxy container:${COLOR_RESET}"
    echo -e "   ${COLOR_DIM}docker restart ${HA_PROXY_CONTAINER_NAME}${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}4. Check port availability:${COLOR_RESET}"
    echo -e "   ${COLOR_DIM}netstat -tlnp | grep :${HA_PROXY_PORT}${COLOR_RESET}"
    echo -e "   ${COLOR_DIM}ss -tlnp | grep :${HA_PROXY_PORT}${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}5. Test network connectivity:${COLOR_RESET}"
    echo -e "   ${COLOR_DIM}nc -z ${HA_PROXY_HOSTNAME} ${HA_PROXY_PORT}${COLOR_RESET}"
    echo -e "   ${COLOR_DIM}curl -I http://${HA_PROXY_HOSTNAME}:${HA_PROXY_PORT}/stats${COLOR_RESET}"
    
    if [[ "$verbose_mode" == "true" ]]; then
        echo -e "\n${COLOR_CYAN}6. Advanced diagnostics:${COLOR_RESET}"
        echo -e "   ${COLOR_DIM}docker inspect ${HA_PROXY_CONTAINER_NAME}${COLOR_RESET}"
        echo -e "   ${COLOR_DIM}docker exec ${HA_PROXY_CONTAINER_NAME} haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg${COLOR_RESET}"
        echo -e "   ${COLOR_DIM}sudo ufw status${COLOR_RESET}"
        echo -e "   ${COLOR_DIM}iptables -L -n${COLOR_RESET}"
    fi
    
    echo
}

# =============================================================================
# CONVENIENCE FUNCTIONS FOR COMPONENT INTEGRATION
# =============================================================================

# Validate HA setup for a specific component
validate_ha_setup_for_component() {
    local component_name="$1"
    shift
    local options=("$@")
    
    log_info "Validating HA setup for $component_name"
    
    case "$component_name" in
        "kubernetes"|"k8s")
            validate_ha_dependency_for_kubernetes "${options[@]}"
            ;;
        *)
            # Generic HA validation
            validate_ha_proxy_installation "${options[@]}"
            ;;
    esac
}

# Quick HA status check
check_ha_status() {
    log_substep "Quick HA status check"
    
    local issues=()
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        issues+=("Docker not available")
    elif ! docker info >/dev/null 2>&1; then
        issues+=("Docker daemon not running")
    fi
    
    # Check HA proxy container
    if ! docker ps --filter "name=${HA_PROXY_CONTAINER_NAME}" --format "{{.Names}}" 2>/dev/null | grep -q "${HA_PROXY_CONTAINER_NAME}"; then
        issues+=("HA proxy container not running")
    fi
    
    # Check port accessibility
    if ! nc -z "${HA_PROXY_HOSTNAME}" "${HA_PROXY_PORT}" 2>/dev/null; then
        issues+=("HA proxy port not accessible")
    fi
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        log_success "HA status check passed"
        return 0
    else
        log_warning "HA status check found issues: ${issues[*]}"
        return 1
    fi
}

# =============================================================================
# MODULE INITIALIZATION
# =============================================================================

# Initialize HA validation utility
init_ha_validation_utility() {
    # Set default configurations if not already set
    : ${HA_PROXY_PORT:=6643}
    : ${HA_PROXY_HOSTNAME:=localhost}
    : ${HA_PROXY_CONFIG_PATH:="/opt/haproxy.cfg"}
    : ${HA_PROXY_CONTAINER_NAME:="master-proxy"}
    
    log_debug "HA validation utility initialized (proxy: ${HA_PROXY_HOSTNAME}:${HA_PROXY_PORT}, container: ${HA_PROXY_CONTAINER_NAME})"
}

# Initialize the utility when sourced
init_ha_validation_utility

# Mark module as loaded
export GOK_UTILS_HA_VALIDATION_LOADED="true"

log_debug "HA Validation utility module loaded successfully"