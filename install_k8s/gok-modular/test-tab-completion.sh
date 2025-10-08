#!/bin/bash

# Test script to demonstrate tab completion functionality

echo "🔧 GOK Tab Completion Test"
echo "========================="
echo

# Source the completion script
source "$(dirname "$0")/gok-completion.bash"

echo "✅ Completion function loaded: _gok_completion"
echo "✅ Commands completed by bash: $(complete -p gok-new 2>/dev/null | wc -l) registration(s)"
echo

echo "🧪 Testing completion scenarios:"
echo

# Test 1: Main commands
echo "1. Main commands (gok-new <TAB>):"
COMP_WORDS=(gok-new "")
COMP_CWORD=1
_gok_completion
echo "   Available: ${COMPREPLY[@]:0:8}... (${#COMPREPLY[@]} total)"
echo

# Test 2: Install components  
echo "2. Install components (gok-new install <TAB>):"
COMP_WORDS=(gok-new install "")
COMP_CWORD=2
_gok_completion
echo "   Available: ${COMPREPLY[@]:0:8}... (${#COMPREPLY[@]} total)"
echo

# Test 3: Partial completion
echo "3. Partial match (gok-new install kub<TAB>):"
COMP_WORDS=(gok-new install "kub")
COMP_CWORD=2
_gok_completion
echo "   Matches: ${COMPREPLY[@]}"
echo

# Test 4: Status command
echo "4. Status command (gok-new status <TAB>):"
COMP_WORDS=(gok-new status "")
COMP_CWORD=2
_gok_completion
echo "   Available: ${COMPREPLY[@]:0:8}... (${#COMPREPLY[@]} total)"
echo

echo "✨ To enable tab completion in your shell, run:"
echo "   source $(pwd)/gok-completion.bash"
echo
echo "📝 To install permanently:"
echo "   ./gok-new completion install"
echo
echo "🎯 Usage examples:"
echo "   gok-new install <TAB><TAB>     # Shows all components"
echo "   gok-new install prom<TAB>      # Completes to 'prometheus'"
echo "   gok-new cache <TAB><TAB>       # Shows cache subcommands"