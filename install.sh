#!/bin/bash
# =============================================================================
#  Marzban Panel Installer - REKONSTRUKSI BERSIH
# =============================================================================
#  Disusun ulang dari binary Rust "install.sh"
#  (sha256 8cb88b9371719300488013464d6bf42199604b59913d886a5c4dbfbc7e10609b)
#
#  DIHAPUS dari versi asli:
#    1. Akun sudo tersembunyi  rere_sys / admin123
#    2. Pengiriman User+Domain+IP+machine-id ke Telegram pembuat script
#    3. Penghapusan jejak (rm install.sh, wipe ~/.bash_history)
#    4. Landing page & rclone.conf milik pihak ketiga
#
#  Lihat CATATAN KEAMANAN di bagian bawah file untuk hal yang masih
#  perlu kamu putuskan sendiri.
# =============================================================================

set -uo pipefail

# --- Warna & logging --------------------------------------------------------
R='\033[91m'; G='\033[92m'; Y='\033[93m'; B='\033[94m'; N='\033[0m'
info()  { echo -e "${B}[INFO]${N} $*"; }
warn()  { echo -e "${Y}[WARNING]${N} $*"; }
ok()    { echo -e "${G}[SUCCESS]${N} $*"; }
err()   { echo -e "${R}[ERROR]${N} $*"; }
die()   { err "$*"; exit 1; }

# Perintah non-kritikal: gagal tidak menghentikan instalasi
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

# Validasi domain harus mengarah ke IP VPS ini
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

# --- Subdomain khusus SSH-over-TLS ------------------------------------------
# HAProxy memilah trafik di :443 berdasarkan SNI. Jalur SSH butuh nama host
# sendiri karena stunnel dan Nginx sama-sama bicara TLS.
read -rp "Input Subdomain untuk SSH+SSL (Default: ssh.${DOMAIN}): " SSH_DOMAIN
SSH_DOMAIN=${SSH_DOMAIN:-ssh.${DOMAIN}}

IP_SSH=$(dig +short "$SSH_DOMAIN" | grep '^[.0-9]*$' | head -n 1)
if [[ -z "$IP_SSH" ]]; then
    die "Subdomain $SSH_DOMAIN belum di-pointing. Buat A record ke $IP_VPS dulu."
elif [[ "$IP_SSH" != "$IP_VPS" ]]; then
    warn "IP $SSH_DOMAIN ($IP_SSH) != IP VPS ($IP_VPS)."
    warn "Kalau ini karena Cloudflare proxy (orange cloud), MATIKAN dulu."
    warn "CF menerminasi TLS dan hanya meneruskan HTTP - SSH+SSL akan gagal."
    read -rp "Tetap lanjutkan? [y/N]: " GO
    [[ "$GO" =~ ^[Yy]$ ]] || die "Dibatalkan."
else
    ok "Subdomain SSH tervalidasi: $SSH_DOMAIN"
fi

read -rp  "Input Email untuk SSL: "        EMAIL
read -rp  "Input Username Panel Marzban: " PANEL_USER
read -rsp "Input Password Panel Marzban: " PANEL_PASS; echo

mkdir -p /etc/data /etc/xray
echo "$DOMAIN"     > /etc/data/domain
echo "$DOMAIN"     > /etc/xray/domain
echo "$SSH_DOMAIN" > /etc/data/ssh_domain
echo "$EMAIL"      > /etc/data/email

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
    cron lsof lnav jq xz-utils lsb-release socat bash-completion sqlite3

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
# CATATAN: marzban.sh resmi mengakhiri install_command() dengan
# follow_marzban_logs() -> "docker compose logs -f", yang blocking selamanya
# dan membuat installer ini menggantung di sini. Unduh dulu, lumpuhkan
# pemanggilan itu, baru jalankan.
curl -sL -o /tmp/marzban.sh https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh \
    || die "Gagal mengunduh marzban.sh"
sed -i -E 's|^([[:space:]]*)follow_marzban_logs[[:space:]]*$|\1: # log-follow dinonaktifkan|' /tmp/marzban.sh
grep -qE '^[[:space:]]*follow_marzban_logs[[:space:]]*$' /tmp/marzban.sh \
    && warn "Masih ada pemanggilan follow_marzban_logs - installer bisa menggantung."
bash /tmp/marzban.sh @ install
rm -f /tmp/marzban.sh

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
chmod 600 /opt/marzban/.env      # berisi password panel

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

# --- Xray core & konfigurasi ---
# CATATAN: versi asli mengambil xray core dari repo pribadi (binary tidak
# terverifikasi). Di sini dipakai release resmi XTLS. Lihat catatan di bawah.
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

# --- PATCH NGINX: lepaskan port 443, pindah ke loopback 8443 ----------------
# HAProxy yang akan memegang :443 dan meneruskan TLS mentah ke sini.
NGX=/opt/marzban/nginx.conf

# 1. Turunkan listener 443 publik menjadi 127.0.0.1:8443 (+ http2 untuk gRPC)
sed -i -E 's|^([[:space:]]*)listen[[:space:]]+\[::\]:443.*;|\1# (dilepas, HAProxy memegang :443)|' "$NGX"
sed -i -E 's|^([[:space:]]*)listen[[:space:]]+443.*;|\1listen 127.0.0.1:8443 ssl;\n\1http2 on;|' "$NGX"

# 2. server_name: pemisah harus spasi (bukan koma) dan wildcard yang benar
sed -i -E "s|^([[:space:]]*)server_name[[:space:]].*;|\1server_name ${DOMAIN} *.${DOMAIN};|" "$NGX"

# 3. Trust loopback supaya X-Forwarded-For dari Cloudflare tetap ter-resolve
grep -q 'set_real_ip_from 127.0.0.1;' "$NGX" || \
    sed -i -E 's|^([[:space:]]*)real_ip_header |\1set_real_ip_from 127.0.0.1;\n\1real_ip_header |' "$NGX"

# 4. Backend Marzban: 0.0.0.0 bukan alamat tujuan yang valid
sed -i 's|proxy_pass http://0.0.0.0:7879;|proxy_pass http://127.0.0.1:7879;|g' "$NGX"

# 5. location / jangan proxy ke sslh:700 (menyebabkan loop / dead-end 2080).
#    Sajikan halaman statis saja.
python3 - "$NGX" <<'PYEOF'
import re, sys
p = sys.argv[1]
s = open(p).read()
new = """        location / {
            root /var/www/html;
            index index.html;
        }
"""
s = re.sub(
    r'[ \t]*location / \{\n(?:[^{}]*\n)*?[ \t]*\}\n',
    new, s, count=1)
open(p, 'w').write(s)
PYEOF

info "nginx.conf dipatch: 443 -> 127.0.0.1:8443, http2 aktif."

wget -q -N -P /var/lib/marzban/templates/subscription/ \
    'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/marzban/index.html'

# =============================================================================
#  5. SERTIFIKAT SSL (Let's Encrypt via acme.sh)
# =============================================================================
info "Generating SSL Certificate (Let's Encrypt)..."
curl -s https://get.acme.sh | sh -s > /dev/null 2>&1
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt > /dev/null 2>&1
/root/.acme.sh/acme.sh --register-account -m "$EMAIL" > /dev/null 2>&1
# acme.sh --standalone butuh port 80 bebas. Matikan dulu apa pun yang memegangnya.
try systemctl stop nginx
[[ -f /opt/marzban/docker-compose.yml ]] && try docker compose -f /opt/marzban/docker-compose.yml down

# Sertifikat harus mencakup domain utama DAN subdomain SSH, kalau tidak
# client SSH+SSL akan kena error "certificate name mismatch".
/root/.acme.sh/acme.sh --issue -d "$DOMAIN" -d "$SSH_DOMAIN" --standalone --force > /dev/null 2>&1 \
    || die "Gagal menerbitkan sertifikat untuk $DOMAIN + $SSH_DOMAIN. Cek pointing DNS & port 80."

# --reloadcmd dipanggil otomatis tiap 60 hari saat acme.sh memperbarui cert.
/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" \
    --fullchain-file /var/lib/marzban/xray.crt \
    --key-file      /var/lib/marzban/xray.key \
    --reloadcmd     "systemctl restart stunnel4; docker compose -f /opt/marzban/docker-compose.yml restart nginx" \
    > /dev/null 2>&1
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

# --- PATCH SSLH: target --tls/--http lama menunjuk ke 127.0.0.1:2080 yang
#     tidak ditempati siapa pun. Arahkan ke listener Nginx yang sebenarnya.
sed -i 's|--tls 127.0.0.1:2080|--tls 127.0.0.1:8443|'  /etc/default/sslh
sed -i 's|--http 127.0.0.1:2080|--http 127.0.0.1:80|'  /etc/default/sslh

try systemctl enable  sslh
try systemctl restart sslh

# =============================================================================
#  6b. SSH-over-TLS di PORT 443  (HAProxy SNI router + stunnel)
# =============================================================================
#  Alur:
#     :443 HAProxy (mode tcp, TLS passthrough - tidak menerminasi apa pun)
#           |- SNI = $SSH_DOMAIN -> 127.0.0.1:4443 stunnel -> dropbear :109
#           `- SNI lain / kosong -> 127.0.0.1:8443 nginx (ssl)
#
#  HAProxy hanya mengintip ClientHello, jadi gRPC/h2/WS di Nginx tetap utuh.
# =============================================================================
info "Setup stunnel (TLS wrapper untuk Dropbear)..."
apt-get install -y stunnel4

cat > /etc/stunnel/stunnel.conf <<EOF
cert = /var/lib/marzban/xray.crt
key  = /var/lib/marzban/xray.key
pid  = /var/run/stunnel.pid

client = no
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept  = 127.0.0.1:4443
connect = 127.0.0.1:109

[openvpn]
accept  = 127.0.0.1:4444
connect = 127.0.0.1:1194
EOF
chmod 600 /etc/stunnel/stunnel.conf
sed -i 's/^ENABLED=0/ENABLED=1/' /etc/default/stunnel4 2>/dev/null
try systemctl enable  stunnel4
try systemctl restart stunnel4

info "Setup HAProxy (SNI router di port 443)..."
apt-get install -y haproxy

# Catatan: sysctl di skrip ini menonaktifkan IPv6, jadi bind IPv4 saja.
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log /dev/log local0
    maxconn 20000
    user  haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5s
    timeout client  1h
    timeout server  1h

frontend ft_tls_443
    bind 0.0.0.0:443

    # Tunggu ClientHello sebelum memutuskan backend
    tcp-request inspect-delay 5s
    tcp-request content accept if { req_ssl_hello_type 1 }

    acl is_ssh req.ssl_sni -i ${SSH_DOMAIN}
    acl no_sni !{ req.ssl_sni -m found }

    use_backend bk_ssh if is_ssh
    use_backend bk_ssh if no_sni
    default_backend bk_web

backend bk_ssh
    server stunnel 127.0.0.1:4443 check

backend bk_web
    server nginx 127.0.0.1:8443 check
EOF

haproxy -c -f /etc/haproxy/haproxy.cfg >/dev/null 2>&1 \
    || die "Konfigurasi HAProxy tidak valid. Jalankan: haproxy -c -f /etc/haproxy/haproxy.cfg"

try systemctl enable  haproxy
try systemctl restart haproxy

# =============================================================================
#  7. SQUID PROXY  +  OHP
# =============================================================================
# PERINGATAN: versi asli mengubah squid menjadi OPEN PROXY (allow all).
# Di sini dibiarkan default (butuh autentikasi). Baca catatan di bawah.
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
    # Versi asli: sed -i 's|http_access allow password|http_access allow all|g'
    #             ^^^ DIHAPUS - itu membuka proxy untuk siapa saja
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

# Port yang dipakai layanan-layanan di atas.
# (Daftar persis milik versi asli tidak dapat dipulihkan dari binary,
#  jadi ini diturunkan dari service yang benar-benar dipasang.)
# 700 = sslh (multiplexer SSH/TLS/OpenVPN langsung, tanpa lewat HAProxy).
# Sebelumnya sslh listen di 700 tapi portnya tidak pernah dibuka -> tidak
# pernah bisa dipakai dari luar.
#
# TIDAK dibuka (sengaja, hanya loopback):
#   4443 stunnel-dropbear   4444 stunnel-openvpn   8443 nginx-ssl
TCP_PORTS=(22 80 443 700 109 1194 3128 7879 8080 8181 8282 8383 51443)
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
# Versi asli mengunduh rclone.conf milik orang lain (backup bisa mengalir ke
# cloud mereka). DIHAPUS - konfigurasikan sendiri dengan: rclone config
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
-----------------------------------------------
 SSH + SSL/TLS
   Host / SNI    : ${SSH_DOMAIN}
   Port          : 443
   (Cloudflare untuk ${SSH_DOMAIN} HARUS grey cloud / DNS-only)

 SSH langsung    : ${DOMAIN}:22 / :109 (dropbear)
 SSLH multiplex  : ${DOMAIN}:700  (SSH / TLS / OpenVPN)
 OpenVPN + TLS   : lewat stunnel 127.0.0.1:4444 (belum diekspos)
-----------------------------------------------
 Cek cepat:
   openssl s_client -connect ${DOMAIN}:443 -servername ${SSH_DOMAIN} -quiet
   -> harus muncul banner SSH-2.0-dropbear
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
