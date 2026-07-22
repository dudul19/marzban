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

liner() {
    echo -e " ${YELLOW}──────────────────────────────────${NC}"
}

ban_menu() {
    echo -e " ${YELLOW}──────────────────────────────────${NC}"
    echo -e " ${BG_GRE}        🌸 CHANGE DOMAIN 🌸       ${NC}"
    echo -e " ${YELLOW}──────────────────────────────────${NC}"
}

if [ ! -f "/etc/data/domain" ]; then
  echo -e " ${RED} File /etc/data/domain not found!${NC}"
  exit 1
fi

domain2=$(cat /etc/data/domain)

clear
ban_menu
echo -e " ${WHITE} Your Current Domain: ${GREEN}$domain2${NC}"
liner
read -rp "  Enter New Domain: " domain
read -rp "  Enter your email: " email

if [[ -z "$domain" || -z "$email" ]]; then
  echo
  echo -e " ${GREEN} The domain or email cannot be empty!${NC}"
  sleep 2
  change-domain
fi

clear
echo -e "${GREEN}Stopping Marzban...${NC}"
marzban down > /dev/null 2>&1

echo -e "${GREEN}Requesting SSL certificate...${NC}"
/root/.acme.sh/acme.sh --server letsencrypt --register-account -m "$email" --issue -d "$domain" --standalone -k ec-256 --force --debug

echo -e "${GREEN}Installing SSL certificate...${NC}"
~/.acme.sh/acme.sh --installcert -d "$domain" --fullchainpath /var/lib/marzban/xray.crt --keypath /var/lib/marzban/xray.key --ecc
cat /var/lib/marzban/xray.crt
cat /var/lib/marzban/xray.key

echo -e "${GREEN}Updating domain configuration...${NC}"
mv /etc/data/domain /etc/data/domain.old
sudo rm -f /etc/data/domain
echo "$domain" | sudo tee /etc/data/domain
sudo rm -f /etc/xray/domain
echo "$domain" | sudo tee /etc/xray/domain

old=$(cat /etc/data/domain.old)

if [[ -z "$old" ]]; then
  echo -e "${GREEN}The old domain was not found in /etc/data/domain.old!${NC}"
  exit 1
fi

echo -e "${GREEN}Updating Nginx configuration...${NC}"
sed -i "s|$old|$domain|g" "/opt/marzban/nginx.conf"
sed -i "s|$old|$domain|g" "/etc/data/setup.log"

DB_PATH="/var/lib/marzban/db.sqlite3"

if [ ! -f "$DB_PATH" ]; then
  echo -e "${GREEN}Database $DB_PATH not found!${NC}"  
  exit 1
fi

SQL_QUERY="UPDATE hosts SET address = '$domain' WHERE address = '$old'; \
UPDATE hosts SET host = '$domain' WHERE host = '$old'; \
UPDATE hosts SET sni = '$domain' WHERE sni = '$old';"

echo -e "${GREEN}Updating database...${NC}" 
sqlite3 "$DB_PATH" "$SQL_QUERY"

if [ $? -eq 0 ]; then
  echo -e "${GREEN}Database update successful.${NC}" 
else
  echo -e "${GREEN}Database update failed!${NC}" 
  exit 1
fi

rm -f /etc/data/domain.old

echo -e "${GREEN}Restarting Marzban...${NC}" 
marzban restart
echo -e "${GREEN}Domain successfully updated to $domain!${NC}" 