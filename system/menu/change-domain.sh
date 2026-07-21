#!/bin/bash

clear

# Membaca domain lama
if [ ! -f "/etc/data/domain" ]; then
  echo "File /etc/data/domain tidak ditemukan!"
  exit 1
fi
domain2=$(cat /etc/data/domain)

echo -e "\nYour Current Domain: $domain2"

# Meminta input domain baru
read -rp "Enter New Domain: " domain
# Meminta input email
read -rp "Enter your email: " email

# Pastikan domain dan email tidak kosong
if [[ -z "$domain" || -z "$email" ]]; then
  echo "Domain atau email tidak boleh kosong!"
  exit 1
fi

# Menurunkan Marzban sebelum pembaruan
echo "Stopping Marzban..."
marzban down > /dev/null 2>&1

# Mengeluarkan sertifikat SSL baru
echo "Requesting SSL certificate..."
/root/.acme.sh/acme.sh --server letsencrypt --register-account -m "$email" --issue -d "$domain" --standalone -k ec-256 --force --debug

# Menginstal sertifikat SSL
echo "Installing SSL certificate..."
~/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /var/lib/marzban/xray.crt --keypath /var/lib/marzban/xray.key --ecc

# Menampilkan sertifikat yang baru diinstal
cat /var/lib/marzban/xray.crt
cat /var/lib/marzban/xray.key

# Backup domain lama dan mengganti dengan yang baru
echo "Updating domain configuration..."
mv /etc/data/domain /etc/data/domain.old
sudo rm -f /etc/data/domain
echo "$domain" | sudo tee /etc/data/domain
sudo rm -f /etc/xray/domain
echo "$domain" | sudo tee /etc/xray/domain

# Membaca domain lama dari backup
old=$(cat /etc/data/domain.old)

# Memastikan domain lama tidak kosong sebelum mengganti
if [[ -z "$old" ]]; then
  echo "Domain lama tidak ditemukan di /etc/data/domain.old!"
  exit 1
fi

# Mengganti domain lama dengan domain baru di nginx.conf
echo "Updating Nginx configuration..."
sed -i "s|$old|$domain|g" "/opt/marzban/nginx.conf"
sed -i "s|$old|$domain|g" "/etc/data/setup.log"

# Memperbarui domain dalam database SQLite
DB_PATH="/var/lib/marzban/db.sqlite3"

if [ ! -f "$DB_PATH" ]; then
  echo "Database $DB_PATH tidak ditemukan!"
  exit 1
fi

SQL_QUERY="UPDATE hosts SET address = '$domain' WHERE address = '$old'; \
UPDATE hosts SET host = '$domain' WHERE host = '$old'; \
UPDATE hosts SET sni = '$domain' WHERE sni = '$old';"

echo "Updating database..."
sqlite3 "$DB_PATH" "$SQL_QUERY"

if [ $? -eq 0 ]; then
  echo "Database update successful."
else
  echo "Database update failed!"
  exit 1
fi

# Menghapus file domain lama yang sudah tidak digunakan
rm -f /etc/data/domain.old

# Menjalankan ulang Marzban
echo "Restarting Marzban..."
marzban restart > /dev/null 2>&1

echo "Domain successfully updated to $domain!"