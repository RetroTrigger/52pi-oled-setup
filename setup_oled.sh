#!/bin/bash

# 52pi Mini Tower OLED Screen Setup Script
# This script sets up the OLED display for the 52pi mini tower case on Raspberry Pi 4
# Works with various Linux distributions

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="${SUDO_USER:-$USER}"

echo -e "${GREEN}52pi Mini Tower OLED Screen Setup${NC}"
echo "=========================================="
echo ""

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    elif [ -f /etc/arch-release ]; then
        DISTRO="arch"
    else
        DISTRO="unknown"
    fi
    echo "Detected distribution: $DISTRO"
}

# Function to install packages based on distribution
install_packages() {
    echo -e "${YELLOW}Installing required packages...${NC}"
    
    case $DISTRO in
        debian|ubuntu|raspbian)
            sudo apt-get update
            sudo apt-get install -y \
                i2c-tools \
                python3 \
                python3-pip \
                python3-pil \
                libjpeg-dev \
                zlib1g-dev \
                libfreetype6-dev \
                liblcms2-dev \
                libopenjp2-7 \
                libtiff5 \
                git
            ;;
        arch|manjaro|endeavouros)
            sudo pacman -S --noconfirm \
                i2c-tools \
                python \
                python-pip \
                python-pillow \
                git
            ;;
        fedora|rhel|centos)
            sudo dnf install -y \
                i2c-tools \
                python3 \
                python3-pip \
                python3-pillow \
                git
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO${NC}"
            echo "Please install manually: i2c-tools, python3, python3-pip, python3-pillow"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}Packages installed successfully${NC}"
}

# Function to enable I2C
enable_i2c() {
    echo -e "${YELLOW}Enabling I2C interface...${NC}"
    
    case $DISTRO in
        debian|ubuntu|raspbian)
            # Use raspi-config if available (Raspberry Pi)
            if command -v raspi-config &> /dev/null; then
                sudo raspi-config nonint do_i2c 0
            else
                # Manual I2C enable for other Debian-based systems
                if ! grep -q "^i2c-dev" /etc/modules; then
                    echo "i2c-dev" | sudo tee -a /etc/modules
                fi
                if ! grep -q "^dtparam=i2c_arm=on" /boot/config.txt 2>/dev/null; then
                    echo "dtparam=i2c_arm=on" | sudo tee -a /boot/config.txt
                fi
            fi
            ;;
        arch|manjaro|endeavouros)
            # Enable I2C modules
            if ! grep -q "^i2c-dev" /etc/modules-load.d/i2c.conf 2>/dev/null; then
                echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c.conf
            fi
            ;;
        fedora|rhel|centos)
            # Enable I2C modules
            if ! grep -q "^i2c-dev" /etc/modules-load.d/i2c.conf 2>/dev/null; then
                echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c.conf
            fi
            ;;
    esac
    
    echo -e "${GREEN}I2C interface enabled${NC}"
    echo -e "${YELLOW}Note: You may need to reboot for I2C changes to take effect${NC}"
}

# Function to add user to groups
add_user_to_groups() {
    echo -e "${YELLOW}Adding user to gpio and i2c groups...${NC}"
    
    sudo usermod -a -G gpio,i2c "$CURRENT_USER" 2>/dev/null || {
        # If gpio group doesn't exist, just add to i2c
        sudo usermod -a -G i2c "$CURRENT_USER"
    }
    
    echo -e "${GREEN}User added to groups${NC}"
    echo -e "${YELLOW}Note: You may need to log out and back in for group changes to take effect${NC}"
}

# Function to install Python libraries
install_python_libraries() {
    echo -e "${YELLOW}Installing Python libraries...${NC}"
    
    sudo -H pip3 install luma.oled pillow
    
    echo -e "${GREEN}Python libraries installed successfully${NC}"
}

# Function to verify display script
verify_display_script() {
    echo -e "${YELLOW}Verifying OLED display script...${NC}"
    
    if [ ! -f "$SCRIPT_DIR/oled_display.py" ]; then
        echo -e "${RED}Error: oled_display.py not found in $SCRIPT_DIR${NC}"
        echo "Please ensure oled_display.py exists in the same directory as this script"
        return 1
    fi
    
    chmod +x "$SCRIPT_DIR/oled_display.py"
    echo -e "${GREEN}Display script verified: $SCRIPT_DIR/oled_display.py${NC}"
}

# Function to create systemd service
create_systemd_service() {
    echo -e "${YELLOW}Creating systemd service...${NC}"
    
    SERVICE_FILE="/etc/systemd/system/oled_display.service"
    
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=52pi Mini Tower OLED Display Service
After=multi-user.target network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $SCRIPT_DIR/oled_display.py
Restart=always
RestartSec=10
User=$CURRENT_USER
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}Systemd service created${NC}"
    
    # Reload systemd and enable service
    sudo systemctl daemon-reload
    sudo systemctl enable oled_display.service
    
    echo -e "${GREEN}Service enabled (will start on boot)${NC}"
    echo -e "${YELLOW}To start the service now, run: sudo systemctl start oled_display.service${NC}"
}

# Function to verify I2C
verify_i2c() {
    echo -e "${YELLOW}Verifying I2C interface...${NC}"
    
    # Check if i2c-tools is installed
    if ! command -v i2cdetect &> /dev/null; then
        echo -e "${RED}i2cdetect not found. Please install i2c-tools.${NC}"
        return 1
    fi
    
    # Detect I2C devices
    echo "Scanning I2C bus..."
    if [ -e /dev/i2c-1 ]; then
        sudo i2cdetect -y 1
    elif [ -e /dev/i2c-0 ]; then
        sudo i2cdetect -y 0
    else
        echo -e "${RED}No I2C device found. Make sure I2C is enabled.${NC}"
        return 1
    fi
    
    echo -e "${GREEN}I2C verification complete${NC}"
    echo -e "${YELLOW}Look for address 0x3C in the output above (typical for OLED displays)${NC}"
}

# Main execution
main() {
    # Check if running as root or with sudo
    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        echo -e "${RED}This script requires sudo privileges${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    detect_distro
    install_packages
    enable_i2c
    add_user_to_groups
    install_python_libraries
    verify_display_script
    create_systemd_service
    verify_i2c
    
    echo ""
    echo -e "${GREEN}==========================================${NC}"
    echo -e "${GREEN}Setup completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Reboot your system: sudo reboot"
    echo "2. After reboot, the OLED display should start automatically"
    echo "3. To manually start: sudo systemctl start oled_display.service"
    echo "4. To check status: sudo systemctl status oled_display.service"
    echo "5. To set a custom message, create ~/.oled_message.txt"
    echo ""
    echo -e "${YELLOW}Note: You may need to log out and back in for group changes to take effect${NC}"
}

main "$@"
