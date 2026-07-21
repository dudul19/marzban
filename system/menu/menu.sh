#!/bin/bash

#color
export red='\033[0;31m';
export NC='\033[0m';
export nc='\033[0m';

# data utama
domain=$(cat /etc/data/domain)

# data system
ml=$(echo "$(lsb_release -ds) [ $(uname -m) ]")
tram=$(free -m | awk 'NR==2 {print $2}')

# Ping Server
url="1.1.1.1"

ping=$(ping_result=$(ping -c 1 $url | grep -oP 'time=\K\d+\.\d+')
if (( $(echo "$ping_result < 100" | bc -l) )); then
    echo -e "\e[32m$ping_result ms\e[0m"
elif (( $(echo "$ping_result < 200" | bc -l) )); then
    echo -e "\e[33m$ping_result ms\e[0m"
else
    echo -e "\e[31m$ping_result ms\e[0m"
fi)

# Detail Badwidth
clear

# Fungsi untuk membaca data vnstat
read_vnstat_usage() {
  local interface=$1
  local today=$(vnstat -i "$interface" | grep "today" | awk '{print $8" "$9}')
  local yesterday=$(vnstat -i "$interface" | grep "yesterday" | awk '{print $8" "$9}')
  local this_month=$(vnstat -i "$interface" -m | grep "$(date +"%b '%y")" | awk '{print $9" "$10}')
  
  echo "$today;$yesterday;$this_month"
}

# Fungsi untuk mengonversi ke satuan MB
convert_to_mb() {
  local value=$1
  local unit=$2
  
  case $unit in
    B) echo "scale=6; $value / 1048576" | bc ;;
    KiB) echo "scale=6; $value / 1024" | bc ;;
    MiB) echo "$value" ;;
    GiB) echo "scale=6; $value * 1024" | bc ;;
    TiB) echo "scale=6; $value * 1048576" | bc ;;
    *) echo "0" ;;
  esac
}

# Mendapatkan semua interface
all_interfaces=$(vnstat --iflist | sed 's/Available interfaces: //')
if [ -z "$all_interfaces" ]; then
  echo "Tidak ada interface yang tersedia di vnstat."
  exit 1
fi

total_today=0
total_yesterday=0
total_month=0

for iface in $all_interfaces; do
  echo "Memproses interface: $iface"
  result=$(read_vnstat_usage "$iface")
  echo "Hasil untuk $iface: $result"
  
  today=$(echo "$result" | awk -F';' '{print $1}')
  yesterday=$(echo "$result" | awk -F';' '{print $2}')
  month=$(echo "$result" | awk -F';' '{print $3}')
  
  today_value=$(echo "$today" | awk '{print $1}')
  today_unit=$(echo "$today" | awk '{print $2}')
  
  yesterday_value=$(echo "$yesterday" | awk '{print $1}')
  yesterday_unit=$(echo "$yesterday" | awk '{print $2}')
  
  month_value=$(echo "$month" | awk '{print $1}')
  month_unit=$(echo "$month" | awk '{print $2}')
  
  total_today=$(echo "$total_today + $(convert_to_mb $today_value $today_unit)" | bc)
  total_yesterday=$(echo "$total_yesterday + $(convert_to_mb $yesterday_value $yesterday_unit)" | bc)
  total_month=$(echo "$total_month + $(convert_to_mb $month_value $month_unit)" | bc)
done

# Format hasil
format_usage() {
  local value=$1
  if (( $(echo "$value >= 1024" | bc -l) )); then
    echo "$(printf "%.2f" $(echo "$value / 1024" | bc)) GB"
  else
    echo "$(printf "%.2f" $value) MB"
  fi
}

ttoday=$(format_usage "$total_today")
tyest=$(format_usage "$total_yesterday")
tmon=$(format_usage "$total_month")

# Dinda Putri Cindyani

clear


echo -e " CLI Menu Marzban MultiPort X SSH Only Autoscript"
echo -e "================================================"
echo -e " OS: $ml"
echo -e " Ram: $tram MB"
echo -e " Domain: $domain"
echo -e " Server Ping: $ping [ $url ]"
echo -e "================================================"
echo -e " Today${NC}: ${red}$ttoday${NC} Yesterday${NC}: ${red}$tyest${NC} This month${NC}: ${red}$tmon${NC} "
echo -e "================================================"
echo -e " 1) Menu SSH"
echo -e " 2) Menu Marzban "
echo -e " 3) Change Domain "
echo -e " 4) Menu Backup "
echo -e " 5) Cek Service "
echo -e " 6) Setup Bot Marzban"
echo -e " 7) Warp Menu "
echo -e " 8) Menu Service [ Manager ]"
echo -e " 9) Renew Certificate"
echo -e " 0) exit"
echo -e "================================================"
echo -e " Autoscript Marzban FarelVPN X Rerechan02 "
echo -e "================================================"
read -p " Input Options [ 1 - 3 ] : " opt
case $opt in
1) menu-ssh ;;
2) marzban ;;
3) change-domain ;;
4) bmenu ;;
5) cekservice ;;
6) menu-bot ;;
7) warp ;;
8) fn-sc1 ;;
9) crt ;;
0) exit ;;
*) menu ;;
esac
