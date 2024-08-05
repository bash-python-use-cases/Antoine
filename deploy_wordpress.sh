#!/bin/bash

generate_password() {
  local length=${1:-"32"}
  openssl rand -base64 $((length * 3 / 4)) | cut -c1-$length
}

load_env_vars() {
    FRONTEND_IP=${FRONTEND_IP:?"51.158.160.190"}
    BACKEND_IP=${BACKEND_IP:?"51.158.174.245"}
    DOMAIN=${DOMAIN:?"apache.${FRONTEND_IP}.nip.io"}

    DB_NAME=${DB_NAME:-"wordpress"}
    DB_USER=${DB_USER:-"wp_user"}
    DB_PASSWORD=${DB_PASSWORD:-$(generate_password)}
    DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD:-$(generate_password)}

    WP_ADMIN_USER=${WP_ADMIN_USER:-"admin"}
    WP_ADMIN_PASSWORD=${WP_ADMIN_PASSWORD:-$(generate_password)}
    WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL:-"admin@example.com"}
    WP_THEME=${WP_THEME:-"twentynineteen"}
    WP_LANGUAGE=${WP_LANGUAGE:-"fr_FR"}

    SSH_KEY_PATH=${SSH_KEY_PATH:-"./sshkey"}
    WEB_SERVER=${WEB_SERVER:-"apache"}
    LOGFILE=${LOGFILE:-"deploy_wordpress.log"}
}

check_services_status () {
echo "Backend Status : $(ssh_execute_command $BACKEND_IP "sudo systemctl is-active mariadb")"
echo "Frontend Status : $(ssh_execute_command $FRONTEND_IP "sudo systemctl is-active httpd")"
}

log () {
local message=$1
echo $(date +'%Y-%m-%d %T') $message | tee -a $LOGFILE
}

ssh_execute_command () {
local target=$1
local commands=$2
local options="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
ssh -i $SSH_KEY_PATH $options wpadmin@${target} "$commands" | tee -a $LOGFILE
}

load_env_vars

ssh_execute_command $BACKEND_IP "cat /etc/hostname ; \
cat /etc/hostname ; \
cat /etc/hostname"

FRONTEND_COMMAND="cat /etc/hostname"
ssh_execute_command $FRONTEND_IP "$FRONTEND_COMMAND" | tee -a $LOGFILE

log "ceci est un log"

check_services_status

log $WP_ADMIN_PASSWORD
