# Spinner Logging Feature

The GOK system now includes spinner functionality for better user experience during long-running operations.

## Functions

### `execute_with_spinner`

Execute a command with a visual spinner indicating progress.

```bash
execute_with_spinner "Installing package" apt-get install -y nginx
```

**Parameters:**
- `$1`: Message to display during execution
- `$2+`: Command and arguments to execute

**Behavior:**
- Shows animated spinner while command runs
- Displays success/error message based on exit code
- Respects verbosity settings (no spinner in quiet mode)

### `execute_with_spinner_custom`

Execute a command with spinner and custom success/failure messages.

```bash
execute_with_spinner_custom "Running test" "Test passed!" "Test failed!" ./run_tests.sh
```

**Parameters:**
- `$1`: Message to display during execution
- `$2`: Custom success message (optional)
- `$3`: Custom failure message (optional)
- `$4+`: Command and arguments to execute

## Spinner Animation

The spinner uses Unicode characters that animate in sequence:
- ⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏

## Verbosity Integration

- **Normal verbosity**: Shows spinner animation
- **Verbose mode**: Shows detailed command output instead of spinner
- **Quiet mode**: No spinner, minimal output
- **Debug mode**: Shows spinner with debug information

## Examples

```bash
# Basic usage
execute_with_spinner "Updating packages" apt-get update

# With custom messages
execute_with_spinner_custom "Building application" "Build completed successfully" "Build failed" make all

# In scripts
if execute_with_spinner "Deploying to Kubernetes" kubectl apply -f deployment.yaml; then
    log_info "Deployment successful"
fi
```

## Integration with Existing Code

The spinner functions integrate seamlessly with the existing GOK logging and verbosity systems. They automatically respect the current verbosity level and logging configuration.