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

domain=$(cat /etc/data/domain)

echo -e "${GREEN}Stopping the Marzban service temporarily...${NC}" 
cd /opt/marzban && docker compose down

echo -e "${GREEN}Starting the certificate generation process (Let's Encrypt) for $domain...${NC}" 
/root/.acme.sh/acme.sh --issue -d $domain --standalone --server letsencrypt --force

echo -e "${GREEN}Installing the certificate to the Marzban directory...${NC}" 
/root/.acme.sh/acme.sh --install-cert -d $domain \
    --fullchain-file /var/lib/marzban/xray.crt \
    --key-file /var/lib/marzban/xray.key

chmod 755 /var/lib/marzban/xray.crt
chmod 755 /var/lib/marzban/xray.key

echo -e "${GREEN}Restarting the Marzban service...${NC}" 
cd /opt/marzban && docker compose up -d

echo -e "${GREEN}The certificate has been successfully updated!${NC}"
sleep 2 
menu