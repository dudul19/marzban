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

ENV_PATH="/opt/marzban/.env"

liner() {
    echo -e " ${YELLOW}──────────────────────────────────${NC}"
}

ban_menu() {
    echo -e " ${YELLOW}──────────────────────────────────${NC}"
    echo -e " ${BG_GRE}     🌸 TELEGRAM BOT MENU 🌸      ${NC}"
    echo -e " ${YELLOW}──────────────────────────────────${NC}"
}

ban_setup() {
    echo -e " ${YELLOW}──────────────────────────────────${NC}"
    echo -e " ${BG_GRE}     🌸 SETUP TELEGRAM BOT 🌸     ${NC}"
    echo -e " ${YELLOW}──────────────────────────────────${NC}"
    echo
}

check_status() {
    if grep -qE "^\s*#\s*TELEGRAM_API_TOKEN" "$ENV_PATH" || ! grep -qE "^\s*TELEGRAM_API_TOKEN=" "$ENV_PATH"; then
        echo -e "Not Running"
    else
        echo -e "Running"
    fi
}

setup_bot() {
    if [ "$(check_status)" == "Not Running" ]; then
        clear
        ban_setup
        read -rp " $(echo -e "${WHITE}Bot Token    :${NC}") " api_token
        read -rp " $(echo -e "${WHITE}Telegram ID  :${NC}") " admin_id
        echo

        if [[ -z "$api_token" || -z "$admin_id" ]]; then
            echo -e "${RED} Error: API Token and Admin ID cannot be empty.${NC}"
            return
        fi

        sed -i 's/^\s*#\s*TELEGRAM_API_TOKEN/TELEGRAM_API_TOKEN/' "$ENV_PATH"
        sed -i 's/^\s*#\s*TELEGRAM_ADMIN_ID/TELEGRAM_ADMIN_ID/' "$ENV_PATH"
        sed -i "/^\s*TELEGRAM_API_TOKEN=/d" "$ENV_PATH"
        sed -i "/^\s*TELEGRAM_ADMIN_ID=/d" "$ENV_PATH"
        echo "TELEGRAM_API_TOKEN=$api_token" >> "$ENV_PATH"
        echo "TELEGRAM_ADMIN_ID=$admin_id" >> "$ENV_PATH"
        clear
        ban_setup 
        echo -e " ${GREEN} The bot has been activated.${NC}"
        liner
        sleep 2 
        menu-bot
    else
        clear
        ban_setup
        echo -e "${GREEN} The bot is now active!${NC}"
        liner
        sleep 2
    fi
}

delete_bot() {
    sed -i 's/^\s*TELEGRAM_API_TOKEN/# TELEGRAM_API_TOKEN/' "$ENV_PATH"
    sed -i 's/^\s*TELEGRAM_ADMIN_ID/# TELEGRAM_ADMIN_ID/' "$ENV_PATH"
    clear
    ban_setup
    echo -e "${RED} The bot has been disabled.${NC}"
    liner
    sleep 2
    menu-bot
}

while true; do
    STATUS=$(check_status)

    if [ "$STATUS" == "Running" ]; then
        STATUS_COLOR="${GREEN}$STATUS${NC}"
    else
        STATUS_COLOR="${RED}$STATUS${NC}"
    fi

    clear
    ban_menu
    echo -e " ${WWHITE} Status Bot: $STATUS_COLOR${NC}"
    liner
    echo -e " ${GREEN} 1.${NC}  ${WHITE}Setup Bot Panel Marzban${NC}"
    echo -e " ${GREEN} 2.${NC}  ${WHITE}Delete Bot Panel Marzban${NC}"
    echo -e " ${RED} x.${NC}  ${WHITE}Exit${NC}"
    liner
    echo
    read -p " Choose an Options [1-2 or x] : " opt
    case $opt in
    1) setup_bot ;;
    2) delete_bot ;;
    x) menu ;;
    *) echo ; echo -e "${RED} You pressed it wrong!${NC}" ; sleep 1 ; menu-bot ;;
    esac
done