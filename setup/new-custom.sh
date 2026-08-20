#!/bin/bash

# =====================================================================
# Questo script prepara i sorgenti custom in accordo alla nuova
# architettura CVS, eseguendo il checkout del progetto CVS.
#
# Lo script prende come unico argomento il nome del progetto CVS
#  ad es. alter-4-0, viae, iter ecc.)
#
# es. di chiamata:
# new-custom.sh alter-4-0 
#
# N.B. Lo script usa la variabile d'ambiente NEW_BASE contenuta in env.sh
#      che deve quindi essere impostate prima di lanciare lo script. 
#
# N.B. Lo script deve essere eseguito una tantum per ogni progetto
#      CVS presente sul server
# =====================================================================

set -euo pipefail

# Leggo la variabile d'ambiente NEW_BASE
. env.sh

# Controllo spazio disco
./check-disk-usage.sh

NEW_REPO="${1:-alter-4-0}"

# Ora eseguo il checkout nella cartella ${NEW_BASE}/shared
mkdir -p ${NEW_BASE}/shared
cd ${NEW_BASE}/shared
cvs co ${NEW_REPO} || true

echo "Eseguito checkout del nuovo repo ${NEW_REPO}"
