#!/bin/bash
source gok-completion.bash

echo "Testing completion for: gok-new install "
COMP_WORDS=(gok-new install "")
COMP_CWORD=2

# Debug variables
echo "COMP_WORDS: ${COMP_WORDS[@]}"
echo "COMP_CWORD: $COMP_CWORD"
echo "cur: '${COMP_WORDS[COMP_CWORD]}'"
echo "prev: '${COMP_WORDS[COMP_CWORD-1]}'"

# Call completion function
_gok_completion

echo "COMPREPLY has ${#COMPREPLY[@]} items:"
echo "First 5 items: ${COMPREPLY[@]:0:5}"
