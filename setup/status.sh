#!/bin/bash
# status.sh

. env.sh

BASE="${NEW_BASE}/clients"

printf "%-20s %-12s %-10s\n" "CLIENTE" "OPENACS" "STATO"
printf "%-20s %-12s %-10s\n" "-------" "-------" "-----"

for cliente_dir in $BASE/*/; do
    nome=$(basename $cliente_dir)
    ver=$(cat $cliente_dir/.openacs-version 2>/dev/null || echo "unknown")
    stato=$(systemctl is-active openacs-$nome 2>/dev/null || echo "n/a")
    printf "%-20s %-12s %-10s\n" "$nome" "$ver" "$stato"
done


