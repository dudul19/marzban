#!/bin/bash

BLUE='\033[0;34m'
CYAN='\033[0;36m'
GREEN='\033[1;32m'
RED='\033[0;31m'
WHITE='\033[1;37m'
NC='\033[0m'
BG_BLUE='\e[44m'

clear
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BG_BLUE}${WHITE}          CEK USER LOGIN / ONLINE         ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
printf "${CYAN}%-18s %-16s${NC}\n" "USERNAME" "TOTAL LOGIN"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

TOTAL_ONLINE=0

declare -A ssh_logins
declare -A active_pids

LOG_FILES=()
[[ -f "/var/log/auth.log" ]] && LOG_FILES+=("/var/log/auth.log")
[[ -f "/var/log/secure" ]] && LOG_FILES+=("/var/log/secure")
[[ -f "/var/log/syslog" ]] && LOG_FILES+=("/var/log/syslog")

if [[ ${#LOG_FILES[@]} -gt 0 ]]; then
    for log in "${LOG_FILES[@]}"; do
        # Mapping koneksi aktif Dropbear
        while read -r pid user; do
            if [[ -n "$pid" && -n "$user" ]]; then
                if [[ -z "${active_pids[$pid]}" ]]; then
                    if ps -p "$pid" -o comm= 2>/dev/null | grep -qE "dropbear|sshd"; then
                        active_pids[$pid]=$user
                        ssh_logins["$user"]=$((ssh_logins["$user"] + 1))
                    fi
                fi
            fi
        done < <(grep -E "dropbear\[[0-9]+\]: Password auth succeeded" "$log" 2>/dev/null | awk -F'dropbear\\[|\\]: Password auth succeeded for ' '{print $2, $3}' | awk -F"'" '{print $1, $2}' | awk '{print $1, $2}')

        # Mapping koneksi aktif OpenSSH
        while read -r pid user; do
            if [[ -n "$pid" && -n "$user" ]]; then
                if [[ -z "${active_pids[$pid]}" ]]; then
                    if ps -p "$pid" -o comm= 2>/dev/null | grep -qE "dropbear|sshd"; then
                        active_pids[$pid]=$user
                        ssh_logins["$user"]=$((ssh_logins["$user"] + 1))
                    fi
                fi
            fi
        done < <(grep -E "sshd\[[0-9]+\]: Accepted (password|publickey) for" "$log" 2>/dev/null | awk -F'sshd\\[|\\]: Accepted password for |\\]: Accepted publickey for ' '{print $2, $3}' | awk '{print $1, $2}')
    done
fi

OVPN_STATUS_FILES=()

# Mencari perintah 'status' di dalam seluruh konfigurasi OpenVPN
while read -r config_line; do
    status_file=$(echo "$config_line" | awk -F'status ' '{print $2}' | awk '{print $1}')
    if [[ -n "$status_file" && -f "$status_file" ]]; then
        OVPN_STATUS_FILES+=("$status_file")
    fi
done < <(grep -rws "^status" /etc/openvpn/ 2>/dev/null)

# Fallback ke path Log Openvpn
default_ovpn_paths=(
    "/etc/openvpn/server/openvpn-tcp.log"
    "/etc/openvpn/server/openvpn-udp.log"
    "/var/log/openvpn/openvpn-status.log"
    "/var/log/openvpn/status.log"
    "/var/log/openvpn-status.log"
    "/etc/openvpn/openvpn-status.log"
    "/run/openvpn/server.status"
    "/run/openvpn-server/status.log"
)
for dp in "${default_ovpn_paths[@]}"; do
    if [[ -f "$dp" ]]; then
        # Cegah duplikasi file
        if ! printf "%s\n" "${OVPN_STATUS_FILES[@]}" | grep -x -q "$dp"; then
            OVPN_STATUS_FILES+=("$dp")
        fi
    fi
done

while IFS=: read -r user pass uid gid info home shell; do
    if [[ "$uid" -ge 1000 ]] && [[ "$user" != "ubuntu" ]] && [[ "$user" != "nobody" ]]; then

        # Hitung OpenSSH & Dropbear
        count_ssh=${ssh_logins["$user"]}
        [[ -z "$count_ssh" ]] && count_ssh=0
        if [[ "$count_ssh" -eq 0 ]]; then
            count_ssh=$(ps -u "$uid" 2>/dev/null | grep -E "sshd|dropbear" | wc -l)
        fi

        # Hitung OpenVPN dari file status yang terdeteksi
        count_ovpn=0
        if [[ ${#OVPN_STATUS_FILES[@]} -gt 0 ]]; then
            # Regex ketat untuk menghindari double-count pada tabel ROUTING
            count_ovpn=$(cat "${OVPN_STATUS_FILES[@]}" 2>/dev/null | grep -c -E "^$user,|^CLIENT_LIST,$user,")
        fi

        # Total Koneksi (Dropbear + SSH + OpenVPN)
        total_login=$((count_ssh + count_ovpn))

        # Tampilkan jika Online
        if [[ "$total_login" -gt 0 ]]; then
            printf "%-18s ${GREEN}%-16s${NC}\n" "$user" "${total_login} IP/Device"
            ((TOTAL_ONLINE++))
        fi
    fi
done < /etc/passwd

if [[ "$TOTAL_ONLINE" -eq 0 ]]; then
    echo -e "               ${RED}No User Online${NC}               "
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Total Account Online : ${GREEN}$TOTAL_ONLINE User${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
