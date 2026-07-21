#!/bin/bash
clear
echo -e "\e[96m======================================\e[0m"
echo -e "         \e[93mSTATUS LAYANAN VPS\e[0m           "
echo -e "\e[96m======================================\e[0m"

# Fungsi cek layanan sistem (systemctl)
check_status() {
    local service=$1
    local name=$2
    if systemctl is-active --quiet "$service"; then
        printf "%-20s : \e[92m[ ON ]\e[0m\n" "$name"
    else
        printf "%-20s : \e[91m[ OFF ]\e[0m\n" "$name"
    fi
}

# Fungsi cek layanan docker
check_docker() {
    local container=$1
    local name=$2
    if docker ps -q -f name="$container" | grep -q .; then
        printf "%-20s : \e[92m[ ON ]\e[0m\n" "$name"
    else
        printf "%-20s : \e[91m[ OFF ]\e[0m\n" "$name"
    fi
}

check_status "ssh" "OpenSSH"
check_status "dropbear" "Dropbear"
check_status "ssh-ws" "SSH WebSocket"
check_status "udp-custom" "UDP Custom"
check_status "cron" "Cronjob"
check_status "vnstat" "Vnstat"

check_docker "marzban-marzban-1" "Marzban Core"
check_docker "marzban-nginx-1" "Marzban Nginx"

echo -e "\e[96m======================================\e[0m"
echo ""
