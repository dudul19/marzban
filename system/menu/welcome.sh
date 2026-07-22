#!/bin/bash
clear
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
BG_RED='\e[41;97;1m' # Red background, bright white bold text
BG_GRE='\e[42;97;1m' # Green background, bright white bold text
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'

MYIP=$(curl -sS ipv4.icanhazip.com)
OS=$(lsb_release -d | cut -f2)
RAM=$(free -m | awk '/Mem:/ {print $2" MB"}')
UPTIME=$(uptime -p | sed 's/up //')
CPU=$(awk -F ': ' '/^model name/ {name=$2} END {print name}' /proc/cpuinfo | head -n 1)
domain=$(cat /etc/xray/domain 2>/dev/null || echo "undefined")
EXPIRE_INFO=""  
CITY=$(curl -s ipinfo.io/city)
ISP=$(curl -s ipinfo.io/org | cut -d " " -f 2-10)
TIMEZONE=$(date +'%Y-%m-%d %H:%M:%S %Z')

get_bw() {
    local date1="$1"
    local date2="$2"
    local flag="$3"
    local res=$(vnstat "$flag" 2>/dev/null | grep -w "$date1" | awk '{print $8" "$9}')
    [[ -z "$res" ]] && res=$(vnstat "$flag" 2>/dev/null | grep -w "$date2" | awk '{print $8" "$9}')
    
    if [[ -n "$res" ]]; then
        echo "$res" | sed 's/i//g'
    else
        echo "0 MB" 
    fi
}

bwhari=$(get_bw "$(date +'%m-%d')" "$(date +'%m/%d')" "-d")
bwkmrn=$(get_bw "$(date -d 'yesterday' +'%m-%d')" "$(date -d 'yesterday' +'%m/%d')" "-d")
bwbln=$(get_bw "$(date +'%b '"'"'%y')" "$(date +'%Y-%m')" "-m")

ping=$(ping -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F/ '/^rtt/ {printf "%.0f", $5}')
[[ -z "$ping" ]] && ping="0"

cpu_usage=$(ps -eo pcpu | awk 'BEGIN {sum=0.0} {sum+=$1} END {printf "%.1f", sum}')
cpu_usage+=" %"

ram_total=$(free -m | awk '/Mem:/ {print $2}')
ram_used=$(free -m | awk '/Mem:/ {print $3}')
ram_percent=$(( (ram_used * 100) / ram_total ))
ram_usage="${ram_used} MB / ${ram_total} MB (${ram_percent}%)"

check_status() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null || /etc/init.d/"$svc" status 2>/dev/null | grep -qw 'running\|Active'; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Not Running${NC}"
    fi
}

check_docker() {
    local container=$1
    local name=$2
    if docker ps -q -f name="$container" | grep -q .; then
        echo -e "${GREEN}Running${NC}"
    else
        echo -e "${RED}Not Running${NC}"
    fi
}

status_ssh=$(check_status ssh)
status_udp=$(check_status udp-custom)
status_ovpn=$(check_status openvpn)
status_ws=$(check_status ssh-ws)
status_dropbear=$(check_status dropbear)
status_cron=$(check_status cron)
status_nginx=$(check_docker marzban-nginx-1)
status_marzban=$(check_docker marzban-marzban-1)
status_vnstat=$(check_status vnstat)

function menu_banner() {
    clear
    echo -e " ${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e " ${BG_GRE}       🌸 MARZBAN AUTOSCRIPT X TF NUKLIR 🌸       ${NC}"
    echo -e " ${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE} System OS   : ${OS:-Unknown}${NC}"
    echo -e " ${WHITE} CPU Usage   : ${cpu_usage}${NC}"
    echo -e " ${WHITE} RAM Usage   : ${ram_usage}${NC}"
    echo -e " ${WHITE} Uptime      : ${UPTIME:-Unknown}${NC}"
    echo -e " ${WHITE} Domain      : ${domain:-Not Set}${NC}"
    echo -e " ${WHITE} Public IP   : ${MYIP:-Unknown}${NC}"
    echo -e " ${WHITE} ISP         : ${ISP}${NC}"
    echo -e " ${WHITE} Region      : ${CITY}${NC}"
    echo -e " ${WHITE} Latency     : ${ping} ms${NC}"
    echo -e " ${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE} SSH         : SSH Service is $status_ssh"
    echo -e " ${WHITE} UDP Custom  : UDP Custom Service is $status_udp"
    echo -e " ${WHITE} OpenVPN     : OpenVPN Service is $status_ovpn"
    echo -e " ${WHITE} SSH WS      : SSH Websocket Service is $status_ws"
    echo -e " ${WHITE} Dropbear    : Dropbear Service is $status_dropbear"
    echo -e " ${WHITE} Cron        : Cron Service is $status_cron"
    echo -e " ${WHITE} Vnstat      : Vnstat Service is $status_vnstat"
    echo -e " ${WHITE} Marzban     : Marzban Core Service is $status_marzban"
    echo -e " ${WHITE} Nginx       : Nginx Service is $status_nginx"
    echo -e " ${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e " ${WHITE} Today       :${NC} ${GREEN}${bwhari}${NC}"
    echo -e " ${WHITE} Yesterday   :${NC} ${GREEN}${bwkmrn}${NC}"
    echo -e " ${WHITE} This Month  :${NC} ${GREEN}${bwbln}${NC}"
    echo -e " ${YELLOW}──────────────────────────────────────────────────${NC}"
    echo -e " ${BG_GRE}           Type [ menu ] to access panel          ${NC}"
    echo -e " ${YELLOW}──────────────────────────────────────────────────${NC}"        
    echo
}
menu_banner