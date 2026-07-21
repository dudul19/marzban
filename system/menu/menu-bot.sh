#!/bin/bash

# Warna teks
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

ENV_PATH="/opt/marzban/.env"

# Fungsi untuk mengecek status bot
check_status() {
    if grep -qE "^\s*#\s*TELEGRAM_API_TOKEN" "$ENV_PATH" || ! grep -qE "^\s*TELEGRAM_API_TOKEN=" "$ENV_PATH"; then
        echo "OFF"
    else
        echo "ON"
    fi
}

# Fungsi untuk setup bot
setup_bot() {
    if [ "$(check_status)" == "OFF" ]; then
        echo -n "Masukkan API Token Bot Telegram: "
        read -r api_token
        echo -n "Masukkan Telegram Admin ID: "
        read -r admin_id

        # Pastikan input tidak kosong
        if [[ -z "$api_token" || -z "$admin_id" ]]; then
            echo -e "${RED}Error: API Token dan Admin ID tidak boleh kosong.${NC}"
            return
        fi

        # Hapus komentar jika ada atau tambahkan jika tidak ada
        sed -i 's/^\s*#\s*TELEGRAM_API_TOKEN/TELEGRAM_API_TOKEN/' "$ENV_PATH"
        sed -i 's/^\s*#\s*TELEGRAM_ADMIN_ID/TELEGRAM_ADMIN_ID/' "$ENV_PATH"

        # Tambahkan atau perbarui nilai di file .env
        sed -i "/^\s*TELEGRAM_API_TOKEN=/d" "$ENV_PATH"
        sed -i "/^\s*TELEGRAM_ADMIN_ID=/d" "$ENV_PATH"
        echo "TELEGRAM_API_TOKEN=$api_token" >> "$ENV_PATH"
        echo "TELEGRAM_ADMIN_ID=$admin_id" >> "$ENV_PATH"

        echo -e "${GREEN}Bot telah diaktifkan.${NC}"
    else
        echo -e "${GREEN}Bot sudah aktif.${NC}"
    fi
}

# Fungsi untuk menghapus bot
delete_bot() {
    sed -i 's/^\s*TELEGRAM_API_TOKEN/# TELEGRAM_API_TOKEN/' "$ENV_PATH"
    sed -i 's/^\s*TELEGRAM_ADMIN_ID/# TELEGRAM_ADMIN_ID/' "$ENV_PATH"
    echo -e "${RED}Bot telah dinonaktifkan.${NC}"
}

# Fungsi untuk setup bot WhatsApp
setup_bot_wa() {
    clear
    echo -e "Coming Soon"
}

# Menu utama
while true; do
    STATUS=$(check_status)

    # Tentukan warna berdasarkan status
    if [ "$STATUS" == "ON" ]; then
        STATUS_COLOR="${GREEN}$STATUS${NC}"
    else
        STATUS_COLOR="${RED}$STATUS${NC}"
    fi

    clear
    echo -e "Status Bot: $STATUS_COLOR"
    echo -e "===================="
    echo -e "1. Setup Bot Panel Marzban"
    echo -e "2. Delete Bot Panel Marzban"
    echo -e "3. Setup Bot WhatsApp"
    echo -e "4. Back To Menu Default"
    echo -e "0. Exit"
    echo -n "Pilih opsi: "
    read -r choice

    case $choice in
        1) setup_bot ;;
        2) delete_bot ;;
        3) setup_bot_wa ;;
        4) menu ;;  # Pastikan fungsi menu sudah didefinisikan di tempat lain
        0) echo -e "${GREEN}Keluar...${NC}"; exit 0 ;;
        *) echo -e "${RED}Pilihan tidak valid!${NC}" ;;
    esac

    sleep 2
done