#!/bin/bash

# =======================================================================
# Questo helper script viene invocato per calcolare lo spazio occupato
# sul server, bloccando l'esecuzione del chiamante se questo supera
# la soglia del 90%.
#
# es. di chiamata:
# ./check-disk-usage.sh
#
# N.B. Lo script usa la variabile d'ambiente NEW_BASE contenuta in env.sh
# che deve quindi essere impostate prima di eseguire lo script. 
# =======================================================================

set -e

# Leggo la variabile d'ambiente NEW_BASE
. env.sh


# Verifica spazio disco remoto
DISK_USAGE=$(df -h ${NEW_BASE} | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    echo "Spazio disco critico sul server: ${DISK_USAGE}%"
    exit 1
elif [ $DISK_USAGE -gt 80 ]; then
    echo "ATTENZIONE! Spazio disco al ${DISK_USAGE}% sul server"
else
    echo "✓ Spazio disco OK sul server (${DISK_USAGE}% usato)"
fi
