#!/bin/bash
# production-deploy-remote.sh
# Deploy completo da sviluppo a produzione su server remoto
# Supporta CVS, Git e rsync

set -e

# Configurazione
PROJECT=${1:-}
DEPLOY_METHOD=${2:-cvs}
PROD_SERVER=${3:-prod.example.com}
PROD_USER=${4:-root}
PROD_BASE=${5:-/data/app}
INSTANCE=${5:-}

# leggo le variabili d'ambiente DEV_BASE e CVSROOT
. env.sh

# CVS
CVSROOT=${CVSROOT:-}

# Devo impostare le variabili DEV_PATH e PROD_PATH in funzione del metodo richiesto
if [ "${DEPLOY_METHOD}" == "rsync" ]; then
    # devo aggiornare le cartelle www, etc e tcl di una specifica istanza
    # Path locali (sviluppo)
    DEV_PATH="${DEV_BASE}/clients/${INSTANCE}"
    # Path remoti (produzione)
    PROD_PATH="${PROD_BASE}/clients/${INSTANCE}"
else
    # Path locali (sviluppo)
    DEV_PATH="${DEV_BASE}/shared/${PROJECT}/packages"
    # Path remoti (produzione)
    PROD_PATH="${PROD_BASE}/shared/${PROJECT}/packages"
fi
    
# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${BLUE}▶${NC} $1"; }

# Help
show_help() {
    cat << EOF
Production Remote Deployment Script

Deploy da server di sviluppo a server remoto.

Usage: $0 <project> <method> <prod_server> <prod_user> <prod_base> <instance> 

Arguments:
  project       Nome progetto CVS o Git
  method        Metodo deploy: cvs, git, o rsync
  prod_server   Server produzione (default: prod.example.com)
  prod_user     User SSH (default: root)
  prod_base     Radice del percorso dei sorgenti
  instance      Nome dell'istanza (solo per rsync)

Examples:
  $0 alter cvs prod.server.com root /var/www/sources carnevali
  $0 alter-4-0 rsync 192.168.1.100 claudio /var/www/sources alter-c1

Prerequisiti:
  - SSH key-based authentication configurato
  - CVS repository accessibile da entrambi i server (per metodo cvs)
  - Git repository accessibile da produzione (per metodo git)

Environment Variables:
  CVSROOT              CVS repository root
  PROJECT              CVS o Git project 
  INSTANCE             Nome istanza per metodo rsync

EOF
    exit 0
}

# Verifica argomenti
if [ "$1" == "help" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    show_help
fi

if [ -z "$PROJECT" -a "DEPLOY_METHOD" != "rsync"]; then
    error "Specificare il progetto CVS o Git"
fi

# Pre-flight checks
preflight_checks() {
    step "Pre-flight checks..."
    
    # Test connessione SSH
    info "Test connessione SSH a ${PROD_SERVER}..."
    if ! ssh -o ConnectTimeout=5 ${PROD_USER}@${PROD_SERVER} "echo ok" >/dev/null 2>&1; then
        error "Impossibile connettersi a ${PROD_USER}@${PROD_SERVER}"
    fi
    info "✓ Connessione SSH OK"
    
    # Check specifici per metodo
    case $DEPLOY_METHOD in
        cvs)
            # Verifica CVS locale
            if [ ! -d "${DEV_PATH}/CVS" ]; then
                error "Directory ${DEV_PATH} non è sotto CVS"
            fi
            info "✓ Repository CVS trovato localmente"
            
            # Ottieni CVSROOT se non settato
            if [ -z "$CVSROOT" ]; then
                CVSROOT=$(cat ${DEV_PATH}/CVS/Root)
            fi
            info "  CVSROOT: ${CVSROOT}"
            ;;
            
        git)
            # Verifica Git remoto
            if [ ! -d "${PROD_PATH}/.git" ]; then
                error "Directory ${DEV_PATH} non è sotto Git"
            fi	    
            info "✓ Repository Git configurato in produzione"
            ;;
            
        rsync)
            # Verifica path sviluppo
            if [ ! -d "${DEV_PATH}" ]; then
                error "Directory sviluppo ${DEV_PATH} non trovata"
            fi
            info "✓ Directory sviluppo trovata"
            ;;
    esac
    
}

# Deploy CVS
deploy_cvs() {
    step "Deploy tramite CVS..."
       
    # CVS update
    info "Esecuzione CVS update..."

    info "ssh ${PROD_USER}@${PROD_SERVER} PROD_PATH=${PROD_PATH} CVSROOT=${CVSROOT}"
    ssh ${PROD_USER}@${PROD_SERVER} \
        "cd ${PROD_PATH} && cvs -d ${CVSROOT} -q update -d -P" \
        || error "CVS update fallito"    
    
    info "✓ Codice aggiornato da CVS"
}

# Deploy Git
deploy_git() {
    step "Deploy tramite Git..."
       
    info "Esecuzione git pull remoto..."

    ssh ${PROD_USER}@${PROD_SERVER} "
        git stash && \
        git pull origin main
    " || error "Git pull fallito"
    
    info "✓ Codice aggiornato da Git"
}

# Deploy rsync
deploy_rsync () {

    local src="${DEV_PATH}"
    local dst="${PROD_USER}@${PROD_SERVER}:${PROD_PATH}"

    # tcl: --delete sicuro, sono solo script
    rsync -av --delete \
        ${src}/tcl/ \
        ${dst}/tcl/

    # etc: --delete sicuro, sono solo script
    rsync -av --delete \
        ${src}/etc/ \
        ${dst}/etc/    

    # www: no --delete, i file caricati dagli utenti non esistono in dev
    rsync -av \
        --exclude='*.tmp' \
        ${src}/www/ \
        ${dst}/www/

    echo "✓ ${INSTANCE} sincronizzata su ${PROD_SERVER}"
}

# Post-deploy
post_deploy() {
    step "Operazioni post-deploy..."
    
    info "Restart istanza remota (richiederà la password) ..."
    ssh ${PROD_USER}@${PROD_SERVER} "
        sudo systemctl restart ${INSTANCE}.service
    " >/dev/null 2>&1
    
    info "Attesa startup (15 secondi)..."
    sleep 15
}

# Main
main() {
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    echo ""
    echo "========================================="
    echo "  🚀 OpenACS Remote Deployment"
    echo "========================================="
    echo "Sviluppo:   $(HOSTNAME)"
    echo "Produzione: ${PROD_SERVER}"
    echo "Progetto:   ${PROJECT}"
    echo "Metodo:     ${DEPLOY_METHOD}"
    echo "Timestamp:  ${TIMESTAMP}"
    if [ "$DEPLOY_METHOD" == "cvs" ]; then
        echo "CVSROOT:    ${CVSROOT}"
    fi
    echo ""
  
    preflight_checks
    echo ""

    case $DEPLOY_METHOD in
        cvs)
            deploy_cvs
            ;;
        git)
            deploy_git
            ;;
	rsync)
	    deploy_rsync
	    ;;
        *)
            error "Metodo non supportato: ${DEPLOY_METHOD}"
            ;;
    esac
    echo ""

    # Da rivedere per eventuale ripartenza delle istanze
    # post_deploy
    echo ""
    
    info "========================================="
    info "  ✅ Deploy remoto completato!"
    info "========================================="
    info ""
    info "Server:  ${PROD_SERVER}"
    info "Metodo:  ${DEPLOY_METHOD}"
    echo ""
}

# Execute
main
