#!/bin/bash

CONFIG_FILE=${CONFIG_FILE:-"config.yml"}

parse_yaml() {
    python -c "import yaml
with open('$1', 'r') as file:
    data = yaml.safe_load(file)
for key, value in data.items():
    print(f'{key.upper()}={value}')
"
}

load_config () {
eval $(parse_yaml $CONFIG_FILE)
}

generate_password() {
  local length=${1:-"32"}
  openssl rand -base64 $((length * 3 / 4)) | cut -c1-$length
}

load_env_vars() {
    FRONTEND_IP=${FRONTEND_IP:?"FRONTEND_IP is required"}
    BACKEND_IP=${BACKEND_IP:?"BACKEND_IP is required"}
    DOMAIN=${DOMAIN:?"DOMAIN is required"}

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

setup_backend() {
    log "Deploying on backend server"
    ssh_execute_command $BACKEND_IP "sudo dnf install -y mariadb-server firewalld ; \
        sudo sed -i \"s/^#bind-address.*/bind-address=0.0.0.0/g\" /etc/my.cnf.d/mariadb-server.cnf ; \
        sudo systemctl start firewalld ; \
        sudo systemctl enable firewalld ; \
        sudo firewall-cmd --permanent --add-rich-rule=\"rule family=\"ipv4\" source address=\"${FRONTEND_IP}/32\" port port=\"3306\" protocol=\"tcp\" accept\" ; \
        sudo firewall-cmd --reload ; \
        sudo systemctl start mariadb ; \
        sudo systemctl enable mariadb ; \
        echo -e '\\ny\\n$DB_ROOT_PASSWORD\\n$DB_ROOT_PASSWORD\\ny\\ny\\ny\\ny\\n' | sudo mysql_secure_installation ; \
        sudo mysql -p${DB_ROOT_PASSWORD} -e \"CREATE DATABASE ${DB_NAME};CREATE USER '${DB_USER}'@'${FRONTEND_IP}' IDENTIFIED BY '${DB_PASSWORD}';CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'${FRONTEND_IP}';GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';FLUSH PRIVILEGES;\""
    log "Backend setup completed"
}

setup_frontend() {
    log "Deploying on frontend server"
    if [ "$WEB_SERVER" == "apache" ]; then
        ssh_execute_command $FRONTEND_IP "sudo dnf install epel-release -y ; \
            sudo dnf install -y httpd php php-mysqlnd php-fpm php-json php-gd php-xml php-mbstring wget unzip firewalld certbot python3-certbot-apache ; \
            sudo systemctl start firewalld ; \
            sudo systemctl enable firewalld ; \
            sudo firewall-cmd --permanent --add-service=https ; \
            sudo firewall-cmd --permanent --add-service=http ; \
            sudo firewall-cmd --reload ; \
            echo \"<VirtualHost *:80>
    ServerName $DOMAIN
    DocumentRoot /var/www/html
    ErrorLog /var/log/httpd/${DOMAIN}-error_log
    CustomLog /var/log/httpd/${DOMAIN}-access_log common
</VirtualHost>\" > /tmp/$DOMAIN.conf ; \
            sudo cp /tmp/$DOMAIN.conf /etc/httpd/conf.d/$DOMAIN.conf ; \
            sudo systemctl start httpd ; \
            sudo systemctl enable httpd ; \
            sudo certbot --apache -d $DOMAIN --non-interactive --agree-tos --email $WP_ADMIN_EMAIL ; \
            getsebool -a | grep -E \"^httpd_(unified|can_network_connect)?(_db)?\s\" ; \
            sudo setsebool -P httpd_can_network_connect 1 ; \
            sudo setsebool -P httpd_can_network_connect_db 1 ; \
            sudo setsebool -P httpd_unified 1 ; \
            getsebool -a | grep -E \"^httpd_(unified|can_network_connect)?(_db)?\s\""
        log "Frontend setup with Apache completed"
    elif [ "$WEB_SERVER" == "nginx" ]; then
        log "Frontend setup with Nginx Not yet implemented"
        exit 1
    else
        log "Unsupported web server: $WEB_SERVER"
        exit 1
    fi

    # Install wp-cli and configure WordPress
    log "Installing wp-cli and configuring WordPress"
    ssh_execute_command $FRONTEND_IP "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar 
        php wp-cli.phar --info 
        chmod +x wp-cli.phar
        sudo mv wp-cli.phar /usr/bin/wp
        sudo chown apache:apache -R /var/www/html
        sudo chmod 755 -R /var/www/html
        sudo -u apache wp core download --path=/var/www/html
        sudo -u apache wp config create --dbname=${DB_NAME} --dbuser=${DB_USER} --dbpass=${DB_PASSWORD} --path=/var/www/html --dbhost=${BACKEND_IP}
        sudo -u apache wp core install --url=$DOMAIN --title='WordPress Site' --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASSWORD --admin_email=$WP_ADMIN_EMAIL --skip-email --path=/var/www/html/
        sudo -u apache wp core language install $WP_LANGUAGE --path=/var/www/html/
        sudo -u apache wp core language activate $WP_LANGUAGE --path=/var/www/html/
        sudo -u apache wp theme install $WP_THEME --path=/var/www/html/
        sudo -u apache wp theme activate $WP_THEME --path=/var/www/html/"
    log "WordPress configuration completed"
}

load_config
load_env_vars
setup_backend
setup_frontend
check_services_status
echo "https://$DOMAIN/wp-login.php"
