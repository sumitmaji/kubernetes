#!/bin/bash
# Main installation script for gok-controller (copied/merged from original gok install).
# This handles the core install, then sources sub-modules for validation, summaries, guidance, and reset.

# Function to build gok-controller with progress tracking (similar to build_vault_with_progress)
build_gok_controller_with_progress() {
    local controller_dir="${MOUNT_PATH}/kubernetes/install_k8s/gok-cloud/controller"
    local temp_build_log=$(mktemp)
    local temp_build_error=$(mktemp)
    local temp_tag_log=$(mktemp)
    local temp_tag_error=$(mktemp)
    local temp_push_log=$(mktemp)
    local temp_push_error=$(mktemp)

    log_substep "Building gok-controller Docker image"

    # Change to controller directory
    if ! pushd "$controller_dir" >/dev/null 2>&1; then
        log_error "Could not access gok-controller directory: $controller_dir"
        return 1
    fi

    # Store GOK modular registry URL before sourcing old config  
    local gok_registry_url
    if [[ -n "$REGISTRY" && -n "$GOK_ROOT_DOMAIN" ]]; then
        gok_registry_url="${REGISTRY}.${GOK_ROOT_DOMAIN}"
    else
        gok_registry_url=$(fullRegistryUrl 2>/dev/null || echo "localhost:5000")
    fi

    # Get registry and image information
    local registry_url="${gok_registry_url}"
    local image_name="${IMAGE_NAME:-gok-controller}"
    local repo_name="${REPO_NAME:-gok-controller}"
    local full_image_url="${registry_url}/${repo_name}"

    log_substep "Registry: ${COLOR_CYAN}${registry_url}${COLOR_RESET}"
    log_substep "Image: ${COLOR_CYAN}${image_name}${COLOR_RESET}"
    log_substep "Target: ${COLOR_CYAN}${full_image_url}${COLOR_RESET}"

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
        echo $? > /tmp/gok_controller_build_exit_code
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
        printf "\r${COLOR_MAGENTA}  Building gok-controller [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$build_progress" "$build_stage"

        spinner_idx=$(( (spinner_idx + 1) % 10 ))
        sleep 0.3
    done

    # Wait for build to complete
    wait $build_pid
    local build_exit_code=$(cat /tmp/gok_controller_build_exit_code 2>/dev/null || echo 1)
    rm -f /tmp/gok_controller_build_exit_code

    if [[ $build_exit_code -eq 0 ]]; then
        printf "\r${COLOR_GREEN}  ✓ Gok-controller build completed [100%%]${COLOR_RESET}\n"
        log_success "Gok-controller Docker image built successfully"
    else
        printf "\r${COLOR_RED}  ✗ Gok-controller build failed${COLOR_RESET}\n"
        log_error "Gok-controller build failed - error details:"
        if [[ -s "$temp_build_error" ]]; then
            cat "$temp_build_error" >&2
        fi
        popd >/dev/null 2>&1
        rm -f "$temp_build_log" "$temp_build_error" "$temp_tag_log" "$temp_tag_error" "$temp_push_log" "$temp_push_error"
        return 1
    fi

    log_substep "Tagging gok-controller image for registry"

    # Start Docker tag in background
    {
        docker tag "$IMAGE_NAME" "$gok_registry_url/$REPO_NAME" >"$temp_tag_log" 2>"$temp_tag_error"
        echo $? > /tmp/gok_controller_tag_exit_code
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
        printf "\r${COLOR_MAGENTA}  Tagging gok-controller [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$tag_progress" "$tag_stage"

        spinner_idx=$(( (spinner_idx + 1) % 10 ))
        sleep 0.2
    done

    wait $tag_pid
    local tag_exit_code=$(cat /tmp/gok_controller_tag_exit_code 2>/dev/null || echo 1)
    rm -f /tmp/gok_controller_tag_exit_code

    if [[ $tag_exit_code -eq 0 ]]; then
        printf "\r${COLOR_GREEN}  ✓ Gok-controller tagging completed [100%%]${COLOR_RESET}\n"
        log_success "Gok-controller image tagged for registry"
    else
        printf "\r${COLOR_RED}  ✗ Gok-controller tagging failed${COLOR_RESET}\n"
        log_error "Gok-controller tagging failed - error details:"
        if [[ -s "$temp_tag_error" ]]; then
            cat "$temp_tag_error" >&2
        fi
        popd >/dev/null 2>&1
        rm -f "$temp_build_log" "$temp_build_error" "$temp_tag_log" "$temp_tag_error" "$temp_push_log" "$temp_push_error"
        return 1
    fi

    log_substep "Pushing gok-controller image to registry"

    # Start Docker push in background
    {
        docker push "$gok_registry_url/$REPO_NAME" >"$temp_push_log" 2>"$temp_push_error"
        echo $? > /tmp/gok_controller_push_exit_code
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
        printf "\r${COLOR_MAGENTA}  Pushing gok-controller [%c] ${COLOR_CYAN}%d%%${COLOR_RESET} - ${COLOR_DIM}%s${COLOR_RESET}" "$char" "$push_progress" "$push_stage"

        spinner_idx=$(( (spinner_idx + 1) % 10 ))
        sleep 0.4
    done

    wait $push_pid
    local push_exit_code=$(cat /tmp/gok_controller_push_exit_code 2>/dev/null || echo 1)
    rm -f /tmp/gok_controller_push_exit_code

    if [[ $push_exit_code -eq 0 ]]; then
        printf "\r${COLOR_GREEN}  ✓ Gok-controller push completed [100%%] - Image available at ${COLOR_BOLD}$gok_registry_url/$REPO_NAME${COLOR_RESET}\n"
        log_success "Gok-controller image pushed successfully to registry"
    else
        printf "\r${COLOR_RED}  ✗ Gok-controller push failed${COLOR_RESET}\n"
        log_error "Gok-controller push failed - error details:"
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

# Function to install gok-controller (copied from original install section)
install_gok_controller() {
    log_component_start "gok-controller" "Installing gok-controller component with Docker image build and Kubernetes deployment"

    # Build and push gok-controller with progress tracking
    if ! build_gok_controller_with_progress; then
        log_component_error "gok-controller" "Failed to build and push gok-controller image"
        return 1
    fi

    log_substep "Setting up gok-controller namespace and configuration"

    # Create namespace for gok-controller
    if execute_with_suppression kubectl create namespace gok-controller; then
        log_success "Gok-controller namespace created successfully"
    else
        log_warning "Gok-controller namespace creation had issues (may already exist)"
    fi

    # Create CA certificate configmap
    if execute_with_suppression kubectl create configmap ca-cert --from-file=issuer.crt=/usr/local/share/ca-certificates/issuer.crt -n gok-controller; then
        log_success "CA certificate configmap created for gok-controller"
    else
        log_warning "CA certificate configmap creation had issues"
    fi

    log_substep "Deploying gok-controller via Helm chart"

    # Install gok-controller using Helm
    if execute_with_suppression helm install gok-controller ${MOUNT_PATH}/kubernetes/install_k8s/gok-cloud/controller/chart --namespace gok-controller; then
        log_success "Gok-controller Helm chart deployed successfully"
    else
        log_component_error "gok-controller" "Failed to deploy gok-controller Helm chart"
        return 1
    fi

    log_substep "Configuring ingress with Let's Encrypt and OAuth"

    # Patch the ingress with Let's Encrypt
    if execute_with_suppression gok patch ingress gok-controller gok-controller letsencrypt controller; then
        log_success "Gok-controller ingress patched with Let's Encrypt"
    else
        log_error "Failed to patch Gok-controller ingress with Let's Encrypt"
        return 1
    fi

    # Apply OAuth configuration
    if execute_with_suppression patchControllerWithOauth; then
        log_success "Gok-controller OAuth configuration applied successfully"
        log_component_success "gok-controller" "Gok-controller installation completed successfully - access at https://controller.$(rootDomain)"
    else
        log_component_error "gok-controller" "Failed to apply OAuth configuration"
        return 1
    fi
}
export -f install_gok_controller
export -f build_gok_controller_with_progress