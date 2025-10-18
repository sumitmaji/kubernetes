#!/bin/bash

# DevWorkspace Summary Module

show_workspace_summary() {
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}📊 DevWorkspace Status Summary${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    
    # Python dependencies
    echo -e "\n${COLOR_YELLOW}Python Dependencies:${COLOR_RESET}"
    if python3 -c "import kubernetes" &>/dev/null; then
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} python3-kubernetes"
    else
        echo -e "  ${COLOR_RED}✗${COLOR_RESET} python3-kubernetes"
    fi
    
    if python3 -c "import yaml" &>/dev/null; then
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} python3-yaml"
    else
        echo -e "  ${COLOR_RED}✗${COLOR_RESET} python3-yaml"
    fi
    
    # DevWorkspace CRD
    echo -e "\n${COLOR_YELLOW}DevWorkspace CRD:${COLOR_RESET}"
    if kubectl get crd devworkspaces.workspace.devfile.io &>/dev/null; then
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} devworkspaces.workspace.devfile.io"
    else
        echo -e "  ${COLOR_RED}✗${COLOR_RESET} devworkspaces.workspace.devfile.io"
    fi
    
    # List all DevWorkspaces
    echo -e "\n${COLOR_YELLOW}Active DevWorkspaces:${COLOR_RESET}"
    local workspace_list=$(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null)
    
    if [[ -z "$workspace_list" ]]; then
        echo -e "  ${COLOR_GRAY}No DevWorkspaces found${COLOR_RESET}"
    else
        echo "$workspace_list" | while read -r line; do
            local ns=$(echo "$line" | awk '{print $1}')
            local name=$(echo "$line" | awk '{print $2}')
            local phase=$(echo "$line" | awk '{print $3}')
            
            if [[ "$phase" == "Running" ]]; then
                echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $ns/$name ($phase)"
            else
                echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $ns/$name ($phase)"
            fi
        done
    fi
    
    # Namespace summary
    echo -e "\n${COLOR_YELLOW}User Namespaces:${COLOR_RESET}"
    local user_namespaces=$(kubectl get namespaces --no-headers 2>/dev/null | grep -E "che-user|devworkspace" | awk '{print $1}')
    
    if [[ -z "$user_namespaces" ]]; then
        echo -e "  ${COLOR_GRAY}No user namespaces found${COLOR_RESET}"
    else
        echo "$user_namespaces" | while read -r ns; do
            local dw_count=$(kubectl get devworkspaces -n "$ns" --no-headers 2>/dev/null | wc -l)
            echo -e "  $ns: $dw_count workspace(s)"
        done
    fi
    
    echo -e "\n${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

export -f show_workspace_summary
