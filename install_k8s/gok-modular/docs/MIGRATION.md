# Migration Guide: From Monolithic GOK to Modular GOK

## Overview

This guide helps you migrate from the original monolithic `gok` script (21,365 lines) to the new modular architecture while maintaining full backward compatibility.

## Migration Timeline

### Phase 1: Parallel Installation (Week 1)
- Install modular GOK alongside original
- Test basic functionality
- Verify command compatibility

### Phase 2: Feature Validation (Week 2-3)
- Test all components you currently use
- Validate configuration compatibility
- Update automation scripts

### Phase 3: Team Training (Week 4)
- Train team on new structure
- Update documentation references
- Create new workflows

### Phase 4: Full Migration (Week 5+)
- Replace original with modular version
- Update symbolic links
- Archive original version

## Step-by-Step Migration

### 1. Backup Current Setup

```bash
# Backup your current GOK installation
cp gok gok.backup.$(date +%Y%m%d)

# Backup configuration
cp -r config config.backup.$(date +%Y%m%d) 2>/dev/null || true

# Export current environment variables
env | grep -E "(ROOT_DOMAIN|IDENTITY_PROVIDER|CERTMANAGER)" > current_config.env
```

### 2. Install Modular GOK

```bash
# Navigate to the modular directory
cd gok-modular

# Make executable
chmod +x gok-new

# Test basic functionality
./gok-new --help
```

### 3. Configuration Migration

```bash
# Copy your existing config values to modular config
# Edit config/default.conf with your settings

# If you have custom environment variables, add them to:
vim config/default.conf
```

### 4. Validate Functionality

```bash
# Test with verbose output to see what's happening
./gok-new install --help --verbose

# Test a simple command
./gok-new status

# Test component listing
./gok-new help components
```

### 5. Side-by-Side Comparison

Run the same command with both versions to ensure compatibility:

```bash
# Original version
./gok help

# Modular version  
./gok-new help

# Compare outputs
```

### 6. Update Scripts and Aliases

```bash
# Update your aliases
echo "alias gok='$PWD/gok-new'" >> ~/.bashrc

# Update scripts that call gok
find . -name "*.sh" -exec grep -l "\\./gok " {} \; | while read script; do
    echo "Update script: $script"
done
```

## Compatibility Matrix

| Feature | Original GOK | Modular GOK | Status |
|---------|-------------|-------------|---------|
| Basic commands | ✓ | ✓ | ✅ Compatible |
| Component installation | ✓ | ✓ | ✅ Compatible |
| Environment variables | ✓ | ✓ | ✅ Compatible |
| Configuration files | ✓ | ✓ | ✅ Enhanced |
| Remote operations | ✓ | ⚠️ | 🔄 In Progress |
| Custom functions | ✓ | ⚠️ | 📝 Manual Migration |

## Command Mapping

All original commands are supported. Here's the mapping:

```bash
# Original → Modular (same commands work)
gok install kubernetes → gok-new install kubernetes  
gok reset monitoring   → gok-new reset monitoring
gok help              → gok-new help
gok status            → gok-new status
```

## Configuration Migration

### Environment Variables

```bash
# Original variables (still supported)
export ROOT_DOMAIN="example.com"
export IDENTITY_PROVIDER="keycloak" 
export CERTMANAGER_CHALLENGE_TYPE="http01"

# New modular config (recommended)
# Edit config/default.conf:
ROOT_DOMAIN="example.com"
IDENTITY_PROVIDER="keycloak"
CERTMANAGER_CHALLENGE_TYPE="http01"
```

### Custom Functions

If you added custom functions to the original GOK:

1. **Identify custom functions**:
   ```bash
   # Compare with original to find your additions
   diff gok.backup gok | grep "^>"
   ```

2. **Create new module**:
   ```bash
   # Create custom module
   vim gok-modular/lib/components/custom/my-functions.sh
   ```

3. **Add your functions**:
   ```bash
   # Add your custom installation functions
   myCustomComponentInst() {
       log_component_start "my-component" "Installing custom component"
       # Your logic here
       log_component_success "my-component"
   }
   ```

4. **Register in install command**:
   ```bash
   # Edit lib/commands/install.sh
   "my-component")
       myCustomComponentInst
       ;;
   ```

## Testing Checklist

### Basic Functionality
- [ ] `./gok-new --help` displays help
- [ ] `./gok-new help components` lists components  
- [ ] `./gok-new status` shows system status
- [ ] Configuration loads without errors

### Component Installation
- [ ] Test installing a simple component (e.g., helm)
- [ ] Verify logging output is clear and helpful
- [ ] Check that installation tracking works
- [ ] Validate error handling and rollback

### Advanced Features  
- [ ] Remote operations (if used)
- [ ] Custom components (if any)
- [ ] Automation scripts integration
- [ ] Backup and restore procedures

## Rollback Plan

If issues occur during migration:

### Quick Rollback
```bash
# Restore original
mv gok.backup.$(date +%Y%m%d) gok
chmod +x gok

# Verify functionality
./gok --help
```

### Partial Rollback
```bash
# Use original for specific functions
./gok install kubernetes          # Use original for known-working components
./gok-new help                   # Use modular for documentation
```

## Performance Comparison

### Loading Time
```bash
# Measure load time
time ./gok help >/dev/null         # Original
time ./gok-new help >/dev/null     # Modular
```

### Memory Usage
```bash
# Check memory usage during installation
./gok install kubernetes &
ps aux | grep gok

./gok-new install kubernetes &  
ps aux | grep gok-new
```

## Troubleshooting Migration Issues

### Module Loading Errors
```bash
# Check module syntax
find gok-modular/lib -name "*.sh" -exec bash -n {} \;

# Verify bootstrap process
bash -x ./gok-new help 2>&1 | head -20
```

### Configuration Issues  
```bash
# Check config loading
./gok-new --verbose help | grep -i config

# Verify environment variables
./gok-new --verbose status | grep -i environment
```

### Function Not Found
```bash
# Check if function exists in modules
grep -r "myFunction" gok-modular/lib/

# Add missing function to appropriate module
```

## Post-Migration Tasks

### 1. Update Documentation
- Update team wiki/docs with new commands
- Create quick reference cards
- Document new module structure

### 2. Update Automation
- Modify CI/CD scripts to use modular version
- Update deployment scripts
- Test automated workflows

### 3. Monitoring
- Monitor system performance
- Track error rates
- Collect user feedback

### 4. Cleanup
```bash
# After successful migration (keep backup for a while)
# mv gok.backup.* /backup/archived/
# rm -rf old_config.backup.*
```

## Benefits After Migration

### Immediate Benefits
- **Better Error Messages**: More specific and helpful
- **Improved Performance**: Faster loading of specific modules
- **Enhanced Logging**: Better visibility into operations
- **Easier Debugging**: Isolated module testing

### Long-term Benefits  
- **Easier Maintenance**: Focused, manageable modules
- **Better Testing**: Component-level testing
- **Team Collaboration**: Multiple developers can work simultaneously
- **Feature Development**: Faster addition of new components

## Support and Help

### Getting Help
- Use `./gok-new help` for comprehensive documentation
- Check `docs/README.md` for detailed architecture information
- Report issues via the original repository

### Community
- Share migration experiences with the team
- Document custom components for reuse
- Contribute improvements back to the project

## Success Criteria

Migration is successful when:
- [ ] All current workflows function identically
- [ ] Team is comfortable with new structure
- [ ] Performance is equal or better
- [ ] Error handling is improved
- [ ] No critical functionality is lost

---

**Remember**: The modular version maintains 100% backward compatibility. Take your time with the migration and test thoroughly in a non-production environment first.