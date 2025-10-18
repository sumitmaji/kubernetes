#!/bin/bash
# Main installation script for gok-agent (copied/merged from original gok install).
# This handles the core install, then sources sub-modules for validation, summaries, guidance, and reset.

# Function to build gok-agent with progress tracking (similar to build_vault_with_progress)
build_gok_agent_with_progress() {
    local agent_dir="${MOUNT_PATH}/kubernetes/install_k8s/gok-cloud/agent"
    local temp_build_log=$(mktemp)
    local temp_build_error=$(mktemp)
    local temp_tag_log=$(mktemp)
    local temp_tag_error=$(mktemp)
    local temp_push_log=$(mktemp)
    local temp_push_error=$(mktemp)

    log_substep "Building gok-agent Docker image"

    # Change to agent directory
    if ! pushd "$agent_dir" >/dev/null 2>&1; then
        log_error "Could not access gok-agent directory: $agent_dir"
        return 1
    fi

    # Store GOK modular registry URL before sourcing old config  
    local gok_registry_url
    if [[ -n "$REGISTRY" && -n "$GOK_ROOT_DOMAIN" ]]; then
        gok_registry_url="${REGISTRY}.${GOK_ROOT_DOMAIN}"
    else
        gok_registry_url=$(fullRegistryUrl 2>/dev/null || echo "localhost:5000")
    fi

    # Source configuration files
    if [[ -f "config/config" ]]; then
        source config/config
    fi
    if [[ -f "configuration" ]]; then
        source configuration
    fi
    source "$MOUNT_PATH/kubernetes/install_k8s/util"

    # Start Docker build in background
    {
        docker build --build-arg LDAP_DOMAIN="$DOMAIN_NAME" \
             --build-arg REGISTRY="$gok_registry_url" \
             --build-arg LDAP_HOSTNAME="$LDAP_HOSTNAME" \
             --build-arg BASE_DN="$DC" \
             --build-arg LDAP_PASSWORD=sumit \
             -t "$IMAGE_NAME" . >"$temp_build_log" 2>"$temp_build_error"
        echo $? > /tmp/gok_agent_build_exit_code
    } &
    local build_pid=$!

    # Progress tracking for build
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local spinner_idx=0
    local build_progress=0
    local build_stage="Initializing build"

    while kill -0 $build_pid 2>/dev/null; do
        # Update progress based on time elapsed (simulated progress)
        build_progress=$((build_progress + 2))
        if [[ $build_progress -gt 100 ]]; then
            build_progress=100
        fi

        # Update stage based on progress
        case $((build_progress / 20)) in
            0) build_stage="Preparing build context" ;;
            1) build_stage="Downloading base image" ;;
            2) build_stage="Installing dependencies" ;;
            3) build_stage="Copying application code" ;;
            4) build_stage="Finalizing build" ;;
        esac

        local char=${spinner_chars:spinner_idx:1}
        printf "\r${COLOR_MAGENTA}  Building gok-agent [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$build_progress" "$build_stage"

        spinner_idx=$(( (spinner_idx + 1) % 10 ))
        sleep 0.3
    done

    # Wait for build to complete
    wait $build_pid
    local build_exit_code=$(cat /tmp/gok_agent_build_exit_code 2>/dev/null || echo 1)
    rm -f /tmp/gok_agent_build_exit_code

    if [[ $build_exit_code -eq 0 ]]; then
        printf "\r${COLOR_GREEN}  ✓ Gok-agent build completed [100%%]${COLOR_RESET}\n"
        log_success "Gok-agent Docker image built successfully"
    else
        printf "\r${COLOR_RED}  ✗ Gok-agent build failed${COLOR_RESET}\n"
        log_error "Gok-agent build failed - error details:"
        if [[ -s "$temp_build_error" ]]; then
            cat "$temp_build_error" >&2
        fi
        popd >/dev/null 2>&1
        rm -f "$temp_build_log" "$temp_build_error" "$temp_tag_log" "$temp_tag_error" "$temp_push_log" "$temp_push_error"
        return 1
    fi

    log_substep "Tagging gok-agent image for registry"

    # Start Docker tag in background
    {
        docker tag "$IMAGE_NAME" "$gok_registry_url/$REPO_NAME" >"$temp_tag_log" 2>"$temp_tag_error"
        echo $? > /tmp/gok_agent_tag_exit_code
    } &
    local tag_pid=$!

    # Progress tracking for tag
    local tag_progress=0
    local tag_stage="Tagging image"
    spinner_idx=0

    while kill -0 $tag_pid 2>/dev/null; do
        tag_progress=$((tag_progress + 10))
        if [[ $tag_progress -gt 100 ]]; then
            tag_progress=100
        fi

        case $((tag_progress / 50)) in
            0) tag_stage="Preparing tag" ;;
            1) tag_stage="Applying registry tag" ;;
        esac

        local char=${spinner_chars:spinner_idx:1}
        printf "\r${COLOR_MAGENTA}  Tagging gok-agent [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$tag_progress" "$tag_stage"

        spinner_idx=$(( (spinner_idx + 1) % 10 ))
        sleep 0.2
    done

    wait $tag_pid
    local tag_exit_code=$(cat /tmp/gok_agent_tag_exit_code 2>/dev/null || echo 1)
    rm -f /tmp/gok_agent_tag_exit_code

    if [[ $tag_exit_code -eq 0 ]]; then
        printf "\r${COLOR_GREEN}  ✓ Gok-agent tagging completed [100%%]${COLOR_RESET}\n"
        log_success "Gok-agent image tagged for registry"
    else
        printf "\r${COLOR_RED}  ✗ Gok-agent tagging failed${COLOR_RESET}\n"
        log_error "Gok-agent tagging failed - error details:"
        if [[ -s "$temp_tag_error" ]]; then
            cat "$temp_tag_error" >&2
        fi
        popd >/dev/null 2>&1
        rm -f "$temp_build_log" "$temp_build_error" "$temp_tag_log" "$temp_tag_error" "$temp_push_log" "$temp_push_error"
        return 1
    fi

    log_substep "Pushing gok-agent image to registry"

    # Start Docker push in background
    {
        docker push "$gok_registry_url/$REPO_NAME" >"$temp_push_log" 2>"$temp_push_error"
        echo $? > /tmp/gok_agent_push_exit_code
    } &
    local push_pid=$!

    # Progress tracking for push
    local push_progress=0
    local push_stage="Preparing push"
    spinner_idx=0

    while kill -0 $push_pid 2>/dev/null; do
        push_progress=$((push_progress + 1))
        if [[ $push_progress -gt 100 ]]; then
            push_progress=100
        fi

        # Update stage based on progress
        case $((push_progress / 20)) in
            0) push_stage="Preparing layers" ;;
            1) push_stage="Uploading base system" ;;
            2) push_stage="Uploading application" ;;
            3) push_stage="Uploading configuration" ;;
            4) push_stage="Finalizing push" ;;
        esac

        local char=${spinner_chars:spinner_idx:1}
        printf "\r${COLOR_MAGENTA}  Pushing gok-agent [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$push_progress" "$push_stage"

        spinner_idx=$(( (spinner_idx + 1) % 10 ))
        sleep 0.4
    done

    wait $push_pid
    local push_exit_code=$(cat /tmp/gok_agent_push_exit_code 2>/dev/null || echo 1)
    rm -f /tmp/gok_agent_push_exit_code

    if [[ $push_exit_code -eq 0 ]]; then
        printf "\r${COLOR_GREEN}  ✓ Gok-agent push completed [100%%] - Image available at ${COLOR_BOLD}$gok_registry_url/$REPO_NAME${COLOR_RESET}\n"
        log_success "Gok-agent image pushed successfully to registry"
    else
        printf "\r${COLOR_RED}  ✗ Gok-agent push failed${COLOR_RESET}\n"
        log_error "Gok-agent push failed - error details:"
        if [[ -s "$temp_push_error" ]]; then
            cat "$temp_push_error" >&2
        fi
        popd >/dev/null 2>&1
        rm -f "$temp_build_log" "$temp_build_error" "$temp_tag_log" "$temp_tag_error" "$temp_push_log" "$temp_push_error"
        return 1
    fi

    # Return to original directory
    popd >/dev/null 2>&1

    # Clean up temp files
    rm -f "$temp_build_log" "$temp_build_error" "$temp_tag_log" "$temp_tag_error" "$temp_push_log" "$temp_push_error"

    return 0
}

# Function to install gok-agent (copied from original install section)
install_gok_agent() {
    log_component_start "gok-agent" "Installing gok-agent component with Docker image build and Kubernetes deployment"

    # Build and push gok-agent with progress tracking
    if ! build_gok_agent_with_progress; then
        log_component_error "gok-agent" "Failed to build and push gok-agent image"
        return 1
    fi

    log_substep "Setting up gok-agent namespace and configuration"

    # Create namespace for gok-agent
    if execute_with_suppression kubectl create namespace gok-agent; then
        log_success "Gok-agent namespace created successfully"
    else
        log_warning "Gok-agent namespace creation had issues (may already exist)"
    fi

    # Create CA certificate configmap
    if execute_with_suppression kubectl create configmap ca-cert --from-file=issuer.crt=/usr/local/share/ca-certificates/issuer.crt -n gok-agent; then
        log_success "CA certificate configmap created for gok-agent"
    else
        log_warning "CA certificate configmap creation had issues"
    fi

    log_substep "Deploying gok-agent via Helm chart"

    # Install gok-agent using Helm
    if execute_with_suppression helm install gok-agent ${MOUNT_PATH}/kubernetes/install_k8s/gok-cloud/agent/chart --namespace gok-agent; then
        log_success "Gok-agent Helm chart deployed successfully"
    else
        log_component_error "gok-agent" "Failed to deploy gok-agent Helm chart"
        return 1
    fi

    log_component_success "gok-agent" "Gok-agent installation completed successfully - component is ready for use"
}

export -f install_gok_agent
export -f build_gok_agent_with_progress
