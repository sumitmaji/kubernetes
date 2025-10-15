#!/bin/bash

# Script to audit GOK components for --show-commands support
# This script scans component files to identify direct command executions that need show_command support

echo "============================================"
echo "GOK Components --show-commands Audit"
echo "============================================"
echo ""

COMPONENTS_DIR="/home/sumit/Documents/repository/kubernetes/install_k8s/gok-modular/lib/components"
TOTAL_ISSUES=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "Scanning components directory: $COMPONENTS_DIR"
echo ""

# Function to check a file for direct command executions
check_file() {
    local file="$1"
    local relative_path="${file#$COMPONENTS_DIR/}"
    local issues=0
    
    # Check for docker commands not using show_command
    local docker_count=$(grep -n "^\s*docker \(build\|tag\|push\|pull\)" "$file" 2>/dev/null | grep -v "show_command" | wc -l)
    
    # Check for helm commands not using show_command or execute_with_suppression
    local helm_count=$(grep -n "^\s*helm \(install\|upgrade\|repo\)" "$file" 2>/dev/null | grep -v "show_command" | grep -v "execute_with_suppression" | wc -l)
    
    # Check for kubectl commands not using execute_with_suppression
    local kubectl_count=$(grep -n "^\s*kubectl " "$file" 2>/dev/null | grep -v "execute_with_suppression" | wc -l)
    
    # Check for shell script executions
    local bash_count=$(grep -n "^\s*bash \|^\s*sh \|^\s*\./[a-zA-Z]" "$file" 2>/dev/null | grep -v "show_command" | grep -v "execute_with_suppression" | wc -l)
    
    issues=$((docker_count + helm_count + kubectl_count + bash_count))
    
    if [[ $issues -gt 0 ]]; then
        echo -e "${YELLOW}📄 $relative_path${NC}"
        
        if [[ $docker_count -gt 0 ]]; then
            echo -e "  ${RED}  ❌ Docker commands: $docker_count${NC}"
            grep -n "^\s*docker \(build\|tag\|push\|pull\)" "$file" 2>/dev/null | grep -v "show_command" | head -3 | while read -r line; do
                echo -e "     ${BLUE}$line${NC}"
            done
        fi
        
        if [[ $helm_count -gt 0 ]]; then
            echo -e "  ${RED}  ❌ Helm commands: $helm_count${NC}"
            grep -n "^\s*helm \(install\|upgrade\|repo\)" "$file" 2>/dev/null | grep -v "show_command" | grep -v "execute_with_suppression" | head -3 | while read -r line; do
                echo -e "     ${BLUE}$line${NC}"
            done
        fi
        
        if [[ $kubectl_count -gt 0 ]]; then
            echo -e "  ${RED}  ❌ kubectl commands: $kubectl_count${NC}"
            grep -n "^\s*kubectl " "$file" 2>/dev/null | grep -v "execute_with_suppression" | head -3 | while read -r line; do
                echo -e "     ${BLUE}$line${NC}"
            done
        fi
        
        if [[ $bash_count -gt 0 ]]; then
            echo -e "  ${RED}  ❌ Script executions: $bash_count${NC}"
            grep -n "^\s*bash \|^\s*sh \|^\s*\./[a-zA-Z]" "$file" 2>/dev/null | grep -v "show_command" | grep -v "execute_with_suppression" | head -3 | while read -r line; do
                echo -e "     ${BLUE}$line${NC}"
            done
        fi
        
        echo ""
    else
        echo -e "${GREEN}✅ $relative_path - No issues found${NC}"
    fi
    
    return $issues
}

# Scan all component files
echo "Scanning component files..."
echo ""

for file in $(find "$COMPONENTS_DIR" -name "*.sh" -type f); do
    check_file "$file"
    TOTAL_ISSUES=$((TOTAL_ISSUES + $?))
done

echo ""
echo "============================================"
echo "Audit Summary"
echo "============================================"
if [[ $TOTAL_ISSUES -eq 0 ]]; then
    echo -e "${GREEN}✅ All components properly support --show-commands${NC}"
else
    echo -e "${RED}❌ Found $TOTAL_ISSUES command(s) that need show_command support${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review the developer guide: docs/DEVELOPER_GUIDE_SHOW_COMMANDS.md"
    echo "2. Add show_command or show_command_with_secrets before each flagged command"
    echo "3. Use execute_with_suppression for kubectl commands when possible"
    echo "4. Test with: ./gok-new install <component> --show-commands"
fi
echo ""
