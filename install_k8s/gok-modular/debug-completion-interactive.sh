#!/bin/bash

# Create a test version of the completion with debug output
_gok_completion_debug() {
    local cur prev words cword split
    
    # Initialize completion variables manually for better compatibility
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword=$COMP_CWORD
    
    echo "DEBUG: cword=$cword, cur='$cur', prev='$prev'"
    echo "DEBUG: words=(${words[*]})"
    
    # Remote command subcommands
    local remote_subcommands="setup add list show exec copy status install-gok setup-ssh setup-keys copy-key setup-sudo passwordless-sudo test-connection help"

    # Completion logic based on position and previous word
    case $cword in
        1)
            echo "DEBUG: In case 1"
            local main_commands="install reset start deploy patch create generate status desc describe logs bash shell exec remote completion cache taint-node checkDns checkCurl help"
            COMPREPLY=($(compgen -W "$main_commands" -- "$cur"))
            ;;
        2)
            echo "DEBUG: In case 2"
            # Second argument: complete based on first command
            case "${words[1]}" in
                "remote")
                    echo "DEBUG: Matched remote case"
                    COMPREPLY=($(compgen -W "$remote_subcommands" -- "$cur"))
                    ;;
                *)
                    echo "DEBUG: Did not match remote, matched: '${words[1]}'"
                    ;;
            esac
            ;;
        *)
            echo "DEBUG: In default case"
            ;;
    esac
    
    echo "DEBUG: COMPREPLY=(${COMPREPLY[*]})"
    return 0
}

# Register debug completion
complete -F _gok_completion_debug gok-new

echo "Debug completion registered. Try: gok-new remote <TAB><TAB>"