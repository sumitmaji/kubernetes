#!/bin/bash

# Debug completion test
echo "Testing gok-new remote completion..."

# Set up the test environment
COMP_WORDS=("gok-new" "remote" "")
COMP_CWORD=2
COMPREPLY=()

echo "COMP_WORDS: ${COMP_WORDS[*]}"
echo "COMP_CWORD: $COMP_CWORD"
echo "Current word: '${COMP_WORDS[COMP_CWORD]}'"
echo "Previous word: '${COMP_WORDS[COMP_CWORD-1]}'"

# Call our completion function
_gok_completion

echo "COMPREPLY: ${COMPREPLY[*]}"
echo "Number of completions: ${#COMPREPLY[@]}"

# Test specific case
echo ""
echo "Testing case logic..."
cword=$COMP_CWORD
words=("${COMP_WORDS[@]}")

echo "cword=$cword"
echo "words[1]='${words[1]}'"

if [[ $cword -eq 2 ]]; then
    echo "In cword=2 branch"
    case "${words[1]}" in
        "remote")
            echo "Matched remote case"
            ;;
        *)
            echo "Did not match remote case: '${words[1]}'"
            ;;
    esac
else
    echo "Not in cword=2 branch"
fi