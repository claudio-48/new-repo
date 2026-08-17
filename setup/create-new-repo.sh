#!/bin/bash

# =======================================================================
# Questo script legge un'istanza modello (alter, viae, iter ecc) ed
# utilizza i package custom tipici del prodotto per creare il nuovo repo
# e contestualmente popolare la cartella 'shared'.
#
# Lo script prende come argomenti:
# 1. Un'istanza modello di uno dei nostri prodotti (ad es. alter-dev)
# 2. Il nome del progetto CVS (ad es. alter-4-0)
#
# es. di chiamata:
# $0 alter-dev alter-4-0 alter-package-names
#
# N.B. Lo script usa le variabili d'ambiente DEV_BASE, NEW_BASE,
#      CUSTOM_PACKAGES e CVSROOT contenute in env.sh che devono quindi
#      essere impostate prima di lanciare lo script. 
# =======================================================================

set -euo pipefail

# Leggo le variabili d'ambiente DEV_BASE, NEW_BASE, CUSTOM_PACKAGES e CVSROOT
. env.sh

# Trovo la cartella contenente lo script in esecuzione
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd ${SCRIPT_DIR}

SOURCE_DIR="${DEV_BASE}/${1:-alter-dev}"
NEW_REPO=${2:-alter-4-0}
CUSTOM_DEST="/tmp/${2:-alter-4-0}"

# Controlli
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Errore: Cartella sorgente $SOURCE_DIR non esiste."
    exit 1
fi

if [ ! -f "$CUSTOM_PACKAGES" ]; then
    echo "Errore: File $CUSTOM_PACKAGES non trovato."
    exit 1
fi

# Preparazione destinazioni
rm -rf "$CUSTOM_DEST"
mkdir -p "$CUSTOM_DEST/packages"

echo "=== Inizio elaborazione ==="

# ----------------------------------------------------------------
#  Copia SOLO i package CUSTOM
# ----------------------------------------------------------------
echo "Creazione cartella con solo i package custom..."

while IFS= read -r pkg || [ -n "$pkg" ]; do
    pkg=$(echo "$pkg" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -z "$pkg" ] && continue
    
    if [ -d "$SOURCE_DIR/packages/$pkg" ]; then
        echo "   Copio custom: $pkg"
        rsync -a \
            --exclude="*~" \
            --exclude="*#" \
            --exclude="CVS" \
            --exclude="*/CVS" \
            "$SOURCE_DIR/packages/$pkg/" "$CUSTOM_DEST/packages/$pkg/"
    else
        echo "   Attenzione: Package custom '$pkg' non trovato!"
    fi
done < "$CUSTOM_PACKAGES"

echo "   Pulizia eventuali file temporanei ..."
find "$CUSTOM_DEST" -type f \( -name "*~" -o -name "*#" \) -delete 2>/dev/null || true
find "$CUSTOM_DEST" -type d -name "CVS" -exec rm -rf {} + 2>/dev/null || true

# Ora posso utilizzare la cartella di destinazione dei package custom per popolare il nuovo repo
cd /tmp/${NEW_REPO}
echo "Importazione nuovo repo ${NEW_REPO}"
cvs -q import -m "Initial import" ${NEW_REPO} Oasi start || true

echo "Il repo ${NEW_REPO} è stato importato."

# Rimuovo la cartella usata per importare il codice nel nuovo repo
rm -rf /tmp/${NEW_REPO}

# Ora eseguo il checkout nella cartella ${NEW_BASE}/shared
mkdir -p ${NEW_BASE}/shared/${NEW_REPO}/packages
cd ${NEW_BASE}/shared/${NEW_REPO}/packages
cvs co ${NEW_REPO} || true

echo "Eseguito checkout del nuovo repo ${NEW_REPO}"

