#!/bin/bash

# ====================================================================
# Questo script prepara una nuova istanza in accordo alla nuova
# architettura CVS, creando gli opportuni link simbolici ai package
# condivisi di OpenACS e del prodotto in questione (alter, iter ecc) 
#
# Lo script prende come argomenti:
# 1. L'istanza da convertire alla nuova architettura
# 2. Il nome del progetto CVS (ad es. alter-4-0)
#
# es. di chiamata:
# new-instance.sh <nome_istanza>  <nome_repo>
#
# N.B. Lo script usa le variabili d'ambiente DEV_BASE e NEW_BASE 
#      contenute in env.sh che devono quindi essere impostate prima
#      di lanciare lo script. 
# ====================================================================

set -euo pipefail

set -e

NOME_ISTANZA=$1    # es. alter-dev, cano, alter-carnevali ....
NOME_REPO=$2       # es. alter-4-0

# leggo le variabili d'ambiente DEV_BASE e NEW_BASE
. env.sh

PATH_ISTANZA=${DEV_BASE}/$1
MIEI_PKG="${NEW_BASE}/shared/${NOME_REPO}/packages"
CLIENTE_DIR="${NEW_BASE}/clients/${NOME_ISTANZA}"

# Verifica che il path dell'istanza sia disponibile
if [ ! -d "${PATH_ISTANZA}" ]; then
    echo "ERRORE: l'istanza ${NOME_ISTANZA} non trovata in ${PATH_ISTANZA}"
    exit 1
fi

# estrapolo la versione di OpenACS
OPENACS_VER=$(awk -F'"' '/version name=/ {print $2}' ${PATH_ISTANZA}/packages/acs-kernel/acs-kernel.info)

OPENACS_STD="${NEW_BASE}/shared/openacs-$OPENACS_VER"

# Verifica che la versione richiesta sia disponibile
if [ ! -d "$OPENACS_STD" ]; then
    echo "ERRORE: OpenACS $OPENACS_VER non trovato in $BASE/shared/"
    exit 1
fi

# Controllo spazio disco
./check-disk-usage.sh

mkdir -p $CLIENTE_DIR/{etc,www,tcl,log,content-repository-content-files,content-repository-fattura-elettronica,packages}

# Popolo la cartella www 
cp -r $PATH_ISTANZA/www/* $CLIENTE_DIR/www/

# Popolo la cartella tcl 
cp -r $PATH_ISTANZA/tcl/* $CLIENTE_DIR/tcl/

# Popolo la cartella etc
cp -r $PATH_ISTANZA/etc/* $CLIENTE_DIR/etc/

# Popolo la cartella content-repository-content-files
cp -r $PATH_ISTANZA/content-repository-content-files/* $CLIENTE_DIR/content-repository-content-files/

if [ ${NOME_REPO} = "alter-4-0" ]; then
    # Popolo la cartella content-repository-fattura-elettronica
    cp -r $PATH_ISTANZA/content-repository-fattura-elettronica/* $CLIENTE_DIR/content-repository-fattura-elettronica/
else
    rmdir $CLIENTE_DIR/content-repository-fattura-elettronica
fi

# Versione associata al cliente
echo "$OPENACS_VER" > $CLIENTE_DIR/.openacs-version

# Symlink package standard
for pkg in ${OPENACS_STD}/packages/*/; do
    pkg_name=$(basename $pkg)
    ln -s $pkg $CLIENTE_DIR/packages/$pkg_name
done

# Symlink package custom (stessi per tutti, indipendenti dalla versione) 
for pkg in $MIEI_PKG/*/; do
    pkg_name=$(basename $pkg)
    ln -s $pkg $CLIENTE_DIR/packages/$pkg_name
done

echo "✓ ${NOME_ISTANZA} su OpenACS ${OPENACS_VER}"
