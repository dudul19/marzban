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
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BG_BLUE}${WHITE}            DELETE SSH ACCOUNT            ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${CYAN}%-18s %-16s %-10s${NC}\n" "USERNAME" "EXPIRED" "STATUS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Membaca file passwd dan melakukan filter
while IFS=: read -r user pass uid gid info home shell; do
    # Filter: UID >= 1000 dan abaikan user default sistem seperti ubuntu/nobody
    if [[ "$uid" -ge 1000 ]] && [[ "$user" != "ubuntu" ]] && [[ "$user" != "nobody" ]]; then

        # Ambil tanggal expired asli dari sistem (chage)
        exp=$(chage -l "$user" | grep -i "Account expires" | awk -F": " '{print $2}')
        [[ -z "$exp" || "$exp" == "never" ]] && exp="Never"

        # Ambil status lock akun
        status=$(passwd -S "$user" | awk '{print $2}')
        if [[ "$status" == "L" || "$status" == "LK" ]]; then
            status_label="LOCKED"
        else
            status_label="UNLOCKED"
        fi

        # Print dengan format rata kiri presisi
        printf "%-18s %-16s %-10s\n" "$user" "$exp" "$status_label"
    fi
done < /etc/passwd

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Proses Hapus User
read -p "Username SSH to Delete : " username

if [ -z "$username" ]; then
    echo -e "${RED}Error: Username tidak boleh kosong!${NC}"
    exit 1
fi

if ! id "$username" &>/dev/null; then
    echo -e "${RED}Failure: User '$username' not found.${NC}"
    exit 1
fi

# Eksekusi penghapusan
userdel -f "$username" &>/dev/null
pkill -u "$username" &>/dev/null
systemctl restart ssh sshd dropbear &>/dev/null

echo -e "${GREEN}Success: User '$username' successfully deleted.${NC}"
