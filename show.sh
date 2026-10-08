#!/bin/bash
# strip ANSI + MORK traces from a run output, show meaningful lines
sed 's/\x1b\[[0-9;]*m//g' "$1" | grep -a -v -E '^\-\->|^\^\^\^|findall|MORK init|prolog clause|metta function|metta sexpr|metta runnable|prolog goal|^\s{5,}|^\)\.|^\.$|^\s+:-'
