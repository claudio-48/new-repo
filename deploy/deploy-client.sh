#!/bin/bash
# deploy-client.sh
# Deploy multi-cliente con configurazione centralizzata

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/deployment-clients.conf"

# Imposto le variabili d'ambiente
. ${SCRIPT_DIR}/env.sh

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "${BLUE}▶${NC} $1"; }
client_info() { echo -e "${CYAN}[CLIENT]${NC} $1"; }

# Help
show_help() {
    cat << EOF
Multi-Client Deployment Script

Deploy su server di produzione o staging di un cliente usando configurazione centralizzata.

Usage: $0 <client> <project> <method> [options]

Arguments:
  client      ID cliente (da deployment-clients.conf)
  project     Progetto CVS o Git da deployare (alter-4-0, viae ecc.)
  method      Metodo deploy: cvs, git, o rsync

Options:
  --dry-run   Mostra cosa verrebbe fatto senza eseguire
  --force     Salta conferme interattive

Commands:
  list                Lista tutti i clienti configurati
  show <client>       Mostra configurazione cliente
  test <client>       Test connessione cliente

Examples:
  $0 list
  $0 show acme
  $0 test acme
  $0 acme oacs-a cvs
  $0 globex oacs-a rsync --dry-run
  $0 techcorp oacs-b git --force

Configuration File: ${CONFIG_FILE}

EOF
    exit 0
}

# Carica configurazione cliente
load_client_config() {
    local client_id=$1
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "File configurazione non trovato: ${CONFIG_FILE}"
    fi
    
    # Cerca cliente nel file config
    local config_line=$(grep "^${client_id}|" "$CONFIG_FILE" | head -1)
    
    if [ -z "$config_line" ]; then
        error "Cliente '${client_id}' non trovato in ${CONFIG_FILE}"
    fi
    
    # Parse configurazione
    IFS='|' read -r CLIENT_ID PROD_SERVER PROD_USER PROD_BASE PROJECT <<< "$config_line"
    
    # Export variabili
    export CLIENT_ID
    export PROD_SERVER
    export PROD_USER
    export PROD_BASE    
    export PROJECT
    
    client_info "Cliente: ${CLIENT_ID}"
    client_info "Server: ${PROD_SERVER}"
    client_info "User: ${PROD_USER}"
    [ -n "$CVSROOT" ] && client_info "CVS: ${CVSROOT}" || client_info "CVS: Non configurato"

}

# Lista tutti i clienti
list_clients() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Clienti Configurati"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    if [ ! -f "$CONFIG_FILE" ]; then
        error "File configurazione non trovato: ${CONFIG_FILE}"
    fi
    
    printf "%-15s %-30s %-10s %-20s\n" "CLIENT" "SERVER" "USER" "INSTANCES"
    echo "────────────────────────────────────────────────────────────────"
    
    while IFS='|' read -r client_id server user dir proj ; do
        # Salta commenti e linee vuote
        [[ "$client_id" =~ ^#.*$ ]] && continue
        [ -z "$client_id" ] && continue
        
        printf "%-15s %-30s %-10s %-20s\n" "$client_id" "$server" "$user" "$proj"
    done < "$CONFIG_FILE"
    
    echo ""
}

# Mostra dettagli cliente
show_client() {
    local client_id=$1
    
    if [ -z "$client_id" ]; then
        error "Specificare ID cliente"
    fi
    
    load_client_config "$client_id"
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Configurazione Cliente: ${CLIENT_ID}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Server Produzione:    ${PROD_SERVER}"
    echo "User SSH:             ${PROD_USER}"
    echo "CVS Root:             ${CVSROOT:-Non configurato}"
    echo "Project:              ${PROJECT}"
    echo ""
    echo "Comando SSH:"
    echo "  ssh ${PROD_USER}@${PROD_SERVER}"
    echo ""
}

# Test connessione cliente
test_client() {
    local client_id=$1
    
    if [ -z "$client_id" ]; then
        error "Specificare ID cliente"
    fi
    
    load_client_config "$client_id"
    
    echo ""
    step "Test connessione a ${CLIENT_ID}..."
    
    # Test SSH
    if ssh -o ConnectTimeout=5 ${PROD_USER}@${PROD_SERVER} "echo 'SSH OK'" >/dev/null 2>&1; then
        info "✓ SSH connessione OK"
    else
        error "✗ SSH connessione FALLITA"
    fi
    
    echo ""
    info "Test completato per cliente: ${CLIENT_ID}"
    echo ""
}


# Deploy function
deploy() {
    local client_id=$1
    local proj=$2
    local method=$3
    local dry_run=$4
    local force=$5
    
    # Carica config cliente
    load_client_config "$client_id"

    # Verifica che istanza sia valida per questo cliente
    if [[ ! ",${PROJECT}," =~ ",${proj}," ]]; then
        error "Progetto '${proj}' non configurato per cliente '${CLIENT_ID}'. Progetti disponibili: ${PROJECT}"
    fi
    
    # Verifica CVS se metodo è cvs
    if [ "$method" == "cvs" ] && [ -z "$CVSROOT" ]; then
        error "Metodo CVS richiesto ma CVSROOT non configurato per cliente '${CLIENT_ID}'"
    fi
    
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  Deploy Cliente"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "Cliente:    ${CLIENT_ID}"
    echo "Server:     ${PROD_SERVER}"
    echo "Progetto:   ${proj}"
    echo "Metodo:     ${method}"
    [ -n "$dry_run" ] && echo "Modalità:   DRY RUN (simulazione)"
    echo ""
    
    if [ -z "$force" ] && [ -z "$dry_run" ]; then
        read -p "Procedere con il deploy? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Deploy annullato"
            exit 0
        fi
    fi
    
    if [ -n "$dry_run" ]; then
        info "DRY RUN - Mostrando operazioni senza eseguirle"
        echo ""
        echo "Operazioni che verrebbero eseguite:"
        echo "  1. Test connessione SSH a ${PROD_USER}@${PROD_SERVER}"
        echo "  2. Backup su ${PROD_SERVER}/backups"
        echo "  3. Deploy con metodo: ${method}"
        echo "  4. Restart istanze"
        echo ""
        info "Usa senza --dry-run per eseguire realmente"
        exit 0
    fi
    
    # Esegui deploy reale chiamando lo script esistente
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    
    step "Esecuzione deploy..."
    
    # Usa production-deploy-remote.sh se esiste
    if [ -f "${SCRIPT_DIR}/production-deploy-remote.sh" ]; then
        
        "${SCRIPT_DIR}/production-deploy-remote.sh" \
            "${proj}" \
            "${method}" \
            "${PROD_SERVER}" \
            "${PROD_USER}" \
	    "${PROD_BASE}"
    else
        error "Script production-deploy-remote.sh non trovato in ${SCRIPT_DIR}"
    fi
}

# Parse arguments
COMMAND=${1:-help}

case "$COMMAND" in
    list)
        list_clients
        ;;
    show)
        show_client "$2"
        ;;
    test)
        test_client "$2"
        ;;
    help|-h|--help)
        show_help
        ;;
    *)
        # Deploy command
        CLIENT_ID=$1
        PROJECT=$2
        METHOD=${3:-cvs}
        
        # Parse options
        DRY_RUN=""
        FORCE=""
        shift 3 2>/dev/null || true
        
        while [ $# -gt 0 ]; do
            case "$1" in
                --dry-run)
                    DRY_RUN="yes"
                    ;;
                --force)
                    FORCE="yes"
                    ;;
                *)
                    warn "Opzione sconosciuta: $1"
                    ;;
            esac
            shift
        done
        
        if [ -z "$CLIENT_ID" ] || [ -z "$PROJECT" ]; then
            error "Specificare client e progetto. Usa '$0 help' per aiuto"
        fi
        
        deploy "$CLIENT_ID" "$PROJECT" "$METHOD" "$DRY_RUN" "$FORCE"
        ;;
esac
