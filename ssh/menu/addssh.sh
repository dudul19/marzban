#!/bin/bash
domain=$(cat /etc/data/domain)

FALSE_PATH=$(which false)
if [ -z "$FALSE_PATH" ]; then
    FALSE_PATH="/bin/false"
fi

grep -q "^${FALSE_PATH}$" /etc/shells || echo "$FALSE_PATH" >> /etc/shells

clear
echo "============================="
echo "         Create SSH          "
echo "============================="
read -p "Username: " username
read -p "Password: " password
read -p "Expired ( days ): " exp

clear

userdel -f "$username" &> /dev/null

useradd -e "$(date -d "$exp days" +"%Y-%m-%d")" -s "$FALSE_PATH" -M "$username"

echo "$username:$password" | chpasswd

expired=$(chage -l "$username" | grep -i "Account expires" | awk -F": " '{print $2}')
if [ -z "$expired" ] || [ "$expired" == "never" ]; then
    expired=$(date -d "$exp days" +"%Y-%m-%d")
fi

clear

echo "\`\`\`"
echo "==============================="
echo "          SSH Account          "
echo "==============================="
echo "Username     : $username"
echo "Password     : $password"
echo "Expired      : $expired"
echo "==============================="
echo "Domain       : $domain"
echo "==============================="
echo "WS HTTP      : 80"
echo "WS HTTPS     : 443"
echo "OpenSSH      : 22"
echo "Dropbear     : 109, 69"
echo "BadVPN       : 7300"
echo "HTTP Proxy   : 8080, 3128"
echo "==============================="
echo "OHP SSH      : 8181"
echo "OHP Dropbear : 8282"
echo "OHP OpenVPN  : 8383"
echo "==============================="
echo "UDP Custom   : 1-65535"
echo "==============================="
echo "OpenVPN TCP  : 1194"
echo "OpenVPN UDP  : 2200"
echo "File OVPN    : https://$domain/website/openvpn.zip"
echo "==============================="
echo "Payload WS   :"
echo "GET / HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]"
echo "==============================="
echo "\`\`\`"
