#!/bin/bash

# Minimal GOK-NEW Tab Completion
# This is a simplified version to debug the tab completion issue

_gok_minimal_completion() {
    local cur prev words cword
    
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD

    case $cword in
        1)
            # First level: main commands
            COMPREPLY=($(compgen -W "install reset remote exec status help" -- "$cur"))
            ;;
        2)
            # Second level: based on first command
            case "${words[1]}" in
                "remote")
                    COMPREPLY=($(compgen -W "setup add list copy exec status help" -- "$cur"))
                    ;;
                "install")
                    COMPREPLY=($(compgen -W "docker kubernetes prometheus grafana" -- "$cur"))
                    ;;
                *)
                    COMPREPLY=()
                    ;;
            esac
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
    
    return 0
}

# Unregister any existing completion
complete -r gok-new 2>/dev/null || true

# Register the minimal completion
complete -F _gok_minimal_completion gok-new

echo "✅ Minimal GOK-NEW completion loaded"
echo "   Test: gok-new <TAB><TAB>"
echo "   Test: gok-new remote <TAB><TAB>"