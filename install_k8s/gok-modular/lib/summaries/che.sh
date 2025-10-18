#!/bin/bash

# Eclipse Che Summary Module

show_che_summary() {
    local CHE_NAMESPACE="eclipse-che"
    
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}📊 Eclipse Che Status Summary${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    
    # Namespace
    echo -e "\n${COLOR_YELLOW}Namespace:${COLOR_RESET} $CHE_NAMESPACE"
    
    # CheCluster status
    if kubectl get checluster -n "$CHE_NAMESPACE" &>/dev/null; then
        local cluster_name=$(kubectl get checluster -n "$CHE_NAMESPACE" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        local cluster_status=$(kubectl get checluster -n "$CHE_NAMESPACE" -o jsonpath='{.items[0].status.chePhase}' 2>/dev/null)
        echo -e "${COLOR_YELLOW}CheCluster:${COLOR_RESET} $cluster_name"
        echo -e "${COLOR_YELLOW}Status:${COLOR_RESET} $cluster_status"
        
        # Che URL
        local che_url=$(kubectl get checluster -n "$CHE_NAMESPACE" -o jsonpath='{.items[0].status.cheURL}' 2>/dev/null)
        if [[ -n "$che_url" ]]; then
            echo -e "${COLOR_YELLOW}Che URL:${COLOR_RESET} ${COLOR_GREEN}$che_url${COLOR_RESET}"
        fi
    else
        echo -e "${COLOR_RED}CheCluster not found${COLOR_RESET}"
    fi
    
    # Pods status
    echo -e "\n${COLOR_YELLOW}Pods:${COLOR_RESET}"
    kubectl get pods -n "$CHE_NAMESPACE" 2>/dev/null | tail -n +2 | while read -r line; do
        local pod_name=$(echo "$line" | awk '{print $1}')
        local pod_status=$(echo "$line" | awk '{print $3}')
        if [[ "$pod_status" == "Running" ]]; then
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $pod_name"
        else
            echo -e "  ${COLOR_RED}✗${COLOR_RESET} $pod_name ($pod_status)"
        fi
    done
    
    # Storage
    echo -e "\n${COLOR_YELLOW}Persistent Volume Claims:${COLOR_RESET}"
    local pvc_count=$(kubectl get pvc -n "$CHE_NAMESPACE" --no-headers 2>/dev/null | wc -l)
    echo -e "  Total PVCs: $pvc_count"
    
    # Ingress/Routes
    echo -e "\n${COLOR_YELLOW}Ingress:${COLOR_RESET}"
    if kubectl get ingress -n "$CHE_NAMESPACE" &>/dev/null; then
        kubectl get ingress -n "$CHE_NAMESPACE" --no-headers 2>/dev/null | while read -r line; do
            local ing_name=$(echo "$line" | awk '{print $1}')
            local ing_hosts=$(echo "$line" | awk '{print $3}')
            echo -e "  $ing_name → $ing_hosts"
        done
    else
        echo -e "  ${COLOR_GRAY}No ingress resources${COLOR_RESET}"
    fi
    
    echo -e "\n${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

export -f show_che_summary
