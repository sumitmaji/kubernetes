#!/bin/bash

# GOK Tab Completion Fix Script
# This script diagnoses and fixes tab completion issues

echo "🔧 GOK Tab Completion Diagnostic & Fix"
echo "======================================"
echo

GOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPLETION_SCRIPT="$GOK_DIR/gok-completion.bash"

echo "📂 GOK Directory: $GOK_DIR"
echo "📄 Completion Script: $COMPLETION_SCRIPT"
echo

# Check 1: Completion script exists
if [[ -f "$COMPLETION_SCRIPT" ]]; then
    echo "✅ Completion script found"
else
    echo "❌ Completion script missing"
    exit 1
fi

# Check 2: Bash completion support
echo
echo "🔍 Checking bash completion support:"
if [[ -f /etc/bash_completion ]] || [[ -f /usr/share/bash-completion/bash_completion ]]; then
    echo "✅ System bash completion available"
elif command -v brew >/dev/null 2>&1 && [[ -f $(brew --prefix)/etc/bash_completion ]]; then
    echo "✅ Homebrew bash completion available"
else
    echo "⚠️  System bash completion not found"
fi

# Check 3: Current registration
echo
echo "🔍 Checking current completion registration:"
complete -p gok-new 2>/dev/null || complete -p ./gok-new 2>/dev/null || echo "❌ No completion registered"

# Check 4: Function availability
echo
echo "🔍 Checking completion function:"
if declare -f _gok_completion >/dev/null 2>&1; then
    echo "✅ _gok_completion function available"
else
    echo "❌ _gok_completion function not found"
fi

echo
echo "🔧 Applying fixes:"

# Fix 1: Source completion script
echo "1. Loading completion script..."
if source "$COMPLETION_SCRIPT"; then
    echo "   ✅ Completion script loaded"
else
    echo "   ❌ Failed to load completion script"
    exit 1
fi

# Fix 2: Register for both gok-new and ./gok-new
echo "2. Registering completion for both 'gok-new' and './gok-new'..."
complete -F _gok_completion gok-new
complete -F _gok_completion ./gok-new
echo "   ✅ Completion registered"

# Fix 3: Test completion
echo "3. Testing completion..."
COMP_WORDS=(gok-new install "")
COMP_CWORD=2
_gok_completion
if [[ ${#COMPREPLY[@]} -gt 0 ]]; then
    echo "   ✅ Completion working (${#COMPREPLY[@]} components available)"
    echo "   📝 Sample components: ${COMPREPLY[@]:0:5}..."
else
    echo "   ❌ Completion not working"
fi

echo
echo "🎉 Tab completion setup complete!"
echo
echo "💡 To make this permanent, add to your ~/.bashrc:"
echo "   source $COMPLETION_SCRIPT"
echo
echo "🧪 Test with these commands:"
echo "   gok-new install <TAB><TAB>"
echo "   ./gok-new install <TAB><TAB>"
echo "   gok-new cache <TAB><TAB>"
echo
echo "📋 If tab completion still doesn't work:"
echo "   1. Make sure you're using bash shell"
echo "   2. Try: set +H  (disable history expansion)"
echo "   3. Try: shopt -s progcomp  (enable programmable completion)"