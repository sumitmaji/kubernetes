#!/bin/bash

# GOK Component Tracking Module - Installation progress and status tracking

# Initialize component tracking system
init_component_tracking() {
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    [[ ! -f "$tracking_file" ]] && touch "$tracking_file"
}

# Start tracking a component installation
start_component() {
    local component="$1"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    # Remove any existing entry for this component
    if [[ -f "$tracking_file" ]]; then
        grep -v "^${component}:" "$tracking_file" > "${tracking_file}.tmp" 2>/dev/null || true
        mv "${tracking_file}.tmp" "$tracking_file" 2>/dev/null || true
    fi
    
    # Add new entry with in-progress status
    echo "${component}:in-progress:$(date +%s)" >> "$tracking_file"
    
    log_info "Started tracking installation of: $component"
}

# Mark component installation as completed
complete_component() {
    local component="$1"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    # Update status to completed
    if [[ -f "$tracking_file" ]]; then
        grep -v "^${component}:" "$tracking_file" > "${tracking_file}.tmp" 2>/dev/null || true
        mv "${tracking_file}.tmp" "$tracking_file" 2>/dev/null || true
    fi
    
    echo "${component}:completed:$(date +%s)" >> "$tracking_file"
    
    log_success "Component installation completed: $component"
}

# Mark component installation as failed
fail_component() {
    local component="$1"
    local reason="${2:-Installation failed}"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    # Update status to failed
    if [[ -f "$tracking_file" ]]; then
        grep -v "^${component}:" "$tracking_file" > "${tracking_file}.tmp" 2>/dev/null || true
        mv "${tracking_file}.tmp" "$tracking_file" 2>/dev/null || true
    fi
    
    echo "${component}:failed:$(date +%s):$reason" >> "$tracking_file"
    
    log_error "Component installation failed: $component - $reason"
}

# Skip component installation
skip_component() {
    local component="$1"
    local reason="${2:-Skipped by user}"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    echo "${component}:skipped:$(date +%s):$reason" >> "$tracking_file"
    
    log_warning "Component installation skipped: $component - $reason"
}

# Get component status
get_component_status() {
    local component="$1"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    if [[ -f "$tracking_file" ]]; then
        grep "^${component}:" "$tracking_file" | tail -1 | cut -d: -f2 2>/dev/null || echo "not-found"
    else
        echo "not-found"
    fi
}

# Check if component installation was successful
is_component_successful() {
    local component="$1"
    local status=$(get_component_status "$component")
    [[ "$status" == "completed" ]]
}

# Get component installation time
get_component_time() {
    local component="$1"
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    if [[ -f "$tracking_file" ]]; then
        local entry=$(grep "^${component}:" "$tracking_file" | tail -1)
        local timestamp=$(echo "$entry" | cut -d: -f3 2>/dev/null)
        if [[ -n "$timestamp" && "$timestamp" != "" ]]; then
            date -d "@$timestamp" 2>/dev/null || echo "Unknown"
        else
            echo "Unknown"
        fi
    else
        echo "Unknown"
    fi
}

# Show installation summary for all components
show_installation_summary() {
    local tracking_file="${GOK_CACHE_DIR}/component_status"
    
    log_header "Installation Summary"
    
    if [[ ! -f "$tracking_file" ]]; then
        log_info "No component installations tracked yet"
        return 0
    fi
    
    # Group components by status
    local completed=()
    local failed=()
    local in_progress=()
    local skipped=()
    
    while IFS=':' read -r component status timestamp reason; do
        case "$status" in
            "completed")
                completed+=("$component")
                ;;
            "failed")
                failed+=("$component")
                ;;
            "in-progress")
                in_progress+=("$component")
                ;;
            "skipped")
                skipped+=("$component")
                ;;
        esac
    done < "$tracking_file"
    
    # Display summary
    if [[ ${#completed[@]} -gt 0 ]]; then
        log_success "Completed (${#completed[@]}): ${completed[*]}"
    fi
    
    if [[ ${#in_progress[@]} -gt 0 ]]; then
        log_warning "In Progress (${#in_progress[@]}): ${in_progress[*]}"
    fi
    
    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "Failed (${#failed[@]}): ${failed[*]}"
    fi
    
    if [[ ${#skipped[@]} -gt 0 ]]; then
        log_info "Skipped (${#skipped[@]}): ${skipped[*]}"
    fi
    
    if [[ ${#completed[@]} -eq 0 && ${#failed[@]} -eq 0 && ${#in_progress[@]} -eq 0 && ${#skipped[@]} -eq 0 ]]; then
        log_info "No component installations found"
    fi
}