#!/bin/bash

# ==========================================
# Variabel Warna Konsisten & Elegan
# ==========================================
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BG_BLUE='\e[44m' # Background Biru untuk Header

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BG_BLUE}${WHITE}                MEMBER SSH                ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${CYAN}%-18s %-16s %-10s${NC}\n" "USERNAME" "EXPIRED" "STATUS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

JUMLAH=0

# Membaca file passwd dengan logika yang sama persis seperti script delete
while IFS=: read -r user pass uid gid info home shell; do
    # Filter: UID >= 1000 dan abaikan user default sistem
    if [[ "$uid" -ge 1000 ]] && [[ "$user" != "ubuntu" ]] && [[ "$user" != "nobody" ]]; then

        exp=$(chage -l "$user" | grep -i "Account expires" | awk -F": " '{print $2}')
        [[ -z "$exp" || "$exp" == "never" ]] && exp="Never"

        status=$(passwd -S "$user" | awk '{print $2}')
        if [[ "$status" == "L" || "$status" == "LK" ]]; then
            status_label="LOCKED"
        else
            status_label="UNLOCKED"
        fi

        # Print rapih tanpa perlu spasi manual ("$exp    ")
        printf "%-18s %-16s %-10s\n" "$user" "$exp" "$status_label"

        # Hitung jumlah user
        ((JUMLAH++))
    fi
done < /etc/passwd

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Account number: ${CYAN}$JUMLAH user${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
