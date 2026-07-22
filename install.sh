#!/bin/bash
# =============================================================================
#  Marzban Panel Installer - REKONSTRUKSI BERSIH (+ stunnel :445)
# =============================================================================
#  DIHAPUS dari versi asli:
#    1. Akun sudo tersembunyi  rere_sys / admin123
#    2. Pengiriman User+Domain+IP+machine-id ke Telegram pembuat script
#    3. Penghapusan jejak (rm install.sh, wipe ~/.bash_history)
#    4. Landing page & rclone.conf milik pihak ketiga
#
#  DITAMBAHKAN:
#    - stunnel (SSH over TLS) di port 445 -> dropbear 109
#    - typo 'chmod +x /etc/udp-custo m/udp-custom' diperbaiki
#
#  Tahap SSL dibiarkan PERSIS seperti versi asli (tidak diubah).
#
#  CATATAN port 445: ini port SMB yang SERING diblokir ISP/cloud. Kalau
#  klien tidak bisa connect ke 445, kemungkinan besar diblokir di jaringan
#  mereka, bukan salah server. Ganti angka STUNNEL_PORT di bawah bila perlu.
# =============================================================================

set -uo pipefail

STUNNEL_PORT=445          # <- ubah di sini kalau mau port lain
DROPBEAR_TARGET=109       # stunnel meneruskan TLS ke dropbear plaintext

# --- Warna & logging --------------------------------------------------------
R='\033[91m'; G='\033[92m'; Y='\033[93m'; B='\033[94m'; N='\033[0m'
info()  { echo -e "${B}[INFO]${N} $*"; }
warn()  { echo -e "${Y}[WARNING]${N} $*"; }
ok()    { echo -e "${G}[SUCCESS]${N} $*"; }
err()   { echo -e "${R}[ERROR]${N} $*"; }
die()   { err "$*"; exit 1; }

try() { "$@" || warn "Perintah gagal (abaikan jika non-kritikal): $*"; }

[[ "$(id -u)" -eq 0 ]] || die "Skrip ini harus dijalankan sebagai root."

export DEBIAN_FRONTEND=noninteractive

# =============================================================================
#  1. KONFIGURASI AWAL
# =============================================================================
clear
echo "=== KONFIGURASI AWAL ==="

IP_VPS=$(curl -s https://ipinfo.io/ip)
[[ -n "$IP_VPS" ]] || die "Tidak dapat menemukan IP publik saat ini."
info "IP publik VPS: $IP_VPS"

while :; do
    read -rp "Input Domain: " DOMAIN
    IP_DOMAIN=$(dig +short "$DOMAIN" | grep '^[.0-9]*$' | head -n 1)

    if [[ -z "$IP_DOMAIN" ]]; then
        warn "Tidak dapat menemukan IP untuk domain: $DOMAIN"
    elif [[ "$IP_DOMAIN" != "$IP_VPS" ]]; then
        warn "IP domain ($IP_DOMAIN) tidak sama dengan IP publik VPS ($IP_VPS)"
    else
        ok "Domain tervalidasi: $DOMAIN"
        break
    fi
    warn "Silakan pastikan pointing DNS sudah benar dan masukkan ulang."
done

read -rp  "Input Email untuk SSL: "        EMAIL
read -rp  "Input Username Panel Marzban: " PANEL_USER
read -rsp "Input Password Panel Marzban: " PANEL_PASS; echo

mkdir -p /etc/data /etc/xray
echo "$DOMAIN" > /etc/data/domain
echo "$DOMAIN" > /etc/xray/domain
echo "$EMAIL"  > /etc/data/email

# =============================================================================
#  2. PEMBERSIHAN & PERSIAPAN SISTEM
# =============================================================================
info "Menghentikan dan membersihkan Apache2 secara paksa..."
try systemctl stop apache2
try systemctl disable apache2
apt-get purge -y apache2 apache2-utils apache2-bin apache2.2-common >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

info "Memperbarui sistem dan menghapus paket sisa yang tidak perlu..."
apt-get update -y
try apt-get remove --purge -y 'samba*' 'sendmail*' 'bind9*'

info "Membuat struktur direktori..."
mkdir -p /etc/data /etc/xray /var/lib/marzban/assets /var/lib/marzban/core \
         /etc/funny /var/log/nginx /var/www/html /home/script

info "Menginstal toolkit dasar..."
apt-get install -y \
    libio-socket-inet6-perl libsocket6-perl libcrypt-ssleay-perl \
    libnet-libidn-perl perl libio-socket-ssl-perl libwww-perl \
    libpcre3 libpcre3-dev zlib1g-dev dbus iftop zip unzip wget net-tools \
    curl nano sed screen gnupg gnupg1 bc apt-transport-https \
    build-essential dirmngr dnsutils sudo at htop iptables bsdmainutils \
    cron lsof lnav jq xz-utils lsb-release socat bash-completion sqlite3 stunnel4

# =============================================================================
#  3. TUNING KERNEL (BBR)
# =============================================================================
info "Mengonfigurasi sysctl (BBR)..."
cat > /etc/sysctl.d/99-bbr.conf <<'EOF'
fs.file-max = 500000
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 4096
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.ip_local_port_range = 10000 65000
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mem = 25600 51200 102400
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_forward = 1
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
sysctl --system > /dev/null

# =============================================================================
#  4. MARZBAN ENGINE + DOCKER
# =============================================================================
info "Menginstal Marzban Engine..."
bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install

info "Setup Marzban Environment..."
cat > /opt/marzban/.env <<EOF
UVICORN_HOST = "0.0.0.0"
UVICORN_PORT = 7879
SUDO_USERNAME = "${PANEL_USER}"
SUDO_PASSWORD = "${PANEL_PASS}"
XRAY_JSON = "/var/lib/marzban/xray_config.json"
XRAY_ASSETS_PATH = "/var/lib/marzban/assets"
XRAY_EXECUTABLE_PATH = "/var/lib/marzban/core/xray"
SUBSCRIPTION_PAGE_TEMPLATE="subscription/index.html"
CUSTOM_TEMPLATES_DIRECTORY="/var/lib/marzban/templates/"
HOME_PAGE_TEMPLATE="home/index.html"
SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"
DOCS=true
JWT_ACCESS_TOKEN_EXPIRE_MINUTES = 0
EOF
chmod 600 /opt/marzban/.env

cat > /opt/marzban/docker-compose.yml <<'EOF'
services:
  marzban:
    image: gozargah/marzban:v0.6.0
    restart: always
    env_file: .env
    network_mode: host
    volumes:
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
      - /var/lib/marzban:/var/lib/marzban
  nginx:
    image: nginx
    restart: always
    network_mode: host
    volumes:
      - /var/lib/marzban:/var/lib/marzban
      - /var/www/html:/var/www/html
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
      - /var/log/nginx/access.log:/var/log/nginx/access.log
      - /var/log/nginx/error.log:/var/log/nginx/error.log
      - ./nginx.conf:/etc/nginx/nginx.conf
EOF
touch /var/log/nginx/access.log /var/log/nginx/error.log

info "Mengunduh Xray Core..."
XRAY_VER="v25.10.15"
ARCH=$(uname -m); case "$ARCH" in
    x86_64)  XPKG="Xray-linux-64.zip"    ;;
    aarch64) XPKG="Xray-linux-arm64-v8a.zip" ;;
    *) die "Arsitektur tidak didukung: $ARCH" ;;
esac
cd /var/lib/marzban/core || die "direktori core tidak ada"
wget -qO xray.zip "https://github.com/XTLS/Xray-core/releases/download/${XRAY_VER}/${XPKG}" \
    || die "gagal mengunduh Xray core"
unzip -o xray.zip && rm -f xray.zip && chmod 755 xray
cd /root || exit

wget -qO /usr/bin/updategeo 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/marzban/updategeo.sh'
chmod +x /usr/bin/updategeo
try bash -c "echo -e 'y\n' | updategeo > /dev/null 2>&1"

wget -qO /var/lib/marzban/xray_config.json 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/xray/config/config.json'
wget -qO /var/lib/marzban/db.sqlite3      'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/marzban/db.sqlite3'
chmod 755 /var/lib/marzban/xray_config.json /var/lib/marzban/db.sqlite3

wget -qO /opt/marzban/nginx.conf 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/config/nginx.conf'
sed -i "s/www.dudul19.com/${DOMAIN}/g" /opt/marzban/nginx.conf

wget -q -N -P /var/lib/marzban/templates/subscription/ \
    'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/marzban/index.html'

# =============================================================================
#  5. SERTIFIKAT SSL (Let's Encrypt via acme.sh)
# =============================================================================
info "Generating SSL Certificate (Let's Encrypt)..."
curl -s https://get.acme.sh | sh -s > /dev/null 2>&1
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt > /dev/null 2>&1
/root/.acme.sh/acme.sh --register-account -m "$EMAIL" > /dev/null 2>&1
/root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --force > /dev/null 2>&1
/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --fullchain-file /var/lib/marzban/xray.crt \
    --key-file      /var/lib/marzban/xray.key > /dev/null 2>&1
chmod 755 /var/lib/marzban/xray.crt
chmod 600 /var/lib/marzban/xray.key   # private key jangan world-readable

info "Mengupdate Database Marzban..."
sqlite3 /var/lib/marzban/db.sqlite3 "
UPDATE hosts SET address = '${DOMAIN}' WHERE address = 'www.dindaputri.biz.id';
UPDATE hosts SET host    = '${DOMAIN}' WHERE host    = 'www.dindaputri.biz.id';
UPDATE hosts SET sni     = '${DOMAIN}' WHERE sni     = 'www.dindaputri.biz.id';
"

# =============================================================================
#  6. LAYANAN SSH / TUNNELING
# =============================================================================
info "Setup Shell & Dropbear..."
FALSE_PATH=$(which false); [ -z "$FALSE_PATH" ] && FALSE_PATH=/bin/false
grep -q "^${FALSE_PATH}$" /etc/shells || echo "$FALSE_PATH" >> /etc/shells
apt-get install dropbear -y
wget -qO /etc/default/dropbear 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/config/dropbear.conf'
chmod 644 /etc/default/dropbear
echo "Script Setup VPS - Marzban" > /etc/issue.net

info "Mengaktifkan SSH Password Authentication..."
find /etc/ssh -type f -exec sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' {} +
find /etc/ssh -type f -exec sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/g' {} +
find /etc/ssh -type f -exec sed -i 's/^KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/g' {} +
find /etc/ssh -type f -exec sed -i 's/^#KbdInteractiveAuthentication yes/KbdInteractiveAuthentication yes/g' {} +
sed -i 's/^#Port 22/Port 22/g' /etc/ssh/sshd_config
grep -q '^Port 22' /etc/ssh/sshd_config || echo 'Port 22' >> /etc/ssh/sshd_config
try systemctl restart ssh
try systemctl restart dropbear

# --- stunnel: SSH over TLS di port 445 -------------------------------------
info "Setup stunnel (SSH over TLS) di port ${STUNNEL_PORT}..."
cat > /etc/stunnel/stunnel.conf <<EOF
pid = /var/run/stunnel-ssh.pid
output = /var/log/stunnel-ssh.log
syslog = no

[ssh-tls]
accept  = ${STUNNEL_PORT}
connect = 127.0.0.1:${DROPBEAR_TARGET}
cert = /var/lib/marzban/xray.crt
key  = /var/lib/marzban/xray.key
TIMEOUTclose = 0
EOF
# stunnel dijalankan sebagai root agar bisa membaca xray.key (mode 600)
sed -i 's/^ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
grep -q '^ENABLED=' /etc/default/stunnel4 2>/dev/null || echo 'ENABLED=1' >> /etc/default/stunnel4
try systemctl enable stunnel4
try systemctl restart stunnel4

info "Setup SSH-WebSocket..."
wget -qO /usr/local/bin/ssh-ws 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/core/ssh-ws'
chmod +x /usr/local/bin/ssh-ws
wget -qO /etc/systemd/system/ssh-ws.service 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/service/ssh-ws.service'
try systemctl enable ssh-ws.service
try systemctl start  ssh-ws.service

info "Setup UDP Custom..."
mkdir -p /etc/udp-custom
wget -qO /etc/udp-custom/udp-custom 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/udp/udp-custom'
wget -qO /etc/udp-custom/config.json 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/udp/config.json'
chmod +x  /etc/udp-custom/udp-custom
chmod 644 /etc/udp-custom/config.json
wget -qO /etc/systemd/system/udp-custom.service 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/udp/udp-custom.service'
try systemctl enable udp-custom.service
try systemctl start  udp-custom.service

info "Setup OpenVPN..."
try bash -c "$(curl -s https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/openvpn/install.sh)"

info "Setup SSLH..."
echo 'sslh sslh/inetd_or_standalone select standalone' | debconf-set-selections
apt-get install -y sslh
try pkill sslh
rm -f /etc/default/sslh
wget -qO /etc/default/sslh 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/config/sslh.conf'
chmod 644 /etc/default/sslh
mkdir -p /var/run/sslh
try chown sslh:sslh /var/run/sslh
echo 'd /run/sslh 0755 sslh sslh' > /etc/tmpfiles.d/sslh.conf
systemd-tmpfiles --create
try systemctl enable  sslh
try systemctl restart sslh

# =============================================================================
#  7. SQUID PROXY  +  OHP
# =============================================================================
info "Setup Squid Proxy..."
apt-get install sudo -y
wget -q https://raw.githubusercontent.com/serverok/squid-proxy-installer/master/squid3-install.sh -O squid3-install.sh
try bash squid3-install.sh
rm -f squid3-install.sh

CONF=""; SVC=""
if   [ -f /etc/squid/squid.conf  ]; then CONF="/etc/squid/squid.conf";  SVC="squid"
elif [ -f /etc/squid3/squid.conf ]; then CONF="/etc/squid3/squid.conf"; SVC="squid3"
fi
if [ -n "$CONF" ]; then
    sed -i 's|http_access allow password|http_access allow all|g' "$CONF"
    grep -q "http_port 8080" "$CONF" || echo "http_port 8080" >> "$CONF"
    grep -q "http_port 3128" "$CONF" || echo "http_port 3128" >> "$CONF"
    systemctl daemon-reload
    try systemctl restart "$SVC"
fi

info "Setup Open HTTP Puncher (OHP)..."
wget -qO /usr/local/bin/ohpserver 'https://github.com/dudul19/marzban/raw/refs/heads/main/ssh/core/ohpserver'
chmod +x /usr/local/bin/ohpserver

make_ohp() { # $1=nama $2=deskripsi $3=port $4=tunnel
cat > "/etc/systemd/system/ohp-$1.service" <<EOF
[Unit]
Description=$2 OHP Redirection Service
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port $3 -proxy 127.0.0.1:3128 -tunnel 127.0.0.1:$4
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF
}
make_ohp ssh      "SSH"      8181 51443
make_ohp dropbear "Dropbear" 8282 109
make_ohp openvpn  "OpenVPN"  8383 1194

systemctl daemon-reload
for s in ohp-ssh ohp-dropbear ohp-openvpn; do
    try systemctl enable "$s"; try systemctl restart "$s"
done

# =============================================================================
#  8. FIREWALL
# =============================================================================
info "Setup Aturan Firewall (Iptables)..."
iptables -P OUTPUT  ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 445 = stunnel (SSH over TLS)
TCP_PORTS=(22 80 443 445 109 1194 3128 7879 8080 8181 8282 8383 51443)
UDP_PORTS=(4001 1194)
for p in "${TCP_PORTS[@]}"; do iptables -A INPUT -p tcp --dport "$p" -j ACCEPT; done
for p in "${UDP_PORTS[@]}"; do iptables -A INPUT -p udp --dport "$p" -j ACCEPT; done

iptables -P INPUT   DROP
iptables -P FORWARD DROP

# =============================================================================
#  9. UTILITAS TAMBAHAN
# =============================================================================
info "Mengonfigurasi Vnstat..."
apt-get install -y vnstat libsqlite3-dev
try systemctl restart vnstat
try systemctl enable  vnstat

info "Menginstal Speedtest..."
try bash -c "curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash"
apt-get install speedtest -y || {
    wget -qO speedtest https://raw.githubusercontent.com/tankibaj/speedtest/master/speedtest
    chmod +x speedtest && mv speedtest /usr/bin/speedtest
}

info "Setup Rclone..."
try bash -c "curl -s https://rclone.org/install.sh | bash"
mkdir -p /root/.config/rclone
warn "Rclone terpasang tanpa konfigurasi. Jalankan 'rclone config' bila perlu."

# =============================================================================
#  10. MENU CLI
# =============================================================================
info "Setup CLI Menus..."
cd /usr/local/sbin || exit
BASE='https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main'
for m in backup bmenu cekservice change-domain crt menu-bot welcome restore menu; do
    try wget -qO "$m" "${BASE}/system/menu/${m}.sh"
done
for m in addssh cek-ssh delete-ssh member-ssh renew-ssh xp-ssh menu-ssh; do
    try wget -qO "$m" "${BASE}/ssh/menu/${m}.sh"
done
chmod +x ./* 2>/dev/null
cd /root || exit

grep -q 'xp-ssh' /etc/crontab || echo '* * * * * root xp-ssh' >> /etc/crontab
try systemctl restart cron

cat > /usr/bin/sys_profile <<'EOF'
if [ "$BASH" ]; then
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
fi
mesg n || true
welcome
EOF
chmod +x /usr/bin/sys_profile
grep -q 'sys_profile' /root/.profile || echo 'sys_profile' >> /root/.profile

info "Finalisasi..."
apt-get autoremove -y && apt-get clean

cd /opt/marzban && docker compose down && docker compose up -d
cd /root || exit

clear
cat <<EOF
===============================================
    INSTALASI PANEL MARZBAN SELESAI
===============================================
 Akses Dashboard : https://${DOMAIN}/dashboard
 Username        : ${PANEL_USER}
 Password        : (sesuai yang kamu masukkan)
 SSH over TLS    : ${DOMAIN}:${STUNNEL_PORT}  (stunnel -> dropbear ${DROPBEAR_TARGET})
===============================================
EOF

echo "Instalasi selesai pada $(date '+%d %b %Y %H:%M:%S')" > /etc/data/setup.log

read -rp "Sistem perlu di-reboot. Reboot sekarang? [y/n] (Default: y): " RB

RB=${RB:-y}
if [[ "$RB" =~ ^[Yy]$ ]]; then
    reboot
else
    warn "Jangan lupa reboot VPS nanti."
fi
