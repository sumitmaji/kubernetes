#!/bin/bash
# Quick fix for GOK autocomplete
cd "$(dirname "${BASH_SOURCE[0]}")" && source gok-completion.bash && complete -F _gok_completion gok-new && complete -F _gok_completion ./gok-new && echo "✅ Autocomplete fixed! Try: ./gok-new install <TAB><TAB>"