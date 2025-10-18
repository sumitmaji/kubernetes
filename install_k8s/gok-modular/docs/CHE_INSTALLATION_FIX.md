# Eclipse Che Installation Fix - Chectl Installation Issue

## Problem
When installing Eclipse Che, the following error occurred:

```
[ERROR] ❌ Command execution failed
/bin/bash: oauth2Inst: line 95: syntax error near unexpected token `else'
/bin/bash: oauth2Inst: line 95: ` else'
/bin/bash: error importing function definition for `oauth2Inst'
/tmp/tmp.1veSA1vtmG: line 280: /usr/bin/env: Argument list too long
```

## Root Cause
The error "Argument list too long" occurs when trying to execute the chectl installation script through `execute_with_suppression`, which wraps the command in a temporary script file. The chectl installation script itself is large and when combined with all exported bash functions in the environment, it exceeds the system's ARG_MAX limit (typically 2MB on Linux).

The oauth2Inst syntax error is a red herring - it's actually caused by bash trying to import function definitions that got corrupted due to the ARG_MAX issue.

## Solution
Changed the chectl installation approach in `lib/components/development/che.sh`:

### Before (Problematic):
```bash
# Install Chectl
log_substep "Installing chectl CLI tool"
local temp_install_script=$(mktemp)

if curl -sL https://che-incubator.github.io/chectl/install.sh -o "$temp_install_script" 2>/dev/null; then
    chmod +x "$temp_install_script"
    if execute_with_suppression "$temp_install_script"; then
        log_success "Chectl installed successfully"
    else
        log_error "Chectl installation failed"
        rm -f "$temp_install_script"
        log_component_error "che" "Chectl installation failed"
        return 1
    fi
    rm -f "$temp_install_script"
fi
```

### After (Fixed):
```bash
# Install Chectl
log_substep "Installing chectl CLI tool"

# Check if chectl is already installed
if command -v chectl &>/dev/null; then
    log_info "Chectl is already installed: $(chectl version 2>/dev/null | head -n1)"
    log_success "Chectl CLI tool available"
else
    # Install chectl directly with bash pipe (not through execute_with_suppression to avoid arg length issues)
    if [[ "${GOK_VERBOSE:-false}" == "true" ]]; then
        bash <(curl -sL https://che-incubator.github.io/chectl/install.sh)
    else
        bash <(curl -sL https://che-incubator.github.io/chectl/install.sh) >/dev/null 2>&1
    fi
    
    if command -v chectl &>/dev/null; then
        log_success "Chectl installed successfully"
    else
        log_error "Chectl installation failed"
        log_component_error "che" "Chectl installation failed"
        return 1
    fi
fi
```

## Key Changes

1. **Skip installation if already present**: Check if `chectl` command exists before attempting installation
2. **Direct pipe execution**: Use `bash <(curl ...)` instead of downloading to a temp file and executing through `execute_with_suppression`
3. **Respect verbose mode**: Only suppress output when not in verbose mode
4. **Avoid ARG_MAX issue**: By not wrapping in `execute_with_suppression`, we don't create an additional layer that copies all environment variables

## Benefits

- ✅ Avoids "Argument list too long" error
- ✅ Simpler, more direct installation approach
- ✅ Faster execution (no temp file creation)
- ✅ Idempotent (skips if already installed)
- ✅ Respects verbose mode for debugging

## Testing

```bash
# Test installation
./gok-new install che

# Verify chectl is installed
chectl version

# Check Che status
./gok-new summary che
```

## Related Issues

This same pattern should be used for any large external installation scripts to avoid ARG_MAX limitations:
- Use direct bash pipe: `bash <(curl -sL URL)`
- Avoid `execute_with_suppression` for large external scripts
- Check for existing installation first (idempotency)

## System Limits

Check your system's ARG_MAX limit:
```bash
getconf ARG_MAX
# Typical output: 2097152 (2MB)
```

When bash exports all functions and variables, large environments can exceed this limit when creating new processes.

---
**Fix Applied**: October 18, 2025
**File Modified**: `lib/components/development/che.sh`
**Status**: ✅ Resolved
