#!/bin/bash

# DevWorkspace V2 Summary Module

show_workspacev2_summary() {
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}📊 DevWorkspace V2 Status Summary${COLOR_RESET}"
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
    
    # Available workspace templates
    echo -e "\n${COLOR_YELLOW}Available Workspace Templates:${COLOR_RESET}"
    echo -e "  1. ${COLOR_CYAN}core-java${COLOR_RESET} - Java development environment"
    echo -e "  2. ${COLOR_CYAN}springboot-web${COLOR_RESET} - Spring Boot web application"
    echo -e "  3. ${COLOR_CYAN}python-web${COLOR_RESET} - Python web development"
    echo -e "  4. ${COLOR_CYAN}springboot-backend${COLOR_RESET} - Spring Boot backend services"
    echo -e "  5. ${COLOR_CYAN}tensorflow${COLOR_RESET} - Machine learning with TensorFlow"
    echo -e "  6. ${COLOR_CYAN}microservice-study${COLOR_RESET} - Microservices architecture study"
    echo -e "  7. ${COLOR_CYAN}javaparser${COLOR_RESET} - Java code parsing and analysis"
    echo -e "  8. ${COLOR_CYAN}nlp${COLOR_RESET} - Natural Language Processing"
    echo -e "  9. ${COLOR_CYAN}kubeauthentication${COLOR_RESET} - Kubernetes authentication study"
    
    # List all DevWorkspaces by template type
    echo -e "\n${COLOR_YELLOW}Active DevWorkspaces by Template:${COLOR_RESET}"
    local workspace_list=$(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null)
    
    if [[ -z "$workspace_list" ]]; then
        echo -e "  ${COLOR_GRAY}No DevWorkspaces found${COLOR_RESET}"
    else
        echo "$workspace_list" | while read -r line; do
            local ns=$(echo "$line" | awk '{print $1}')
            local name=$(echo "$line" | awk '{print $2}')
            local phase=$(echo "$line" | awk '{print $3}')
            
            # Try to detect workspace type from name
            local type="unknown"
            case "$name" in
                *java*) type="core-java" ;;
                *spring*) type="springboot" ;;
                *python*) type="python-web" ;;
                *tensorflow*) type="tensorflow" ;;
                *microservice*) type="microservice-study" ;;
                *nlp*) type="nlp" ;;
                *kube*) type="kubeauthentication" ;;
            esac
            
            if [[ "$phase" == "Running" ]]; then
                echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $ns/$name [${COLOR_CYAN}$type${COLOR_RESET}] ($phase)"
            else
                echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $ns/$name [${COLOR_CYAN}$type${COLOR_RESET}] ($phase)"
            fi
        done
    fi
    
    # User namespaces summary
    echo -e "\n${COLOR_YELLOW}User Namespaces:${COLOR_RESET}"
    local user_namespaces=$(kubectl get namespaces --no-headers 2>/dev/null | grep -E "^(user[0-9]+|che-user)" | awk '{print $1}')
    
    if [[ -z "$user_namespaces" ]]; then
        echo -e "  ${COLOR_GRAY}No user namespaces found${COLOR_RESET}"
    else
        echo "$user_namespaces" | while read -r ns; do
            local dw_count=$(kubectl get devworkspaces -n "$ns" --no-headers 2>/dev/null | wc -l)
            if [[ $dw_count -gt 0 ]]; then
                echo -e "  ${COLOR_GREEN}$ns${COLOR_RESET}: $dw_count workspace(s)"
            else
                echo -e "  ${COLOR_GRAY}$ns${COLOR_RESET}: 0 workspaces"
            fi
        done
    fi
    
    # Quick stats
    local total_workspaces=$(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null | wc -l)
    local running_workspaces=$(kubectl get devworkspaces --all-namespaces --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    local total_users=$(kubectl get namespaces --no-headers 2>/dev/null | grep -E "^(user[0-9]+|che-user)" | wc -l)
    
    echo -e "\n${COLOR_YELLOW}Statistics:${COLOR_RESET}"
    echo -e "  Total workspaces: ${COLOR_CYAN}$total_workspaces${COLOR_RESET}"
    echo -e "  Running workspaces: ${COLOR_GREEN}$running_workspaces${COLOR_RESET}"
    echo -e "  User namespaces: ${COLOR_CYAN}$total_users${COLOR_RESET}"
    
    echo -e "\n${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

export -f show_workspacev2_summary
