#!/bin/bash

# ==========================================
# Variabel Warna Konsisten & Elegan
# ==========================================
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[1;32m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BG_BLUE='\e[44m' # Background Biru untuk Header

clear
# ==========================================
# 1. Menampilkan Daftar User Terlebih Dahulu
# ==========================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BG_BLUE}${WHITE}              LIST MEMBER SSH             ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${CYAN}%-18s %-16s %-10s${NC}\n" "USERNAME" "EXPIRED" "STATUS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Membaca file passwd untuk list user
while IFS=: read -r user pass uid gid info home shell; do
    if [[ "$uid" -ge 1000 ]] && [[ "$user" != "ubuntu" ]] && [[ "$user" != "nobody" ]]; then
        exp=$(chage -l "$user" | grep -i "Account expires" | awk -F": " '{print $2}')
        [[ -z "$exp" || "$exp" == "never" ]] && exp="Never"

        status=$(passwd -S "$user" | awk '{print $2}')
        if [[ "$status" == "L" || "$status" == "LK" ]]; then
            status_label="LOCKED"
        else
            status_label="UNLOCKED"
        fi

        printf "%-18s %-16s %-10s\n" "$user" "$exp" "$status_label"
    fi
done < /etc/passwd

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BG_BLUE}${WHITE}                 RENEW USER               ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ==========================================
# 2. Proses Input dan Renew
# ==========================================
read -p "Username : " USER

# Cek input kosong
if [ -z "$USER" ]; then
    echo -e "${RED}Error: Username tidak boleh kosong!${NC}"
    exit 1
fi

# Cek apakah user ada (validasi menggunakan command 'id')
if id "$USER" &>/dev/null && [[ "$USER" != "ubuntu" && "$USER" != "nobody" ]]; then
    read -p "Day Extend : " DAYS

    # Validasi input DAYS harus berupa angka
    if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Day Extend harus berupa angka bulat!${NC}"
        exit 1
    fi

    # Ambil tanggal kedaluwarsa user saat ini
    CURRENT_EXPIRATION=$(chage -l "$USER" | grep -i "Account expires" | awk -F": " '{print $2}')

    # Jika akun tidak memiliki tanggal kedaluwarsa, gunakan hari ini sebagai dasar
    if [[ "$CURRENT_EXPIRATION" == "never" || -z "$CURRENT_EXPIRATION" ]]; then
        CURRENT_EXPIRATION=$(date +"%Y-%m-%d")
    fi

    # Hitung tanggal kedaluwarsa baru secara instan
    NEW_EXPIRATION_DATE=$(date -d "$CURRENT_EXPIRATION + $DAYS days" +"%Y-%m-%d")
    NEW_EXPIRATION_DISPLAY=$(date -d "$CURRENT_EXPIRATION + $DAYS days" +"%d %b %Y")

    # Perpanjang masa aktif user dan buka kunci (unlock) jika sebelumnya terkunci
    passwd -u "$USER" &>/dev/null
    usermod -e "$NEW_EXPIRATION_DATE" "$USER" &>/dev/null

    # Tampilkan output hasil berhasil renew
    clear
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BG_BLUE}${WHITE}               RENEW SUCCESS              ${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e ""
    echo -e " Username   : ${CYAN}$USER${NC}"
    echo -e " Days Added : ${GREEN}$DAYS Days${NC}"
    echo -e " Expires on : ${GREEN}$NEW_EXPIRATION_DISPLAY${NC}"
    echo -e ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

else
    echo -e "${RED}Failure: User '$USER' not found!${NC}"
fi
