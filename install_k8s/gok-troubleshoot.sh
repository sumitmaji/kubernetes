#!/bin/bash
# GOK Completion Troubleshooting Script
# This script helps diagnose and fix tab completion issues

echo "🔧 GOK Tab Completion Troubleshooting"
echo "====================================="
echo ""

# Check 1: Is bash completion available?
echo "📋 Check 1: Bash completion availability"
if shopt -q progcomp; then
    echo "✅ Programmable completion is enabled"
else
    echo "❌ Programmable completion is disabled"
    echo "💡 Fix: Run 'shopt -s progcomp'"
fi
echo ""

# Check 2: Is GOK completion registered?
echo "📋 Check 2: GOK completion registration"
if complete -p gok >/dev/null 2>&1; then
    echo "✅ GOK completion is registered"
    complete -p gok
else
    echo "❌ GOK completion is not registered"
    echo "💡 Fix: Run 'source gok-completion.sh'"
fi
echo ""

# Check 3: Does the completion function exist?
echo "📋 Check 3: Completion function availability"
if type _gok_enhanced_completion >/dev/null 2>&1; then
    echo "✅ Completion function exists"
else
    echo "❌ Completion function missing"
    echo "💡 Fix: Re-source the completion script"
fi
echo ""

# Check 4: Test the completion function
echo "📋 Check 4: Function testing"
echo "Testing: gok k8sSum completion..."

# Set up test environment
COMP_WORDS=("gok" "k8sSum")
COMP_CWORD=1
COMPREPLY=()

# Call the function
if type _gok_enhanced_completion >/dev/null 2>&1; then
    _gok_enhanced_completion
    if [ ${#COMPREPLY[@]} -gt 0 ]; then
        echo "✅ Completion works: ${COMPREPLY[@]}"
    else
        echo "❌ No completion results"
    fi
else
    echo "❌ Cannot test - function not available"
fi
echo ""

# Check 5: Test with compgen directly
echo "📋 Check 5: Direct compgen test"
result=$(compgen -W "k8sSummary ingressSummary k8sInst" "k8sSum" 2>/dev/null)
if [ -n "$result" ]; then
    echo "✅ Direct compgen works: $result"
else
    echo "❌ Direct compgen failed"
fi
echo ""

# Recommendations
echo "🚀 Recommendations:"
echo "==================="
echo ""
echo "If tab completion still doesn't work in your interactive shell:"
echo ""
echo "1. 🔄 Reload completion:"
echo "   source gok-completion.sh"
echo ""
echo "2. 🧪 Test in a new shell:"
echo "   bash -i"
echo "   source gok-completion.sh"
echo "   gok k8sSum<TAB>"
echo ""
echo "3. 📝 Check shell type:"
echo "   echo \$SHELL"
echo "   echo \$0"
echo ""
echo "4. 🛠️ Manual test:"
echo "   Type: gok k8s"
echo "   Then press TAB twice quickly"
echo ""
echo "5. 🔍 Debug mode:"
echo "   set -x"
echo "   gok k8sSum<TAB>"
echo "   set +x"
echo ""

# Quick fix option
echo "🚀 Quick Fix Commands:"
echo "====================="
echo "# Run these commands in your interactive shell:"
echo "source gok-completion.sh"
echo "complete -r gok  # Remove old completion"
echo "complete -F _gok_enhanced_completion gok  # Re-register"
echo "# Now test: gok k8sSum<TAB>"