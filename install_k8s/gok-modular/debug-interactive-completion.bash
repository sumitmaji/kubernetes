#!/bin/bash

# Debug completion that logs what bash is sending
_gok_debug_completion() {
    # Log to a file what bash is sending us
    echo "$(date): COMP_WORDS=(${COMP_WORDS[*]}) COMP_CWORD=$COMP_CWORD COMP_LINE='$COMP_LINE' COMP_POINT=$COMP_POINT" >> /tmp/gok-completion-debug.log
    
    local cur prev words cword
    
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD

    case $cword in
        1)
            COMPREPLY=($(compgen -W "install reset remote exec status help" -- "$cur"))
            ;;
        2)
            case "${words[1]}" in
                "remote")
                    COMPREPLY=($(compgen -W "setup add list copy exec status help" -- "$cur"))
                    ;;
                "install")
                    COMPREPLY=($(compgen -W "docker kubernetes prometheus grafana" -- "$cur"))
                    ;;
            esac
            ;;
    esac
    
    echo "$(date): COMPREPLY=(${COMPREPLY[*]})" >> /tmp/gok-completion-debug.log
    return 0
}

# Clear previous debug log
> /tmp/gok-completion-debug.log

# Unregister any existing completion
complete -r gok-new 2>/dev/null || true

# Register the debug completion
complete -F _gok_debug_completion gok-new

echo "✅ Debug completion loaded"
echo "   Try: gok-new remote <TAB><TAB>"
echo "   Then check: cat /tmp/gok-completion-debug.log"