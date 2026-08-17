STEP 1: Preparazione nuovo repo CVS (inizio con alter-4-0)

# L'attuale repo CVS non è affidabile e quindi parto da un'istanza modello aggiornata,
# in questo caso da alter-dev.

# creo file con lista packages
cd /var/www/sources
ls --format=single-column alter-dev/packages > ./custom-package-names

# Lo scopo è di creare un nuovo repo con i soli packages dei nostri prodotti 
# e quindi ho eliminato manualmente tutti i packages standard di OpenACS dal
# file custom-package-names

# eseguo lo script prepare-sources.sh che crea:
# 1. la cartella alter-4-0 che conterrà unicamente i packages custom e che
#    verrà usata come base per il nuovo repo CVS di alter
# 2. la cartella openacs-5.10.0 con il codice standard di openacs
./prepare-sources.sh alter-dev /var/www/sources/shared/openacs-5.10.0 /tmp/alter-4-0

# ora posso utilizzare la cartella alter-4-0 per popolare il nuovo repo
cd /tmp/alter-4-0
cvs -d :ext:nsadmin@oasisoftware.com:/var/lib/cvs import -m "Initial import" alter-4-0 Oasi start

# rimuovo la cartella usata per importare il codice nel nuovo repo ed eseguo il checkout
# nella cartella /var/www/sources/shared
rm -rf ../alter-4-0
cd /var/www/sources/shared
cvs -d :ext:nsadmin@oasisoftware.com:/var/lib/cvs co alter-4-0

# ora posso creare l'istanza di nuovi clienti, con opportuni link simbolici
# eseguendo lo script nuovo-cliente.sh
./nuovo-cliente.sh alter-c1 5.10.0 alter-4-0
./nuovo-cliente.sh alter-c2 5.10.0 alter-4-0

# ... e verificare lo stato dei clienti con:
./status.sh


