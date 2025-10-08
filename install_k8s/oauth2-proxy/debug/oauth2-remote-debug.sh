#!/bin/bash

# OAuth2 Proxy Remote Debugging Script
# This script executes the OAuth2 debugging on the remote cluster using gok remote exec
# Author: Generated for OAuth2 troubleshooting

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOK_SCRIPT="$(cd "$SCRIPT_DIR/../../" && pwd)/gok"

echo -e "${BOLD}${CYAN}OAuth2 Proxy Remote Debugging Tool${NC}"
echo -e "${CYAN}Using gok script: $GOK_SCRIPT${NC}\n"

# Check if gok script exists
if [[ ! -f "$GOK_SCRIPT" ]]; then
    echo -e "${RED}Error: gok script not found at $GOK_SCRIPT${NC}"
    exit 1
fi

# Function to transfer and execute the debug script remotely
run_remote_debug() {
    local debug_script="$SCRIPT_DIR/oauth2-debug.sh"
    local remote_script="/tmp/oauth2-debug.sh"
    
    echo -e "${YELLOW}Transferring debug script to remote cluster...${NC}"
    
    # Copy the debug script to remote
    scp "$debug_script" sumit@10.0.0.244:"$remote_script" || {
        echo -e "${RED}Failed to copy debug script to remote${NC}"
        exit 1
    }
    
    # Make it executable and run it
    echo -e "${YELLOW}Executing debug script on remote cluster...${NC}"
    "$GOK_SCRIPT" remote exec "chmod +x $remote_script && $remote_script" || {
        echo -e "${RED}Failed to execute debug script remotely${NC}"
        exit 1
    }
    
    # Get the debug directory name from remote - use a simpler approach
    echo -e "\n${YELLOW}Copying debug results back to local machine...${NC}"
    
    # Use a fixed pattern since we know the directory naming convention
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local local_debug_dir="$SCRIPT_DIR/results/oauth2-debug-$timestamp"
    mkdir -p "$local_debug_dir"
    
    # Copy debug results back using wildcards
    scp -r sumit@10.0.0.244:"/tmp/oauth2-debug-*" "$SCRIPT_DIR/results/" 2>/dev/null || {
        echo -e "${YELLOW}Note: Debug files remain on remote server in /tmp/oauth2-debug-*${NC}"
        echo -e "${CYAN}You can manually copy them with: scp -r sumit@10.0.0.244:/tmp/oauth2-debug-* ./results/${NC}"
        local_debug_dir=""
    }
    
    if [[ -d "$local_debug_dir" ]]; then
        echo -e "${GREEN}✓ Debug results copied to: $local_debug_dir${NC}"
    else
        # Find the actual copied directory
        local copied_dir=$(ls -td "$SCRIPT_DIR/results/oauth2-debug-"* 2>/dev/null | head -1)
        if [[ -n "$copied_dir" ]]; then
            echo -e "${GREEN}✓ Debug results copied to: $copied_dir${NC}"
            local_debug_dir="$copied_dir"
        fi
    fi
    
    # Check if we have a valid debug directory (either original or found)
    if [[ -n "$local_debug_dir" && -d "$local_debug_dir" ]]; then
        # Show validation results if available
        if [[ -f "$local_debug_dir/validation_results.txt" ]]; then
            echo -e "\n${BOLD}${BLUE}=== VALIDATION RESULTS ===${NC}"
            cat "$local_debug_dir/validation_results.txt"
        fi
        
        # Show argument explanations
        if [[ -f "$local_debug_dir/arguments_explained.txt" ]]; then
            echo -e "\n${BOLD}${BLUE}=== OAUTH2 ARGUMENTS ANALYSIS ===${NC}"
            head -30 "$local_debug_dir/arguments_explained.txt"
            echo -e "${CYAN}(Full analysis in: $local_debug_dir/arguments_explained.txt)${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}Could not find debug directory on remote${NC}"
        return 1
    fi
}

# Function to compare with previous debug results
compare_with_baseline() {
    local baseline_dir="$1"
    
    if [[ ! -d "$baseline_dir" ]]; then
        echo -e "${RED}Baseline directory not found: $baseline_dir${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Running comparison with baseline: $baseline_dir${NC}"
    
    # Copy comparison script to remote
    local compare_script="$baseline_dir/compare_future_deployment.sh"
    if [[ -f "$compare_script" ]]; then
        scp "$compare_script" sumit@10.0.0.244:/tmp/compare_oauth2.sh
        "$GOK_SCRIPT" remote exec "chmod +x /tmp/compare_oauth2.sh && /tmp/compare_oauth2.sh '$basename_dir' oauth2"
    else
        echo -e "${RED}Comparison script not found in baseline directory${NC}"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo -e "${BOLD}Usage:${NC}"
    echo -e "  $0 capture                           # Capture current OAuth2 configuration"
    echo -e "  $0 compare <baseline_dir>            # Compare with baseline configuration"  
    echo -e "  $0 validate                          # Quick validation of current setup"
    echo -e "  $0 logs                             # Capture and analyze logs only"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  $0 capture"
    echo -e "  $0 compare ./debug/results/oauth2-debug-20241007-123456"
}

# Function to capture logs only
capture_logs_only() {
    echo -e "${YELLOW}Capturing OAuth2 and Ingress logs...${NC}"
    
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local log_dir="$SCRIPT_DIR/results/logs-$timestamp"
    mkdir -p "$log_dir"
    
    # Capture OAuth2 logs
    "$GOK_SCRIPT" remote exec "kubectl logs -n oauth2 -l app.kubernetes.io/name=oauth2-proxy --tail=100" > "$log_dir/oauth2-logs.txt" 2>&1
    
    # Capture Ingress logs  
    "$GOK_SCRIPT" remote exec "kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100" > "$log_dir/ingress-logs.txt" 2>&1
    
    # Capture pod status
    "$GOK_SCRIPT" remote exec "kubectl get pods -n oauth2 -o wide" > "$log_dir/pod-status.txt" 2>&1
    
    echo -e "${GREEN}✓ Logs captured to: $log_dir${NC}"
    
    # Show recent errors
    echo -e "\n${BOLD}${BLUE}=== RECENT OAUTH2 ERRORS ===${NC}"
    grep -i "error\|fail\|denied" "$log_dir/oauth2-logs.txt" | tail -10 || echo "No recent errors found"
    
    echo -e "\n${BOLD}${BLUE}=== RECENT INGRESS ERRORS ===${NC}"  
    grep -i "error\|fail\|502\|503" "$log_dir/ingress-logs.txt" | tail -10 || echo "No recent errors found"
}

# Function to run quick validation
quick_validate() {
    echo -e "${YELLOW}Running quick OAuth2 validation...${NC}"
    
    # Test OAuth2 endpoints
    echo -e "\n${BOLD}Testing OAuth2 endpoints:${NC}"
    
    # Test start endpoint
    if curl -k -s -o /dev/null -w "%{http_code}" "https://kube.gokcloud.com/oauth2/start?rd=/" | grep -q "200\|302"; then
        echo -e "✓ OAuth2 start endpoint: ${GREEN}OK${NC}"
    else
        echo -e "✗ OAuth2 start endpoint: ${RED}FAILED${NC}"
    fi
    
    # Test ping endpoint
    if curl -k -s -o /dev/null -w "%{http_code}" "https://kube.gokcloud.com/oauth2/ping" | grep -q "200"; then
        echo -e "✓ OAuth2 ping endpoint: ${GREEN}OK${NC}"
    else
        echo -e "✗ OAuth2 ping endpoint: ${RED}FAILED${NC}"
    fi
    
    # Check cluster resources
    echo -e "\n${BOLD}Checking cluster resources:${NC}"
    
    # Check deployment
    if "$GOK_SCRIPT" remote exec "kubectl get deployment oauth2-proxy -n oauth2" >/dev/null 2>&1; then
        local ready=$("$GOK_SCRIPT" remote exec "kubectl get deployment oauth2-proxy -n oauth2 -o jsonpath='{.status.readyReplicas}'" 2>/dev/null | tail -1 | tr -d ' \n\r' || echo "0")
        local desired=$("$GOK_SCRIPT" remote exec "kubectl get deployment oauth2-proxy -n oauth2 -o jsonpath='{.spec.replicas}'" 2>/dev/null | tail -1 | tr -d ' \n\r' || echo "1")
        if [[ "$ready" == "$desired" ]] && [[ -n "$ready" ]] && [[ "$ready" != "0" ]]; then
            echo -e "✓ Deployment: ${GREEN}Ready ($ready/$desired)${NC}"
        else
            echo -e "✗ Deployment: ${RED}Not Ready ($ready/$desired)${NC}"
        fi
    else
        echo -e "✗ Deployment: ${RED}NOT FOUND${NC}"
    fi
    
    # Check service endpoints
    local endpoints=$("$GOK_SCRIPT" remote exec "kubectl get endpoints oauth2-proxy -n oauth2 -o jsonpath='{.subsets[*].addresses[*].ip}'" 2>/dev/null | tail -1 | wc -w || echo "0")
    if [[ $endpoints -gt 0 ]]; then
        echo -e "✓ Service endpoints: ${GREEN}$endpoints available${NC}"
    else
        echo -e "✗ Service endpoints: ${RED}NONE${NC}"
    fi
    
    # Check ingress
    if "$GOK_SCRIPT" remote exec "kubectl get ingress oauth2-proxy -n oauth2" >/dev/null 2>&1; then
        echo -e "✓ Ingress: ${GREEN}EXISTS${NC}"
        
        # Check critical annotations
        local buffer_size=$("$GOK_SCRIPT" remote exec "kubectl get ingress oauth2-proxy -n oauth2 -o jsonpath='{.metadata.annotations.nginx\.ingress\.kubernetes\.io/proxy-buffer-size}'" 2>/dev/null | tail -1 | tr -d ' \n\r' || echo "")
        if [[ -n "$buffer_size" ]]; then
            echo -e "✓ Proxy buffer: ${GREEN}$buffer_size${NC}"
        else
            echo -e "⚠ Proxy buffer: ${YELLOW}NOT SET (may cause 502 errors)${NC}"
        fi
    else
        echo -e "✗ Ingress: ${RED}NOT FOUND${NC}"
    fi
}

# Main execution
main() {
    case "${1:-}" in
        "capture")
            run_remote_debug
            ;;
        "compare")
            if [[ -z "${2:-}" ]]; then
                echo -e "${RED}Error: Baseline directory required for comparison${NC}"
                show_usage
                exit 1
            fi
            compare_with_baseline "$2"
            ;;
        "validate")
            quick_validate
            ;;
        "logs")
            capture_logs_only
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        "")
            echo -e "${RED}Error: No action specified${NC}"
            show_usage
            exit 1
            ;;
        *)
            echo -e "${RED}Error: Unknown action: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# Create results directory
mkdir -p "$SCRIPT_DIR/results"

# Run main function with all arguments
main "$@"