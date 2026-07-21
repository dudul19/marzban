#!/bin/bash
clear
domain=$(cat /etc/data/domain)

echo -e "\e[94m[INFO]\e[0m Mematikan layanan Marzban sementara..."
cd /opt/marzban && docker compose down

echo -e "\e[94m[INFO]\e[0m Memulai proses generate sertifikat (Let's Encrypt) untuk $domain..."
/root/.acme.sh/acme.sh --issue -d $domain --standalone --server letsencrypt --force

echo -e "\e[94m[INFO]\e[0m Menginstal sertifikat ke direktori Marzban..."
# Menggunakan fullchain agar tidak ada issue "missing intermediate cert"
/root/.acme.sh/acme.sh --install-cert -d $domain \
    --fullchain-file /var/lib/marzban/xray.crt \
    --key-file /var/lib/marzban/xray.key

chmod 755 /var/lib/marzban/xray.crt
chmod 755 /var/lib/marzban/xray.key

echo -e "\e[94m[INFO]\e[0m Menyalakan kembali layanan Marzban..."
cd /opt/marzban && docker compose up -d

echo -e "\e[92m[SUCCESS]\e[0m Sertifikat berhasil diperbarui!"
