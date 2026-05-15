#!/bin/bash

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
PURPLE='\033[1;35m'
NC='\033[0m'
B='\033[1m'

UUID_FILE="/workspace/uuid.txt"
CONFIG_FILE="/workspace/config.json"
LOG_DIR="/workspace/logs"
DOMAIN="${CODESPACE_NAME}-8443.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"

mkdir -p "$LOG_DIR"

if [ "$1" == "--silent-start" ]; then
    sudo chown -R vscode:vscode /var/lib/vnstat 2>/dev/null
    vnstatd -d 2>/dev/null
    if [ -f "$CONFIG_FILE" ]; then
        sudo systemctl stop xray 2>/dev/null
        nohup xray run -c "$CONFIG_FILE" > "$LOG_DIR/xray.log" 2>&1 &
    fi
    exit 0
fi

if ! pgrep -x "xray" > /dev/null && [ -f "$CONFIG_FILE" ]; then
    nohup xray run -c "$CONFIG_FILE" > "$LOG_DIR/xray.log" 2>&1 &
fi

draw_logo() {
    echo -e "${CYAN}${B}"
    echo "  ██████╗ ██████╗ ██████╗  █████╗ ██╗   ██╗"
    echo " ██╔════╝ ╚════██╗██╔══██╗██╔══██╗╚██╗ ██╔╝"
    echo " ██║  ███╗ █████╔╝██████╔╝███████║ ╚████╔╝ "
    echo " ██║   ██║██╔═══╝ ██╔══██╗██╔══██║  ╚██╔╝  "
    echo " ╚██████╔╝███████╗██║  ██║██║  ██║   ██║   "
    echo "  ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   "
    echo -e "${NC}${YELLOW}     Advanced Codespace Panel | CodeLeafy${NC}\n"
}

generate_config() {
    uuidgen > "$UUID_FILE"
    UUID=$(cat "$UUID_FILE")

    cat <<EOF > "$CONFIG_FILE"
{
  "log": { "loglevel": "warning" },
  "dns": {
    "servers": [
      "https://1.1.1.1/dns-query",
      "https://8.8.8.8/dns-query",
      "localhost"
    ],
    "queryStrategy": "UseIPv4"
  },
  "inbounds": [
    {
      "tag": "vless-in",
      "port": 8443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          { "id": "${UUID}", "flow": "", "level": 0, "email": "user@CodeLeafy" }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "none",
        "xhttpSettings": {
          "mode": "packet-up",
          "path": "/",
          "maxUploadSize": 1000000,
          "maxConcurrentUploads": 10
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "routeOnly": false
      }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom", "settings": { "domainStrategy": "UseIPv4" } },
    { "tag": "block", "protocol": "blackhole" }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "type": "field", "ip": ["geoip:private"], "outboundTag": "block" },
      { "type": "field", "protocol": ["bittorrent"], "outboundTag": "block" },
      { "type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "block" }
    ]
  }
}
EOF

    pkill -f "xray run" 2>/dev/null
    nohup xray run -c "$CONFIG_FILE" > "$LOG_DIR/xray.log" 2>&1 &
}

generate_link() {
    UUID=$(cat "$UUID_FILE")
    LINK="vless://${UUID}@${DOMAIN}:443?encryption=none&security=tls&type=xhttp&host=${DOMAIN}&path=%2F&mode=packet-up#CodeLeafy-G2Ray"
    echo "$LINK"
}

first_run() {
    clear
    draw_logo
    echo -e "${PURPLE}Welcome to the G2Ray Setup Guide!${NC}"
    echo -e "No configuration found. Please setup to continue.\n"
    echo -e "1) ${GREEN}Generate UUID & Create CodeLeafy Config${NC}"
    echo -e "2) ${RED}Exit to Terminal${NC}\n"
    read -p "Select an option [1-2]: " setup_choice
    
    if [ "$setup_choice" == "1" ]; then
        echo -e "\n${CYAN}Generating max-speed configuration...${NC}"
        generate_config
        echo -e "${GREEN}Configuration built successfully! Loading main menu...${NC}"
        sleep 2
    else
        clear
        exit 0
    fi
}

sudo chown -R vscode:vscode /var/lib/vnstat 2>/dev/null
vnstatd -d 2>/dev/null

if [ ! -f "$CONFIG_FILE" ]; then
    first_run
fi

while true; do
    clear
    draw_logo
    
    echo -e "1)  ${GREEN}View CodeLeafy VLESS Config & QR${NC}"
    echo -e "2)  ${CYAN}Generate New Config & UUID${NC}"
    echo -e "3)  ${YELLOW}Restart G2Ray Engine${NC}"
    echo -e "4)  ${PURPLE}View Data Usage (vnstat)${NC}"
    echo -e "5)  ${B}Codespace Quota & Uptime${NC}"
    echo -e "6)  ${RED}View Server Location${NC}"
    echo -e "7)  ${CYAN}Enable AutoStart on Terminal${NC}"
    echo -e "8)  ${NC}Exit to Terminal${NC}\n"
    
    read -p "Select an option [1-8]: " choice
    
    case $choice in
        1)
            clear
            draw_logo
            VLESS=$(generate_link)
            echo -e "${GREEN}Your Universal CodeLeafy Link (All Servers):${NC}\n"
            echo -e "${VLESS}\n"
            echo -e "${CYAN}Scan to Connect:${NC}"
            qrencode -t ANSIUTF8 "$VLESS"
            echo ""
            read -p "Press Enter to return..."
            ;;
        2)
            clear
            draw_logo
            echo -e "${RED}Warning: This will override existing CodeLeafy config.${NC}"
            read -p "Proceed? (y/n): " confirm
            if [ "$confirm" == "y" ]; then
                generate_config
                echo -e "${GREEN}New configuration created and applied!${NC}"
            fi
            sleep 1
            ;;
        3)
            clear
            draw_logo
            echo -e "${YELLOW}Restarting G2Ray (Xray Engine)...${NC}"
            pkill -f "xray run" 2>/dev/null
            nohup xray run -c "$CONFIG_FILE" > "$LOG_DIR/xray.log" 2>&1 &
            echo -e "${GREEN}Restarted successfully!${NC}"
            sleep 1
            ;;
        4)
            clear
            draw_logo
            echo -e "${PURPLE}Data Usage Statistics:${NC}\n"
            vnstat
            echo ""
            read -p "Press Enter to return..."
            ;;
        5)
            clear
            draw_logo
            UPTIME_SEC=$(cut -d. -f1 /proc/uptime)
            HOURS_USED=$(echo "scale=2; $UPTIME_SEC / 3600" | bc)
            HOURS_LEFT=$(echo "scale=2; 60.00 - $HOURS_USED" | bc)
            echo -e "${B}Current Session Data:${NC}"
            echo -e "Time consumed: ${RED}${HOURS_USED} hours${NC}"
            echo -e "Time remaining: ${GREEN}${HOURS_LEFT} hours${NC} (of 60h free tier)"
            echo ""
            read -p "Press Enter to return..."
            ;;
        6)
            clear
            draw_logo
            echo -e "${CYAN}Fetching Location Data...${NC}"
            CITY=$(curl -s https://ipapi.co/city)
            COUNTRY=$(curl -s https://ipapi.co/country_name)
            IP=$(curl -s https://ipapi.co/ip)
            echo -e "\nServer IP: ${B}${IP}${NC}"
            echo -e "Location:  ${B}${CITY}, ${COUNTRY}${NC}"
            echo ""
            read -p "Press Enter to return..."
            ;;
        7)
            clear
            draw_logo
            if grep -q "g2ray.sh" ~/.bashrc; then
                echo -e "${YELLOW}AutoStart is already enabled!${NC}"
            else
                echo "bash /workspace/g2ray.sh" >> ~/.bashrc
                echo -e "${GREEN}AutoStart enabled! G2Ray CLI will open on ALL new terminal tabs.${NC}"
            fi
            sleep 2
            ;;
        8)
            clear
            exit 0
            ;;
        *)
            ;;
    esac
done
