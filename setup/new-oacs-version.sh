#!/bin/bash

# ====================================================================
# Questo script legge un'istanza modello (alter, viae, iter ecc) e
# prepara i sorgenti OpenACS in accordo alla nuova architettura CVS.
#
# Lo script prende come unico argomento un'istanza modello di uno dei
# nostri prodotti ad es. alter-dev
#
# es. di chiamata:
# new-oacs-version.sh alter-dev 
#
# N.B. Lo script usa le variabili d'ambiente DEV_BASE, NEW_BASE e
#      CUSTOM_PACKAGES contenute in env.sh che devono quindi essere
#      impostate prima di lanciare lo script. 
#
# N.B. Lo script deve essere eseguito una tantum per ogni versione
#      di OpenACS presente sul server
# ====================================================================

set -euo pipefail

# Leggo le variabili d'ambiente DEV_BASE e NEW_BASE
. env.sh

INSTANCE="${1:-alter-dev}"
SOURCE_DIR="${DEV_BASE}/${INSTANCE}"

# Trovo la cartella contenente lo script in esecuzione
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd ${SCRIPT_DIR}

# Controlli
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Errore: Cartella sorgente $SOURCE_DIR non esiste."
    exit 1
fi

if [ ! -f "$CUSTOM_PACKAGES" ]; then
    echo "Errore: File $CUSTOM_PACKAGES non trovato."
    exit 1
fi

# estrapolo la versione di OpenACS
VERSION=$(awk -F'"' '/version name=/ {print $2}' ${SOURCE_DIR}/packages/acs-kernel/acs-kernel.info)

OACS_DEST="${NEW_BASE}/shared/openacs-${VERSION}"

# Preparazione destinazione
#rm -rf "$OACS_DEST"
mkdir -p "$OACS_DEST/packages"

echo "=== Inizio elaborazione ==="

# Copio SOLO i package STANDARD (quelli NON presenti in custom-package-names)
echo "   → Copia solo i package standard..."

# Creo una lista dei packsge custom per escluderli facilmente
mapfile -t CUSTOM_PACKAGES < <(grep -v '^[[:space:]]*$' "$CUSTOM_PACKAGES" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

for pkg in "$SOURCE_DIR/packages/"*; do
    [ -d "$pkg" ] || continue
    pkg_name=$(basename "$pkg")
    
    # Salta se è un package custom
    if printf '%s\n' "${CUSTOM_PACKAGES[@]}" | grep -qx "$pkg_name"; then
        echo "   Escludo custom: $pkg_name"
        continue
    fi

    # Salta cartella CVS
    [ "$pkg_name" = "CVS" ] && continue    
    
    echo "   Copio standard: $pkg_name"
    rsync -a \
        --exclude="*~" \
        --exclude="*#" \
        --exclude="CVS" \
        "$pkg/" "${OACS_DEST}/packages/$pkg_name/"
done

echo "=== Operazione completata ==="
echo "→ Creata versione openacs-${VERSION} in ${OACS_DEST}"

