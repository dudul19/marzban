#!/bin/bash

clear

# Direktori kerja
backup_dir="/root"
backup_file=$(ls $backup_dir/*.zip 2>/dev/null | head -n 1)

# Fungsi warna output
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

echo -e "$(green "Memulai proses restore...")"

# Pastikan paket yang dibutuhkan terinstal
if ! command -v python3 &>/dev/null || ! command -v pip3 &>/dev/null; then
    echo -e "$(green "Menginstal Python3 dan pip3...")"
    apt update && apt install -y python3 python3-pip || { echo -e "$(red "Gagal menginstal Python3 dan pip3!")"; exit 1; }
fi

# Pastikan gdown terinstal
if ! command -v gdown &>/dev/null; then
    echo -e "$(green "Menginstal gdown...")"
    pip3 install --no-cache-dir gdown --break-system-packages || { echo -e "$(red "Gagal menginstal gdown!")"; exit 1; }
fi

# Cek apakah ada file backup di /root
if [[ -f "$backup_file" ]]; then
    echo -e "$(green "File backup ditemukan: $backup_file")"
else
    # Meminta pengguna memasukkan ID Backup atau URL
    while [[ -z "$backup_url" ]]; do
        read -rp "Tidak ditemukan file backup! Masukkan ID Backup atau URL: " input

        if [[ -z "$input" ]]; then
            echo -e "$(red "Tidak ada input ID Backup atau URL! Proses restore dibatalkan.")"
            exit 1
        fi

        if [[ "$input" == https* ]]; then
            backup_url="$input"
        else
            backup_url="https://drive.google.com/uc?id=${input}&export=download"
        fi
    done

    # Unduh file backup menggunakan gdown
    gdown --fuzzy -O "$backup_dir/rebackup.zip" "$backup_url"

    if [[ $? -ne 0 ]]; then
        echo -e "$(red "Gagal mengunduh file backup!")"
        exit 1
    fi

    backup_file="$backup_dir/rebackup.zip"
    echo -e "$(green "File backup berhasil diunduh: $backup_file")"
fi

# Ekstrak file backup
unzip -P "Rerechan02" -o "$backup_file" -d "$backup_dir"

if [[ $? -ne 0 ]]; then
    echo -e "$(red "Gagal mengekstrak file backup!")"
    exit 1
fi

# Restore file sesuai dengan struktur awal
echo -e "$(green "Memulai proses pemulihan data...")"
cp "$backup_dir/backup/passwd" /etc/
cp "$backup_dir/backup/group" /etc/
cp "$backup_dir/backup/shadow" /etc/
cp "$backup_dir/backup/gshadow" /etc/
cp -r "$backup_dir/backup/marzban" /opt/
cp "$backup_dir/backup/xray_config.json" /var/lib/marzban/
cp "$backup_dir/backup/db.sqlite3" /var/lib/marzban/
cp -r "$backup_dir/backup/html" /var/www/
cp -r "$backup_dir/data" /etc/data/
cp "$backup_dir/backup/.telegram_config.conf" /root/
cp "$backup_dir/backup/file_id.txt" /root/
cp -r "$backup_dir/xray" /etc/

echo -e "$(green "Restore selesai. Membersihkan file sementara...")"

# Hapus semua file di /root kecuali skrip restore
find "$backup_dir" -type f ! -name "$(basename "$0")" -delete
find "$backup_dir" -type d -empty -delete

clear

echo -e "$(green "Proses restore selesai dan semua file sementara telah dihapus.")"
