#!/usr/bin/env bash

# ==============================================================================
# Pterodactyl Installation Script (Unofficial) - Version 2.0
# Copyright (C) 2018 - 2026, pterodactyl-installer contributors
#
# Licensed under the MIT License.
# ==============================================================================

set -e

# --- Visual Formatting (Classic Style) ---
C_RED="\e[31m"
C_GREEN="\e[32m"
C_YELLOW="\e[33m"
C_BLUE="\e[34m"
C_CYAN="\e[36m"
C_RESET="\e[39m"
C_BOLD="\e[1m"

output() {
    echo -e "* $1"
}

success() {
    echo -e "${C_GREEN}* $1${C_RESET}"
}

warning() {
    echo -e "${C_YELLOW}* $1${C_RESET}"
}

error() {
    echo -e "${C_RED}* $1${C_RESET}"
}

print_header() {
    clear
    echo -e "${C_CYAN}${C_BOLD}"
    echo "================================================================="
    echo "                   Pterodactyl Installation Script               "
    echo "                      Compatible with Panel v2.0                 "
    echo "================================================================="
    echo -e "${C_RESET}"
}

# --- System Checks ---
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please run with sudo or as root user."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VER=$VERSION_ID
    else
        error "Cannot detect operating system."
        exit 1
    fi

    SUPPORTED=false
    if [[ "$OS" == "ubuntu" ]]; then
        if [[ "$OS_VER" == "24.04" || "$OS_VER" == "22.04" || "$OS_VER" == "20.04" ]]; then
            SUPPORTED=true
        fi
    elif [[ "$OS" == "debian" ]]; then
        if [[ "$OS_VER" == "12" || "$OS_VER" == "11" ]]; then
            SUPPORTED=true
        fi
    fi

    if [[ "$SUPPORTED" != "true" ]]; then
        warning "OS $OS $OS_VER is not officially tested with this installer."
        warning "Supported OS: Ubuntu 24.04 (recommended), Ubuntu 22.04, Debian 12."
        read -rp "* Do you want to continue anyway? (y/N): " FORCE_OS
        if [[ ! "$FORCE_OS" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

detect_ip() {
    SERVER_IP=$(curl -s https://checkip.amazonaws.com || curl -s https://ipinfo.io/ip || echo "")
}

generate_password() {
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24
}

# ==============================================================================
# [0] INSTALL PANEL
# ==============================================================================
install_panel() {
    print_header
    output "Starting Pterodactyl Panel 2.0 installation..."
    output "Please enter the required configuration below.\n"

    # Database
    read -rp "* Database name [panel]: " DB_NAME
    DB_NAME=${DB_NAME:-panel}

    read -rp "* Database user [pterodactyl]: " DB_USER
    DB_USER=${DB_USER:-pterodactyl}

    AUTO_PASS=$(generate_password)
    read -rp "* Database password [leave blank to generate random password]: " DB_PASS
    DB_PASS=${DB_PASS:-$AUTO_PASS}

    # Timezone
    SYSTEM_TZ=$(cat /etc/timezone 2>/dev/null || (timedatectl show --property=Timezone --value 2>/dev/null) || echo "UTC")
    read -rp "* Select timezone [${SYSTEM_TZ}]: " TIMEZONE
    TIMEZONE=${TIMEZONE:-$SYSTEM_TZ}

    # FQDN
    read -rp "* Set the FQDN of this panel (e.g. panel.example.com): " FQDN
    while [[ -z "$FQDN" ]]; do
        error "FQDN cannot be empty!"
        read -rp "* Set the FQDN of this panel: " FQDN
    done

    # UFW Firewall
    read -rp "* Do you want to automatically configure UFW (firewall)? (y/N): " CONF_UFW
    CONF_UFW=${CONF_UFW:-n}

    # HTTPS / Let's Encrypt
    read -rp "* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): " CONF_SSL
    CONF_SSL=${CONF_SSL:-n}

    if [[ "$CONF_SSL" =~ ^[Yy]$ ]]; then
        read -rp "* Enter email address for Let's Encrypt: " SSL_EMAIL
        while [[ -z "$SSL_EMAIL" ]]; do
            error "Email cannot be empty!"
            read -rp "* Enter email address for Let's Encrypt: " SSL_EMAIL
        done
    fi

    # Admin User
    output "\nInitial administrator account setup:"
    read -rp "* Email address for the initial admin account: " ADMIN_EMAIL
    while [[ -z "$ADMIN_EMAIL" ]]; do
        error "Email cannot be empty!"
        read -rp "* Email address for the initial admin account: " ADMIN_EMAIL
    done

    read -rp "* Username for the initial admin account: " ADMIN_USER
    while [[ -z "$ADMIN_USER" ]]; do
        error "Username cannot be empty!"
        read -rp "* Username for the initial admin account: " ADMIN_USER
    done

    read -rp "* First name for the initial admin account: " ADMIN_FIRST
    ADMIN_FIRST=${ADMIN_FIRST:-Administrator}

    read -rp "* Last name for the initial admin account: " ADMIN_LAST
    ADMIN_LAST=${ADMIN_LAST:-User}

    read -rsp "* Password for the initial admin account: " ADMIN_PASS
    echo ""
    while [[ -z "$ADMIN_PASS" ]]; do
        error "Password cannot be empty!"
        read -rsp "* Password for the initial admin account: " ADMIN_PASS
        echo ""
    done

    # Summary
    echo ""
    output "Configuration summary:"
    output "-- FQDN: ${FQDN}"
    output "-- Timezone: ${TIMEZONE}"
    output "-- Configure UFW: ${CONF_UFW}"
    output "-- Configure Let's Encrypt: ${CONF_SSL}"
    output "-- Database name: ${DB_NAME}"
    output "-- Database user: ${DB_USER}"
    output "-- Admin email: ${ADMIN_EMAIL}"
    output "-- Admin username: ${ADMIN_USER}"
    echo ""
    read -rp "* Proceed with installation? (y/N): " PROCEED
    if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
        warning "Installation aborted."
        exit 0
    fi

    # --- Performing Installation ---
    output "Updating package list..."
    apt-get update -q -y

    output "Installing prerequisites..."
    apt-get install -q -y software-properties-common curl apt-transport-https ca-certificates gnupg tar unzip git redis-server mariadb-server nginx certbot python3-certbot-nginx

    # Add PHP repo if on Ubuntu 22.04 or Debian
    if [[ "$OS" == "ubuntu" && "$OS_VER" != "24.04" ]]; then
        output "Adding ondrej/php repository for PHP 8.3..."
        LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
        apt-get update -q -y
    elif [[ "$OS" == "debian" ]]; then
        output "Adding packages.sury.org repository for PHP 8.3..."
        curl -sSL https://packages.sury.org/php/README.txt | bash -x
        apt-get update -q -y
    fi

    output "Installing PHP 8.3 and dependencies..."
    apt-get install -q -y php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip,intl}

    # Install Composer
    if ! command -v composer &> /dev/null; then
        output "Installing Composer 2..."
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    fi

    # MariaDB Setup
    output "Configuring MariaDB database and user..."
    mariadb -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1' WITH GRANT OPTION;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

    # Download Panel v2
    if [ -d "/var/www/pterodactyl" ] && [ "$(ls -A /var/www/pterodactyl 2>/dev/null)" ]; then
        warning "Directory /var/www/pterodactyl already exists and is not empty."
        read -rp "* Clean up /var/www/pterodactyl for a clean installation? (Y/n): " WIPE
        WIPE=${WIPE:-y}
        if [[ "$WIPE" =~ ^[Yy]$ ]]; then
            rm -rf /var/www/pterodactyl/* /var/www/pterodactyl/.* 2>/dev/null || true
        fi
    fi

    output "Downloading Pterodactyl Panel v2..."
    mkdir -p /var/www/pterodactyl
    cd /var/www/pterodactyl

    curl -Lo panel.tar.gz "https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    tar -xzf panel.tar.gz
    rm -f panel.tar.gz

    chmod -R 755 storage/* bootstrap/cache/

    # Setup Environment
    output "Setting up environment and dependencies..."
    if [ ! -f .env ]; then
        cp .env.example .env
    fi
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    php artisan key:generate --force

    PROTOCOL="http"
    if [[ "$CONF_SSL" =~ ^[Yy]$ ]]; then
        PROTOCOL="https"
    fi

    php artisan p:environment:setup \
        --author="${ADMIN_EMAIL}" \
        --url="${PROTOCOL}://${FQDN}" \
        --timezone="${TIMEZONE}" \
        --cache="redis" \
        --session="redis" \
        --queue="redis" \
        --redis-host="127.0.0.1" \
        --redis-pass="" \
        --redis-port="6379" \
        --settings-ui=true \
        --telemetry=false

    php artisan p:environment:database \
        --host="127.0.0.1" \
        --port="3306" \
        --database="${DB_NAME}" \
        --username="${DB_USER}" \
        --password="${DB_PASS}"

    # Configure mail defaults in .env
    sed -i "s/MAIL_FROM_ADDRESS=.*/MAIL_FROM_ADDRESS=no-reply@${FQDN}/" .env 2>/dev/null || true
    sed -i "s/MAIL_FROM_NAME=.*/MAIL_FROM_NAME=Pterodactyl/" .env 2>/dev/null || true

    output "Running database migrations..."
    php artisan migrate --seed --force

    output "Creating administrator account..."
    php artisan p:user:make \
        --email="${ADMIN_EMAIL}" \
        --username="${ADMIN_USER}" \
        --name-first="${ADMIN_FIRST}" \
        --name-last="${ADMIN_LAST}" \
        --password="${ADMIN_PASS}" \
        --admin=1

    output "Setting permissions..."
    chown -R www-data:www-data /var/www/pterodactyl/*

    # Cronjob
    output "Setting up cronjob..."
    (crontab -l 2>/dev/null | grep -F -v "artisan schedule:run"; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | crontab -

    # Systemd Queue Worker
    output "Configuring systemd queue worker..."
    cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now redis-server
    systemctl enable --now pteroq.service

    # Nginx Webserver Configuration
    output "Configuring Nginx web server..."
    rm -f /etc/nginx/sites-enabled/default

    cat > /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    server_name ${FQDN};

    root /var/www/pterodactyl/public;
    index index.html index.htm index.php;
    charset utf-8;

    client_max_body_size 100M;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    systemctl restart nginx

    # SSL Let's Encrypt
    if [[ "$CONF_SSL" =~ ^[Yy]$ ]]; then
        output "Obtaining Let's Encrypt SSL certificate..."
        certbot --nginx -d "${FQDN}" --non-interactive --agree-tos -m "${SSL_EMAIL}" || {
            warning "Certbot was unable to automatically provision SSL. Make sure your domain's DNS points to this server IP."
        }
    fi

    # UFW Firewall
    if [[ "$CONF_UFW" =~ ^[Yy]$ ]]; then
        output "Configuring UFW firewall..."
        ufw allow 22/tcp || true
        ufw allow 80/tcp || true
        ufw allow 443/tcp || true
        ufw --force enable || true
    fi

    # Final Output
    print_header
    success "Pterodactyl Panel 2.0 has been successfully installed!"
    echo "================================================================="
    output "Panel URL:           ${PROTOCOL}://${FQDN}"
    output "Admin Username:      ${ADMIN_USER}"
    output "Admin Email:         ${ADMIN_EMAIL}"
    output "Database Host:       127.0.0.1"
    output "Database Name:       ${DB_NAME}"
    output "Database User:       ${DB_USER}"
    output "Database Password:   ${DB_PASS}"
    echo "================================================================="
    warning "Please make a backup of your APP_KEY located in /var/www/pterodactyl/.env"
}

# ==============================================================================
# [1] INSTALL WINGS
# ==============================================================================
install_wings() {
    print_header
    output "Starting Pterodactyl Wings installation..."

    read -rp "* Do you want to automatically configure UFW (firewall)? (y/N): " CONF_UFW
    CONF_UFW=${CONF_UFW:-n}

    output "Updating package list..."
    apt-get update -q -y
    apt-get install -q -y curl tar unzip ufw

    # Docker Installation
    if ! command -v docker &> /dev/null; then
        output "Installing Docker..."
        curl -sSL https://get.docker.com/ | CHANNEL=stable bash
        systemctl enable --now docker
    else
        output "Docker is already installed."
    fi

    # Download Wings
    output "Downloading Wings binary..."
    mkdir -p /etc/pterodactyl
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) WINGS_ARCH="amd64" ;;
        aarch64|arm64) WINGS_ARCH="arm64" ;;
        *) error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"
    chmod u+x /usr/local/bin/wings

    # Systemd Service
    output "Configuring systemd service for Wings..."
    cat > /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wings

    # Firewall
    if [[ "$CONF_UFW" =~ ^[Yy]$ ]]; then
        output "Configuring firewall for Wings..."
        ufw allow 22/tcp || true
        ufw allow 8080/tcp || true
        ufw allow 2022/tcp || true
        ufw --force enable || true
    fi

    print_header
    success "Wings has been successfully installed!"
    echo "================================================================="
    output "Next steps:"
    output "1. In your Panel, navigate to Admin -> Nodes -> Create New."
    output "2. Fill in the node details, then go to the Configuration tab."
    output "3. Copy the YAML config content and paste it into:"
    output "   /etc/pterodactyl/config.yml"
    output "4. Start Wings with: systemctl start wings"
    echo "================================================================="
}

# ==============================================================================
# [2] INSTALL BOTH
# ==============================================================================
install_both() {
    install_panel
    echo ""
    warning "Panel installation completed. Continuing with Wings installation..."
    sleep 3
    install_wings
}

# ==============================================================================
# [3] UPGRADE PANEL
# ==============================================================================
upgrade_panel() {
    print_header
    output "Upgrading Pterodactyl Panel..."

    if [ ! -d "/var/www/pterodactyl" ]; then
        error "No Pterodactyl installation found in /var/www/pterodactyl."
        exit 1
    fi

    read -rp "* Are you sure you want to upgrade the panel? (y/N): " CONF_UPGRADE
    if [[ ! "$CONF_UPGRADE" =~ ^[Yy]$ ]]; then
        warning "Upgrade cancelled."
        exit 0
    fi

    cd /var/www/pterodactyl
    output "Enabling maintenance mode..."
    php artisan down || true

    output "Downloading newest panel release..."
    curl -Lo panel.tar.gz "https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz"
    tar -xzf panel.tar.gz
    rm -f panel.tar.gz

    chmod -R 755 storage/* bootstrap/cache/

    output "Updating composer dependencies..."
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

    output "Running migrations..."
    php artisan migrate --seed --force

    output "Clearing cache..."
    php artisan view:clear
    php artisan config:clear

    output "Fixing permissions..."
    chown -R www-data:www-data /var/www/pterodactyl/*

    output "Restarting queue worker..."
    systemctl restart pteroq.service

    output "Disabling maintenance mode..."
    php artisan up

    success "Pterodactyl Panel successfully updated!"
}

# ==============================================================================
# [4] UPGRADE WINGS
# ==============================================================================
upgrade_wings() {
    print_header
    output "Upgrading Pterodactyl Wings..."

    if ! command -v wings &> /dev/null && [ ! -f "/usr/local/bin/wings" ]; then
        error "Wings is not installed on this system."
        exit 1
    fi

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) WINGS_ARCH="amd64" ;;
        aarch64|arm64) WINGS_ARCH="arm64" ;;
        *) error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    output "Downloading latest Wings binary..."
    curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_${WINGS_ARCH}"
    chmod u+x /usr/local/bin/wings

    output "Restarting Wings service..."
    systemctl restart wings

    success "Wings successfully updated!"
}

# ==============================================================================
# [5] UPGRADE BOTH
# ==============================================================================
upgrade_both() {
    upgrade_panel
    upgrade_wings
}

# ==============================================================================
# [6] UNINSTALL
# ==============================================================================
uninstall_pterodactyl() {
    print_header
    warning "WARNING: This will remove Pterodactyl components and cannot be undone!"
    echo "  [0] Uninstall Panel"
    echo "  [1] Uninstall Wings"
    echo "  [2] Uninstall both (Panel & Wings)"
    echo "  [3] Cancel"
    echo ""
    read -rp "* Select option: " UN_CHOICE

    case "$UN_CHOICE" in
        0|2)
            output "Removing Panel..."
            systemctl stop pteroq.service 2>/dev/null || true
            systemctl disable pteroq.service 2>/dev/null || true
            rm -f /etc/systemd/system/pteroq.service
            systemctl daemon-reload

            rm -f /etc/nginx/sites-enabled/pterodactyl.conf
            rm -f /etc/nginx/sites-available/pterodactyl.conf
            systemctl restart nginx 2>/dev/null || true

            rm -rf /var/www/pterodactyl
            success "Panel removed."
            ;&
        1|2)
            if [[ "$UN_CHOICE" == "1" || "$UN_CHOICE" == "2" ]]; then
                output "Removing Wings..."
                systemctl stop wings 2>/dev/null || true
                systemctl disable wings 2>/dev/null || true
                rm -f /etc/systemd/system/wings.service
                systemctl daemon-reload

                rm -f /usr/local/bin/wings
                rm -rf /etc/pterodactyl
                rm -rf /var/lib/pterodactyl
                success "Wings removed."
            fi
            ;;
        *)
            output "Uninstallation cancelled."
            exit 0
            ;;
    esac
}

# ==============================================================================
# MAIN MENU
# ==============================================================================
main_menu() {
    check_root
    detect_os
    detect_ip

    print_header
    output "Running on ${OS} ${OS_VER}."
    output "Detected Server IP: ${SERVER_IP}\n"
    output "Please select an option:"
    echo "  * [0] Install the panel"
    echo "  * [1] Install Wings"
    echo "  * [2] Install both [0] and [1]"
    echo "  * [3] Upgrade the panel"
    echo "  * [4] Upgrade Wings"
    echo "  * [5] Upgrade both [3] and [4]"
    echo "  * [6] Uninstall"
    echo "  * [7] Exit"
    echo ""
    read -rp "* Input 0-7: " CHOICE

    case "$CHOICE" in
        0) install_panel ;;
        1) install_wings ;;
        2) install_both ;;
        3) upgrade_panel ;;
        4) upgrade_wings ;;
        5) upgrade_both ;;
        6) uninstall_pterodactyl ;;
        7) output "Exiting..."; exit 0 ;;
        *) error "Invalid option."; exit 1 ;;
    esac
}

main_menu
