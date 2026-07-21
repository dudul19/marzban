#!/bin/bash

# File konfigurasi bot
config_file="/root/.telegram_config.conf"
cron_job="0 0,1,3,5,6,12,13,15,17,18 * * * root backup"

# Fungsi warna output
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
export NC='\033[0m';

# Fungsi Setup Auto Backup
auto-backup() {
    clear
    echo -e "    Setup Auto Backup"
    echo -e "========================="
    
    # Periksa apakah file konfigurasi ada
    if [[ ! -f "$config_file" ]]; then
        echo -e "$(red "Bot token dan user ID belum diset. Silakan masukkan informasi berikut.${NC}")"
        read -rp "Masukkan Telegram Bot Token: " botToken
        read -rp "Masukkan Telegram User ID: " chatId

        # Simpan ke file konfigurasi
        cat <<EOF > "$config_file"
botToken=$botToken
chatId=$chatId
EOF
        echo -e "$(green "Konfigurasi berhasil disimpan.${NC}")"
    else
        echo -e "$(green "Konfigurasi sudah tersedia.${NC}")"
    fi

    # Cek apakah crontab sudah mengandung job auto backup
    if grep -qF "$cron_job" /etc/crontab; then
        echo -e "Auto Backup: $(green "[ ON ]${NC}")"
    else
        echo -e "Auto Backup: $(red "[ OFF ]${NC}")"
        read -rp "Apakah ingin mengaktifkan auto backup? (y/n): " enable_auto_backup
        if [[ "$enable_auto_backup" == "y" ]]; then
            echo "$cron_job" | tee -a /etc/crontab
            systemctl restart cron
            echo -e "$(green "Auto backup telah diaktifkan.")"
        fi
    fi
    read -p "Tekan enter untuk kembali ke menu..."
    menu2
}

# Fungsi Menu
menu2() {
    clear
    echo -e "    Menu Backup"
    echo -e "====================="
    echo -e ""
    echo -e "1. Backup Database"
    echo -e "2. Restore Database"
    echo -e "3. Setup Auto Backup"
    echo -e "0. Back To Menu"
    echo -e "x. Exit"
    echo -e "====================="
    echo -e " CTRL + C To Exit "
    echo -e "====================="
    read -p "Input Options: " saq
    case $saq in
    1) backup ;;
    2) restore ;;
    3) auto-backup ;;
    0) menu ;;
    x) exit ;;
    *) menu2 ;;
    esac
}

# Panggil menu utama
menu2