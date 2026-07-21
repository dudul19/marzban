#!/bin/bash

# collor
green='\e[32m'
yellow='\e[33m'
red='\e[31m'
reset='\e[0m'

# loop status
check_status() {
    local service_name=$1
    systemctl is-active --quiet "$service_name"
    if [ $? -eq 0 ]; then
        echo "on"
    else
        echo "off"
    fi
}

# cek status
status_dropbear=$(check_status dropbear)
status_websocket=$(check_status ssh-ws)

# display
if [[ "$status_dropbear" == "on" && "$status_websocket" == "on" ]]; then
    status_all="${green}ON${reset}"
elif [[ "$status_dropbear" == "off" && "$status_websocket" == "off" ]]; then
    status_all="${red}OFF${reset}"
else
    status_all="${yellow}OFF${reset}"
fi

clear
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " \E[0;100;33m          • SSH MANAGER •        \E[0m"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " SSH Status : $status_all"
echo -e ""
echo -e " [\e[36m•1\e[0m] Create SSH Acount "
echo -e " [\e[36m•2\e[0m] List   SSH Account"
echo -e " [\e[36m•3\e[0m] Delete SSH Acount "
echo -e " [\e[36m•4\e[0m] Renew  SSH Acount "
echo -e " [\e[36m•5\e[0m] Check  SSH Account Active Session"
echo -e ""
echo -e " [\e[31m•0\e[0m] \e[31mBACK TO MENU\033[0m"
echo -e ""
echo -e "   Press x or [ Ctrl+C ] • To-Exit"
echo -e "\e[33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -p " Select menu :  "  opt
echo -e ""
case $opt in
1) clear ; addssh ; exit ;;
2) clear ; member-ssh ; exit ;;
3) clear ; delete-ssh ; exit ;;
4) clear ; renew-ssh ; exit ;;
5) clear ; cek-ssh ; exit ;;
0) clear ; menu ; exit ;;
x) exit ;;
*) echo -e "${red}Invalid Option${reset}" ; sleep 1 ; menu-ssh ;;
esac
