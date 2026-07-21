#!/bin/bash
clear

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || {
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}

#color
red='\e[1;31m'
green='\e[0;32m'
blue='\e[0;34m'
cyan='\e[0;36m'
cyanb='\e[46m'
white='\e[037;1m'
grey='\e[1;36m'
NC='\e[0m'

# var installation
export DEBIAN_FRONTEND=noninteractive
OS=`uname -m`;
MYIP=$(wget -qO- icanhazip.com);
MYIP2="s/xxxxxxxxx/$MYIP/g";
ANU=$(ip -o -4 route show to default | awk '{print $5}');

# =========================
# TAMBAHAN: Install iptables
# =========================
apt update -y
apt install iptables iptables-persistent -y

# Install OpenVPN dan Easy-RSA
apt install openvpn -y
apt install openvpn easy-rsa -y
apt install unzip -y
apt install openssl -y

mkdir -p /etc/openvpn/server/easy-rsa/
cd /etc/openvpn/
wget -q https://github.com/risqinf/marzban/raw/refs/heads/main/ssh/openvpn/vpn.zip
unzip vpn.zip
rm -f vpn.zip
chown -R root:root /etc/openvpn/server/easy-rsa/

cd
mkdir -p /usr/lib/openvpn/
cp /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so /usr/lib/openvpn/openvpn-plugin-auth-pam.so

sed -i 's/#AUTOSTART="all"/AUTOSTART="all"/g' /etc/default/openvpn

systemctl enable --now openvpn-server@server-tcp-1194
systemctl enable --now openvpn-server@server-udp-2200
/etc/init.d/openvpn restart
/etc/init.d/openvpn status

# aktifkan ip4 forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf

# =========================
# TAMBAHAN: Allow OpenVPN ports & traffic
# =========================

# allow loopback & established
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# allow SSH (biar tidak ke-lock)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# allow OpenVPN TCP 1194
iptables -A INPUT -p tcp --dport 1194 -j ACCEPT

# allow OpenVPN UDP 2200
iptables -A INPUT -p udp --dport 2200 -j ACCEPT

# allow tun interface
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A FORWARD -o tun+ -j ACCEPT

# =========================

# Buat config client TCP 1194
cat > /etc/openvpn/client-tcp-1194.ovpn <<-END
client
dev tun
proto tcp
setenv FRIENDLY_NAME "Beginner TCP"
remote xxxxxxxxx 1194
resolv-retry infinite
route-method exe
auth-user-pass
auth-nocache
nobind
persist-key
persist-tun
comp-lzo
verb 3
END

# Buat config client UDP 2200
cat > /etc/openvpn/client-udp-2200.ovpn <<-END
client
dev tun
proto udp
setenv FRIENDLY_NAME "Beginner UDP"
remote xxxxxxxxx 2200
resolv-retry infinite
route-method exe
auth-user-pass
auth-nocache
nobind
persist-key
persist-tun
comp-lzo
verb 3
END

sed -i $MYIP2 /etc/openvpn/client-udp-2200.ovpn;
sed -i $MYIP2 /etc/openvpn/client-tcp-1194.ovpn;

echo '<ca>' >> /etc/openvpn/client-tcp-1194.ovpn
cat /etc/openvpn/server/ca.crt >> /etc/openvpn/client-tcp-1194.ovpn
echo '</ca>' >> /etc/openvpn/client-tcp-1194.ovpn

echo '<ca>' >> /etc/openvpn/client-udp-2200.ovpn
cat /etc/openvpn/server/ca.crt >> /etc/openvpn/client-udp-2200.ovpn
echo '</ca>' >> /etc/openvpn/client-udp-2200.ovpn

mkdir -p /var/www/html
cp /etc/openvpn/client-tcp-1194.ovpn /var/www/html/client-tcp-1194.ovpn
cp /etc/openvpn/client-udp-2200.ovpn /var/www/html/client-udp-2200.ovpn

cd /var/www/html/
zip openvpn.zip client-tcp-1194.ovpn client-udp-2200.ovpn > /dev/null 2>&1
rm -f *.ovpn
cd

iptables -t nat -I POSTROUTING -s 10.6.0.0/24 -o $ANU -j MASQUERADE
iptables -t nat -I POSTROUTING -s 10.7.0.0/24 -o $ANU -j MASQUERADE

iptables-save > /etc/iptables.up.rules
chmod +x /etc/iptables.up.rules

iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

systemctl daemon-reload
systemctl enable openvpn
systemctl start openvpn
/etc/init.d/openvpn restart

rm -f $0
