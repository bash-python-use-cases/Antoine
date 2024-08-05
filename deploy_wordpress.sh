#!/bin/bash

# Configuration de la base de données
DB_NAME="wordpress"
DB_USER="wp_user"
DB_PASSWORD="dbpassword"
DB_ROOT_PASSWORD="rootdbpassword"

# Configuration du serveur frontal (frontend)
FRONTEND_IP="51.158.172.153"
# Configuration du serveur backend (base de données)
BACKEND_IP="51.15.127.192"
# Domaine pour le site WordPress
DOMAIN="apache.${FRONTEND_IP}.nip.io"

# Configuration de l'administrateur WordPress
WP_ADMIN_EMAIL="goffinet@goffinet.eu"
WP_ADMIN_USER="admin"
WP_ADMIN_PASSWORD="admin1234admin"
WP_ADMIN_EMAIL="goffinet@goffinet.eu"
WP_LANGUAGE="fr_FR"
WP_THEME="twentynineteen"
SSH_KEY_PATH="/home/admsys/sshkey"

# Fichier de log
LOGFILE="deploy_wordpress.log"
timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

####################

check_services_status () {
echo "Backend Status : $(ssh_execute_command $BACKEND_IP "sudo systemctl is-active mariadb")"
echo "Frontend Status : $(ssh_execute_command $FRONTEND_IP "sudo systemctl is-active httpd")"

log () {
echo "Log $timestamp" | tee -a $LOGFILE
}

ssh_execute_command () {
local target=$1
local commands=$2
local options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ssh -i $SSH_KEY_PATH "$options" wpadmin@${target} "$commands" | tee -a $LOGFILE
}

ssh_execute_command $BACKEND_IP "cat /etc/hostname ; \
cat /etc/hostname ; \
cat /etc/hostname"

