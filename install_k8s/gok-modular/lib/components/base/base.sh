#!/bin/bash

# GOK Base Component - Core platform services and base infrastructure
# This component provides the foundational base platform with Docker images,
# caching systems, and essential utilities for the GOK platform

# Note: Utility modules are loaded by bootstrap, no need to source them here

# Simple test function
test_base_function() {
    echo "test_base_function called"
}

# Base platform installation function
basePlatformInst() {
    local start_time=$(date +%s)

    log_component_start "base" "Installing base platform services and infrastructure"
    start_component "base"

    # Step 3: Prepare base installation directory
    local base_dir="${GOK_ROOT}/../base"
    if [[ ! -d "$base_dir" ]]; then
        log_error "Base installation directory not found: $base_dir"
        fail_component "base" "Base directory not found"
        return 1
    fi

    if execute_with_suppression pushd "$base_dir"; then
        log_success "Base installation directory prepared"
    else
        log_error "Failed to access base installation directory"
        fail_component "base" "Directory access failed"
        return 1
    fi

    # Step 4: Set executable permissions for base scripts
    if execute_with_suppression find . -type f -name "*.sh" -exec chmod +x {} \;; then
        log_success "Executable permissions set for base scripts"
    else
        log_error "Failed to set executable permissions"
        popd || true
        fail_component "base" "Permission setup failed"
        return 1
    fi

    # Step 5: Build and install base platform components
    log_step "5" "Building and installing base platform components"
    if ! build_base_platform_with_progress; then
        log_error "Base platform build failed"
        popd || true
        fail_component "base" "Build failed"
        return 1
    fi

    # Step 6: Validate base platform installation
    log_step "6" "Validating base platform installation"
    if validate_base_installation; then
        log_success "Base platform installation validation completed"
    else
        log_warning "Base validation had issues but installation may still work"
    fi

    # Step 7: Complete base installation cleanup
    if execute_with_suppression popd; then
        log_success "Base installation directory cleanup completed"
    else
        log_warning "Directory cleanup had issues but installation completed"
    fi

    # Create installation marker
    if kubectl get configmap base-config -n kube-system >/dev/null 2>&1; then
        log_info "Updating existing base installation marker"
        execute_with_suppression kubectl patch configmap base-config -n kube-system --patch "{\"data\":{\"updated\":\"$(date)\",\"version\":\"modular\"}}"
    else
        if execute_with_suppression kubectl create configmap base-config \
            --from-literal=installed="$(date)" \
            --from-literal=version="modular" \
            --from-literal=caching-enabled="true" \
            -n kube-system; then
            log_success "Base installation marker created with metadata"
        else
            log_warning "Failed to create base installation marker (but installation completed successfully)"
        fi
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    show_base_summary
    log_component_success "base" "Base platform services installed successfully in ${duration}s"
    return 0
}

# Enhanced base platform build with detailed progress tracking
build_base_platform_with_progress() {
    local start_time=$(date +%s)

    # Source configuration to get image details
    if [[ ! -f "configuration" ]]; then
        log_error "Configuration file not found in base directory"
        return 1
    fi

    source configuration
    source "${GOK_ROOT}/../util" 2>/dev/null || true

    # Get registry information
    local registry_url=$(fullRegistryUrl 2>/dev/null || echo "localhost:5000")
    local image_name="${IMAGE_NAME:-gok-base}"
    local repo_name="${REPO_NAME:-gok-base}"
    local full_image_url="${registry_url}/${repo_name}"

    log_substep "Registry: ${registry_url}"
    log_substep "Image: ${image_name}"
    log_substep "Target: ${full_image_url}"

    # Step 1: Docker Build with Enhanced Progress
    log_info "Building base platform Docker image: ${image_name}"

    local temp_build_log=$(mktemp)
    local temp_build_error=$(mktemp)

    # Start Docker build in background with enhanced arguments
    docker build \
        --build-arg REGISTRY="$registry_url" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VERSION="modular" \
        -t "$image_name" . >"$temp_build_log" 2>"$temp_build_error" &
    local build_pid=$!

    # Show build progress with base-specific stages
    local build_progress=0
    local build_steps=10
    local spinner_chars="|/-\\"
    local spinner_idx=0
    local build_stage="Initializing"

    while kill -0 $build_pid 2>/dev/null; do
        local char=${spinner_chars:spinner_idx:1}
        build_progress=$(( (build_progress + 1) % (build_steps * 8) ))
        local progress_percent=$(( build_progress * 100 / (build_steps * 8) ))

        # Update stage based on progress
        case $((build_progress / 8)) in
            0) build_stage="Preparing Ubuntu base image" ;;
            1) build_stage="Installing system utilities" ;;
            2) build_stage="Setting up SSH server" ;;
            3) build_stage="Installing network tools" ;;
            4) build_stage="Adding Python runtime" ;;
            5) build_stage="Installing curl and wget" ;;
            6) build_stage="Copying platform scripts" ;;
            7) build_stage="Setting up permissions" ;;
            8) build_stage="Configuring volumes" ;;
            9) build_stage="Finalizing base image" ;;
        esac

        printf "\r  Building base image [%c] %d%% - %s" "$char" "$progress_percent" "$build_stage"

        spinner_idx=$(( (spinner_idx + 1) % 4 ))
        sleep 0.4
    done

    wait $build_pid
    local build_exit_code=$?

    if [[ $build_exit_code -eq 0 ]]; then
        printf "\r✓ Base platform Docker build completed [100%%]\n"
        log_success "Base platform Docker image built successfully: ${image_name}"

        # Show warnings if present but don't fail
        if is_verbose && [[ -s "$temp_build_log" ]]; then
            if grep -q "warning" "$temp_build_log"; then
                log_info "Build warnings (non-critical):"
                grep -i "warning" "$temp_build_log" | head -5 | while read line; do
                    log_warning "  $line"
                done
            fi
        fi
    else
        printf "\r✗ Base platform Docker build failed\n"
        log_error "Base platform Docker build failed - error details:"
        if [[ -s "$temp_build_error" ]]; then
            cat "$temp_build_error" >&2
        fi
        rm -f "$temp_build_log" "$temp_build_error"
        return 1
    fi

    # Step 2: Docker Tag
    log_info "Tagging image for registry: ${full_image_url}"
    if docker tag "$image_name" "$full_image_url" >/dev/null 2>&1; then
        log_success "Image tagged successfully"
    else
        log_error "Failed to tag Docker image"
        rm -f "$temp_build_log" "$temp_build_error"
        return 1
    fi

    # Step 3: Docker Push with Enhanced Progress
    log_info "Pushing base platform image to registry: ${registry_url}"
    log_substep "Target repository: ${repo_name}"

    # Start Docker push in background
    docker push "$full_image_url" >"$temp_build_log" 2>"$temp_build_error" &
    local push_pid=$!

    # Show enhanced push progress with base-specific stages
    local push_progress=0
    local push_steps=8
    local push_stage="Preparing"

    while kill -0 $push_pid 2>/dev/null; do
        local char=${spinner_chars:spinner_idx:1}
        push_progress=$(( (push_progress + 1) % (push_steps * 12) ))
        local progress_percent=$(( push_progress * 100 / (push_steps * 12) ))

        # Update stage based on progress
        case $((push_progress / 12)) in
            0) push_stage="Preparing base layers" ;;
            1) push_stage="Uploading Ubuntu base" ;;
            2) push_stage="Uploading system tools" ;;
            3) push_stage="Uploading Python runtime" ;;
            4) push_stage="Uploading platform scripts" ;;
            5) push_stage="Uploading configurations" ;;
            6) push_stage="Uploading final layers" ;;
            7) push_stage="Finalizing push" ;;
        esac

        printf "\r  Pushing base to registry [%c] %d%% - %s" "$char" "$progress_percent" "$push_stage"

        spinner_idx=$(( (spinner_idx + 1) % 4 ))
        sleep 0.4
    done

    wait $push_pid
    local push_exit_code=$?

    if [[ $push_exit_code -eq 0 ]]; then
        printf "\r✓ Base platform push completed [100%%] - Image available at ${full_image_url}\n"
        log_success "Base platform image pushed successfully to registry"
    else
        printf "\r✗ Base platform push failed\n"
        log_error "Base platform Docker push failed - error details:"
        if [[ -s "$temp_build_error" ]]; then
            if is_verbose; then
                cat "$temp_build_error" >&2
            else
                tail -10 "$temp_build_error" >&2
                log_info "Use --verbose flag to see full push logs"
            fi
        fi
        rm -f "$temp_build_log" "$temp_build_error"
        return 1
    fi

    # Clean up temporary files
    rm -f "$temp_build_log" "$temp_build_error"

    # Build completion summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_success "Base platform build completed in ${duration}s"

    # Show Dockerfile summary
    show_dockerfile_summary

    return 0
}

# Show comprehensive Dockerfile summary after build completion
show_dockerfile_summary() {
    log_info "Base Platform Dockerfile Summary"

    echo
    echo -e "${COLOR_BRIGHT_BLUE}🐳 Base Platform Container Details${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"

    echo -e "${COLOR_YELLOW}Base Image:${COLOR_RESET}"
    echo -e "  📦 ubuntu:trusty - Ubuntu 14.04 LTS (Trusty Tahr)"
    echo -e "     • Stable, long-term support base system"
    echo -e "     • Optimized for containerized environments"

    echo
    echo -e "${COLOR_YELLOW}Installed System Tools:${COLOR_RESET}"
    echo -e "  🔧 openssh-server & openssh-client - SSH connectivity and remote access"
    echo -e "  🌐 net-tools - Network utilities (ifconfig, netstat, route)"
    echo -e "  📡 iputils-ping - Network connectivity testing (ping command)"
    echo -e "  📥 curl - HTTP/HTTPS data transfer and API communication"
    echo -e "  📥 wget - File downloading and web content retrieval"
    echo -e "  🐍 python - Python runtime for scripting and automation"

    echo
    echo -e "${COLOR_YELLOW}Container Structure:${COLOR_RESET}"
    echo -e "  📁 /container/scripts/ - Platform initialization and setup scripts"
    echo -e "  📁 /usr/local/repository - Volume mount for persistent data"
    echo -e "     • Houses GOK platform configuration and state"
    echo -e "     • Shared across container lifecycle"

    echo
    echo -e "${COLOR_YELLOW}Container Features:${COLOR_RESET}"
    echo -e "  ✅ Minimal footprint - Optimized package selection with cleanup"
    echo -e "  ✅ Network-ready - Full networking stack for service communication"
    echo -e "  ✅ SSH-enabled - Remote access and management capabilities"
    echo -e "  ✅ Script automation - Custom setup and initialization scripts"
    echo -e "  ✅ Persistent storage - Volume support for data persistence"
    echo
}