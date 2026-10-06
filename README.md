# Pterodactyl 2.0 Unofficial Auto-Installer

<p align="center">
  <img src="https://raw.githubusercontent.com/pterodactyl/panel/develop/public/assets/svgs/pterodactyl.svg" width="120" alt="Pterodactyl Logo" /><br>
  <b>An interactive, fully automated installer for Pterodactyl Panel v2.0 & Wings</b><br>
  <i>Preserving the classic, beloved installer experience while powering next-generation Pterodactyl 2.0</i>
</p>

<p align="center">
  <a href="https://github.com/xlr9/ptero-v2-installer/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg?style=flat-square" alt="License"></a>
  <a href="https://github.com/pterodactyl/panel/tree/2.0-develop"><img src="https://img.shields.io/badge/Pterodactyl%20Panel-v2.0--develop-orange.svg?style=flat-square" alt="Panel v2.0"></a>
  <a href="https://www.php.net/"><img src="https://img.shields.io/badge/PHP-8.3-777BB4.svg?style=flat-square" alt="PHP 8.3"></a>
  <a href="https://nodejs.org/"><img src="https://img.shields.io/badge/Node.js-22.x-339933.svg?style=flat-square" alt="Node.js 22"></a>
  <a href="https://vite.dev/"><img src="https://img.shields.io/badge/Vite-Frontend%20Build-646CFF.svg?style=flat-square" alt="Vite"></a>
  <a href="https://ubuntu.com/"><img src="https://img.shields.io/badge/Ubuntu-24.04%20|%2022.04-E95420.svg?style=flat-square" alt="Ubuntu"></a>
</p>

---

## ⚡ Quick Start

Run the command below on your clean server as `root`:

```bash
bash <(curl -s "https://raw.githubusercontent.com/xlr9/ptero-v2-installer/main/install.sh")
```

> **Tip:** If your terminal or CDN caches raw files, append a timestamp parameter to force the latest version:
> ```bash
> bash <(curl -s "https://raw.githubusercontent.com/xlr9/ptero-v2-installer/main/install.sh?$(date +%s)")
> ```

---

## 🌟 Key Features

- **Full Pterodactyl 2.0 Support:** Downloads directly from the official `2.0-develop` branch (Laravel 13 & PHP 8.3).
- **Automated Frontend Compilation:** Installs Node.js 22 and compiles the brand-new React 19 & Vite frontend assets during installation.
- **Smart Swap Protection:** Detects systems with limited physical RAM (<= 2GB) and automatically allocates a temporary swap file to prevent the compiler from crashing during asset compilation.
- **Input Sanitization:** Automatically scrubs terminal escape sequences, invisible Unicode characters, and whitespace to prevent `Invalid URI` configuration errors.
- **Zero-Conflict Database Setup:** Manages MariaDB clean installations, user drops, and permission grants without crashing on pre-existing users.
- **Complete SSL Automation:** Uses Certbot to configure Let's Encrypt certificates for **both** the Panel (`panel.domain.com`) and Wings (`node.domain.com`).
- **Classic 1:1 Interface:** Exact menu layout (`[0]` to `[7]`), banners, prompt ordering, and color coding identical to the original classic installer.

---

## 📋 Interactive Menu

```text
=================================================================
                   Pterodactyl Installation Script               
                      Compatible with Panel v2.0                 
=================================================================
* Running on Ubuntu 24.04.
* Detected Server IP: 1.2.3.4

* Please select an option:
  * [0] Install the panel
  * [1] Install Wings
  * [2] Install both [0] and [1]
  * [3] Upgrade the panel
  * [4] Upgrade Wings
  * [5] Upgrade both [3] and [4]
  * [6] Uninstall
  * [7] Exit
```

| Option | Action | Description |
| :---: | :--- | :--- |
| `[0]` | **Install the panel** | Installs PHP 8.3, MariaDB, Redis, Node.js 22, builds Panel 2.0, sets up Nginx & SSL. |
| `[1]` | **Install Wings** | Installs Docker, the Wings daemon binary, configures systemd, firewall, and provisions Node SSL. |
| `[2]` | **Install both** | Sequential automated installation of both Panel 2.0 and Wings on the same machine. |
| `[3]` | **Upgrade the panel** | Pulls the newest `2.0-develop` commit, runs Composer, rebuilds Vite assets, runs migrations & clears caches. |
| `[4]` | **Upgrade Wings** | Downloads the latest official Wings binary, replaces executable, and restarts systemd service. |
| `[5]` | **Upgrade both** | Upgrades Panel and Wings together. |
| `[6]` | **Uninstall** | Interactive uninstaller to purge Panel, Wings, or entire Pterodactyl environment. |
| `[7]` | **Exit** | Exits the installer safely. |

---

## 🖥️ System Requirements

### Supported Operating Systems:
- **Ubuntu 24.04 LTS (Noble Numbat)** *(Recommended)*
- **Ubuntu 22.04 LTS (Jammy Jellyfish)**
- **Debian 12 (Bookworm)**

### Minimum Hardware:
- **CPU:** 1 Core (2+ Cores recommended)
- **RAM:** 1 GB (2 GB+ recommended; installer auto-creates swap for building Vite assets)
- **Disk:** 10 GB SSD / NVMe

### Network & DNS:
Ensure your DNS records point to your server IP prior to installation:
- `panel.yourdomain.com` -> `SERVER_IP` (A Record)
- `node.yourdomain.com`  -> `SERVER_IP` (A Record, if hosting node on the same machine)

---

## 📖 Step-by-Step Guide

### 1. Panel Installation
1. Run the installer command:
   ```bash
   bash <(curl -s "https://raw.githubusercontent.com/xlr9/ptero-v2-installer/main/install.sh")
   ```
2. Choose `[0] Install the panel`.
3. Provide your desired settings:
   - **Database Name / User / Password** (leave blank for defaults and auto-generated secure password).
   - **Timezone** (e.g. `UTC`, `Europe/London`, `America/New_York`).
   - **FQDN**: Enter your panel domain (e.g. `panel.sloome.net`).
   - **UFW**: Configure firewall (`y` or `n`).
   - **Let's Encrypt**: Enable HTTPS (`y`) and enter your email address.
   - **Admin Account**: Enter email, username, first name, last name, and password.
4. Once completed, your Panel is accessible immediately at `https://panel.yourdomain.com`.

---

### 2. Wings & Node Setup

Pterodactyl 2.0 requires SSL on both the Panel and Wings when running over HTTPS.

#### Step A: Run Wings Installer
1. Run the installer and choose `[1] Install Wings`.
2. Answer `y` to configure Let's Encrypt SSL.
3. Enter your Node FQDN (e.g. `node.sloome.net`) and email address.
4. The script installs Docker, downloads Wings, configures the systemd daemon, and provisions your SSL certificate to `/etc/letsencrypt/live/node.yourdomain.com/fullchain.pem`.

#### Step B: Link Node in the Panel
1. Open your Panel: `https://panel.yourdomain.com`
2. Navigate to **Admin -> Nodes -> Create New**.
3. Fill in the node details:
   - **FQDN:** `node.yourdomain.com`
   - **Behind Proxy:** Not Behind Proxy
   - **SSL:** Enabled (Use SSL Connection)
   - **Daemon Port:** `8080`
   - **Daemon SFTP Port:** `2022`
4. Click **Create Node**, then go to the **Configuration** tab.
5. Click **Generate Token** and copy the **Auto-Deploy** command:
   ```bash
   cd /etc/pterodactyl && sudo wings configure --panel-url https://panel.yourdomain.com --token ...
   ```
6. Paste the command into your server terminal.
7. Start Wings:
   ```bash
   systemctl enable --now wings
   systemctl restart wings
   ```
8. Refresh your Panel: your node will immediately show **Online 🟢**.

---

## 🔧 Maintenance & Management

```bash
# Check Wings service status & live logs
systemctl status wings
journalctl -u wings -n 50 -f

# Run Wings in interactive debug mode
wings --debug

# Restart Pterodactyl Queue worker
systemctl restart pteroq.service

# Check Nginx status
systemctl status nginx
nginx -t

# Manually clear Panel application cache
cd /var/www/pterodactyl && php artisan view:clear && php artisan config:clear
```

---

## 🛡️ Firewall & Port Reference

| Port | Protocol | Purpose |
| :---: | :---: | :--- |
| `22` | TCP | SSH Server Access |
| `80` | TCP | HTTP / Let's Encrypt Verification |
| `443` | TCP | HTTPS Web Traffic (Panel) |
| `8080` | TCP | Wings Daemon API |
| `2022` | TCP | Wings SFTP Server |

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).  
Pterodactyl is a registered trademark of Dane Everitt and Pterodactyl Software. This auto-installer is an independent community project.
