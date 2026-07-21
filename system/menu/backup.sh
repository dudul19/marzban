#!/bin/bash

clear

# Variabel Waktu
tanggal=$(date +"%m-%d-%Y")
tanggal2=$(date +"%m%d%Y")
waktu=$(date +"%T" | tr -d ':')
backup_dir="/root/backup"
zip_file="/root/Backup-${tanggal2}.zip"

# File Konfigurasi Telegram
config_file="/root/.telegram_config.conf"

# Periksa apakah konfigurasi bot sudah ada
if [[ -f "$config_file" ]]; then
    source "$config_file"
else
    echo "Bot token dan user ID belum diset. Silakan masukkan informasi berikut."
    
    read -rp "Masukkan Telegram Bot Token: " botToken
    read -rp "Masukkan Telegram User ID: " chatId

    # Simpan ke file konfigurasi
    cat <<EOF > "$config_file"
botToken=$botToken
chatId=$chatId
EOF

    echo "Konfigurasi berhasil disimpan. Jalankan ulang skrip untuk memulai backup."
    exit 0
fi

# Autentikasi dan Informasi Server
nama=$(cat /root/nama 2>/dev/null || echo "Unknown")
domain=$(cat /etc/data/domain 2>/dev/null || echo "Unknown")
ipsaya=$(curl -s http://checkip.amazonaws.com)
asn_info=$(timeout 5 curl -s "http://ip-api.com/json/$ipsaya" | jq -r '.isp // "Unknown ISP"')

# Fungsi Warna Output
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

echo -e "$(green "Memulai Backup")"
sleep 1

# Buat Direktori Backup
rm -rf "$backup_dir"
mkdir -p "$backup_dir"

# Salin File yang Akan Dibackup
cp -r /etc/data "$backup_dir/data" 2>/dev/null
cp -r /opt/marzban "$backup_dir/" 2>/dev/null
cp /etc/passwd "$backup_dir/" 2>/dev/null
cp /etc/group "$backup_dir/" 2>/dev/null
cp /etc/shadow "$backup_dir/" 2>/dev/null
cp /etc/gshadow "$backup_dir/" 2>/dev/null
cp -r /etc/xray "$backup_dir/xray"  2>/dev/null
cp /var/lib/marzban/{xray_config.json,db.sqlite3} "$backup_dir/" 2>/dev/null
cp -r /var/www/html/ "$backup_dir/" 2>/dev/null
cp /root/{.telegram_config.conf,file_id.txt} "$backup_dir/" 2>/dev/null

# Buat File ZIP dengan Password
zip -rP "Rerechan02" "$zip_file" "backup"

if [[ ! -f "$zip_file" ]]; then
    echo -e "$(red "Gagal membuat file ZIP.")"
    exit 1
fi

# Upload Backup ke Google Drive menggunakan rclone
rclone copy "$zip_file" dr:backup/

# Dapatkan URL file di Google Drive
url=$(rclone link dr:backup/Backup-${tanggal2}.zip)

if [[ -z "$url" ]]; then
    echo -e "$(red "Gagal mendapatkan link backup.")"
    exit 1
fi

# Ambil ID Backup dari Google Drive (ID file)
backup_id=$(echo "$url" | grep -o 'id=[^&]*' | cut -d'=' -f2)
link="https://drive.google.com/u/4/uc?id=${backup_id}&export=download"

# Kirim File ke Telegram dengan ID Backup dari Google Drive
message="✅ *Backup Berhasil!*

🆔 *ID Backup:* \`$backup_id\`

🖥 *Informasi Server:*
┣ **Domain:** $domain
┣ **ISP:** $asn_info
┣ **IP VPS:** \`$ipsaya\`
┣ **Waktu Backup:** $tanggal pukul $waktu
┗━━━━━━━━━━━━━━━━━

📥 *Unduh Backup:*  
\`$link\`

🔹 File backup telah tersimpan di Google Drive.
🔹 Simpan ID backup ini untuk referensi pemulihan di masa mendatang."

response=$(curl -s -F chat_id="$chatId" -F document=@"$zip_file" -F caption="$message" -F parse_mode="Markdown" "https://api.telegram.org/bot$botToken/sendDocument")

# Periksa apakah pengiriman berhasil
if echo "$response" | jq -e '.ok' > /dev/null; then
    file_id=$(echo "$response" | jq -r '.result.document.file_id')
    echo "### Backup ${tanggal}" >> "/root/file_id.txt"
    echo "Backup ID: $backup_id" >> "/root/file_id.txt"
    echo "File ID: $file_id" >> "/root/file_id.txt"
    echo "Backup berhasil pada $tanggal pukul $waktu." >> "/root/log-backup.txt"
else
    echo -e "$(red "Gagal mengirim backup ke Telegram.")"
    exit 1
fi

# Hapus File Sementara
rm -rf "$backup_dir"
rm -f "$zip_file"

echo -e "$(green "Backup dan pengiriman selesai.")"