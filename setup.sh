#!/bin/bash

# 52pi Mini Tower Combined Setup Script
# Installs OLED display, LED fan, or both

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}52pi Mini Tower Setup${NC}"
echo "======================================"
echo ""
echo "What would you like to install?"
echo ""
echo "  1) OLED Display only"
echo "  2) LED Fan only"
echo "  3) Both OLED Display and LED Fan"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        echo -e "\n${YELLOW}Installing OLED Display...${NC}"
        bash "$SCRIPT_DIR/setup_oled.sh"
        ;;
    2)
        echo -e "\n${YELLOW}Installing LED Fan...${NC}"
        bash "$SCRIPT_DIR/setup_fan.sh"
        ;;
    3)
        echo -e "\n${YELLOW}Installing OLED Display...${NC}"
        bash "$SCRIPT_DIR/setup_oled.sh"
        echo -e "\n${YELLOW}Installing LED Fan...${NC}"
        bash "$SCRIPT_DIR/setup_fan.sh"
        ;;
    *)
        echo -e "${RED}Invalid choice. Please run again and select 1, 2, or 3.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Setup complete!${NC}"
echo ""

read -p "Reboot now? [Y/n]: " reboot_choice
reboot_choice=${reboot_choice:-Y}

if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Rebooting...${NC}"
    sudo reboot
else
    echo -e "${YELLOW}Please reboot manually when ready: sudo reboot${NC}"
fi
