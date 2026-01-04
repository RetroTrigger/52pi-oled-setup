#!/bin/bash

# 52pi Mini Tower LED Fan Setup Script
# This script sets up the LED fan control for the 52pi mini tower case

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_USER="${SUDO_USER:-$USER}"

echo -e "${GREEN}52pi Mini Tower LED Fan Setup${NC}"
echo "======================================"
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

# Function to check if a package is installed (Debian/Ubuntu)
check_package_deb() {
    dpkg -l | grep -q "^ii.*$1 " 2>/dev/null
}

# Function to check if a package is installed (Arch)
check_package_arch() {
    pacman -Qi "$1" &>/dev/null
}

# Function to check if a package is installed (Fedora/RHEL/CentOS)
check_package_rpm() {
    rpm -q "$1" &>/dev/null
}

# Function to install packages
install_packages() {
    echo -e "${YELLOW}Checking and installing required packages...${NC}"
    
    case $DISTRO in
        debian|ubuntu|raspbian)
            sudo apt-get update -qq
            PACKAGES="python3-pip git build-essential python3-dev scons swig"
            MISSING_PACKAGES=""
            
            for pkg in $PACKAGES; do
                if ! check_package_deb "$pkg"; then
                    MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
                else
                    echo -e "${GREEN}Package $pkg is already installed${NC}"
                fi
            done
            
            if [ -n "$MISSING_PACKAGES" ]; then
                echo -e "${YELLOW}Installing missing packages:${MISSING_PACKAGES}${NC}"
                sudo apt-get install -y $MISSING_PACKAGES
            else
                echo -e "${GREEN}All required packages are already installed${NC}"
            fi
            ;;
        arch|manjaro|endeavouros)
            MAIN_PACKAGES="python-pip git base-devel"
            MISSING_PACKAGES=""
            
            for pkg in $MAIN_PACKAGES; do
                if ! check_package_arch "$pkg"; then
                    MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
                else
                    echo -e "${GREEN}Package $pkg is already installed${NC}"
                fi
            done
            
            if [ -n "$MISSING_PACKAGES" ]; then
                echo -e "${YELLOW}Installing missing packages:${MISSING_PACKAGES}${NC}"
                sudo pacman -S --noconfirm $MISSING_PACKAGES
            else
                echo -e "${GREEN}All required packages are already installed${NC}"
            fi
            ;;
        fedora|rhel|centos)
            PACKAGES="python3-pip git gcc python3-devel"
            MISSING_PACKAGES=""
            
            for pkg in $PACKAGES; do
                if ! check_package_rpm "$pkg"; then
                    MISSING_PACKAGES="$MISSING_PACKAGES $pkg"
                else
                    echo -e "${GREEN}Package $pkg is already installed${NC}"
                fi
            done
            
            if [ -n "$MISSING_PACKAGES" ]; then
                echo -e "${YELLOW}Installing missing packages:${MISSING_PACKAGES}${NC}"
                sudo dnf install -y $MISSING_PACKAGES
            else
                echo -e "${GREEN}All required packages are already installed${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}Package check completed${NC}"
}

# Function to configure GPIO permissions
configure_gpio_permissions() {
    echo -e "${YELLOW}Configuring GPIO permissions...${NC}"
    
    # Add user to gpio group if it exists
    if getent group gpio > /dev/null 2>&1; then
        sudo usermod -a -G gpio "$CURRENT_USER"
        echo -e "${GREEN}User added to gpio group${NC}"
    fi
    
    # For rpi-ws281x, we may need to run as root or use udev rules
    # Create udev rule for GPIO access (if on Raspberry Pi)
    if [ -d /sys/class/gpio ]; then
        echo -e "${YELLOW}Note: rpi-ws281x library requires root access for GPIO/PWM${NC}"
        echo -e "${YELLOW}The service will run as root for proper hardware access${NC}"
    fi
    
    echo -e "${GREEN}GPIO configuration completed${NC}"
}

# Function to install Python libraries using virtual environment
install_python_libraries() {
    # Determine Python command
    if [ "$DISTRO" = "arch" ] || [ "$DISTRO" = "manjaro" ] || [ "$DISTRO" = "endeavouros" ]; then
        PYTHON_CMD="python"
    else
        PYTHON_CMD="python3"
    fi
    
    # Use existing venv or create new one
    VENV_DIR="$SCRIPT_DIR/venv"
    
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${YELLOW}Creating Python virtual environment...${NC}"
        $PYTHON_CMD -m venv "$VENV_DIR"
        echo -e "${GREEN}Virtual environment created${NC}"
    else
        echo -e "${GREEN}Using existing virtual environment${NC}"
    fi
    
    # Activate venv and install packages
    echo -e "${YELLOW}Checking Python libraries for LED fan...${NC}"
    source "$VENV_DIR/bin/activate"
    
    # Install rpi-ws281x library for controlling WS2812 LEDs
    if pip show rpi-ws281x &>/dev/null; then
        echo -e "${GREEN}Package rpi-ws281x is already installed${NC}"
    else
        echo -e "${YELLOW}Installing rpi-ws281x...${NC}"
        pip install rpi-ws281x
    fi
    
    deactivate
    echo -e "${GREEN}Python libraries check completed${NC}"
}

# Function to create fan control script
create_fan_script() {
    echo -e "${YELLOW}Creating LED fan control script...${NC}"
    
    cat > "$SCRIPT_DIR/fan_control.py" << 'PYTHON_EOF'
#!/usr/bin/env python3
"""
52pi Mini Tower LED Fan Control Script
Controls the RGB LED fan using WS2812/NeoPixel LEDs
"""

import time
import sys
from rpi_ws281x import PixelStrip, Color

# LED strip configuration
LED_COUNT = 12          # Number of LED pixels (typical for 52pi fan)
LED_PIN = 18            # GPIO pin connected to the LED strip (18 = PWM0)
LED_FREQ_HZ = 800000    # LED signal frequency in hertz
LED_DMA = 10            # DMA channel to use
LED_BRIGHTNESS = 255    # Brightness (0-255)
LED_INVERT = False      # Invert signal
LED_CHANNEL = 0         # PWM channel (0 or 1)

def color_wipe(strip, color, wait_ms=50):
    """Wipe color across display a pixel at a time."""
    for i in range(strip.numPixels()):
        strip.setPixelColor(i, color)
        strip.show()
        time.sleep(wait_ms / 1000.0)

def rainbow_cycle(strip, wait_ms=20, iterations=5):
    """Draw rainbow that uniformly distributes itself across all pixels."""
    for j in range(256 * iterations):
        for i in range(strip.numPixels()):
            pixel_index = (i * 256 // strip.numPixels()) + j
            strip.setPixelColor(i, wheel(pixel_index & 255))
        strip.show()
        time.sleep(wait_ms / 1000.0)

def wheel(pos):
    """Generate rainbow colors across 0-255 positions."""
    if pos < 85:
        return Color(pos * 3, 255 - pos * 3, 0)
    elif pos < 170:
        pos -= 85
        return Color(255 - pos * 3, 0, pos * 3)
    else:
        pos -= 170
        return Color(0, pos * 3, 255 - pos * 3)

def solid_color(strip, color):
    """Set all LEDs to a solid color."""
    for i in range(strip.numPixels()):
        strip.setPixelColor(i, color)
    strip.show()

def main():
    """Main function"""
    # Create NeoPixel object
    try:
        strip = PixelStrip(
            LED_COUNT, LED_PIN, LED_FREQ_HZ, LED_DMA, LED_INVERT, LED_BRIGHTNESS, LED_CHANNEL
        )
        strip.begin()
        print(f"LED strip initialized with {LED_COUNT} LEDs on GPIO {LED_PIN}")
    except Exception as e:
        print(f"Error initializing LED strip: {e}")
        print("Make sure you're running on a Raspberry Pi with proper GPIO access")
        sys.exit(1)
    
    # Default mode: rainbow cycle
    mode = "rainbow"
    if len(sys.argv) > 1:
        mode = sys.argv[1].lower()
    
    try:
        if mode == "rainbow" or mode == "cycle":
            print("Starting rainbow cycle mode (Ctrl+C to stop)")
            while True:
                rainbow_cycle(strip)
        elif mode == "red":
            print("Setting LEDs to red")
            solid_color(strip, Color(255, 0, 0))
            time.sleep(3600)  # Keep on for 1 hour
        elif mode == "green":
            print("Setting LEDs to green")
            solid_color(strip, Color(0, 255, 0))
            time.sleep(3600)
        elif mode == "blue":
            print("Setting LEDs to blue")
            solid_color(strip, Color(0, 0, 255))
            time.sleep(3600)
        elif mode == "white":
            print("Setting LEDs to white")
            solid_color(strip, Color(255, 255, 255))
            time.sleep(3600)
        elif mode == "off":
            print("Turning LEDs off")
            solid_color(strip, Color(0, 0, 0))
        elif mode == "wipe":
            print("Color wipe effect")
            color_wipe(strip, Color(255, 0, 0))  # Red
            color_wipe(strip, Color(0, 255, 0))  # Green
            color_wipe(strip, Color(0, 0, 255))  # Blue
            solid_color(strip, Color(0, 0, 0))   # Off
        else:
            print(f"Unknown mode: {mode}")
            print("Available modes: rainbow, red, green, blue, white, off, wipe")
            sys.exit(1)
    except KeyboardInterrupt:
        print("\nStopping LED control...")
        solid_color(strip, Color(0, 0, 0))  # Turn off on exit
        sys.exit(0)

if __name__ == "__main__":
    main()
PYTHON_EOF

    chmod +x "$SCRIPT_DIR/fan_control.py"
    echo -e "${GREEN}Fan control script created: $SCRIPT_DIR/fan_control.py${NC}"
}

# Function to create systemd service
create_systemd_service() {
    echo -e "${YELLOW}Creating systemd service for LED fan...${NC}"
    
    SERVICE_FILE="/etc/systemd/system/led_fan.service"
    VENV_DIR="$SCRIPT_DIR/venv"
    VENV_PYTHON="$VENV_DIR/bin/python"
    
    if [ ! -f "$VENV_PYTHON" ]; then
        echo -e "${RED}Error: Virtual environment not found${NC}"
        return 1
    fi
    
    # Ask user for default mode
    echo -e "${YELLOW}Choose default LED mode:${NC}"
    echo "1) Rainbow cycle (default)"
    echo "2) Solid color (red, green, blue, or white)"
    echo "3) Off"
    read -p "Enter choice [1-3] (default: 1): " choice
    choice=${choice:-1}
    
    case $choice in
        1) MODE="rainbow" ;;
        2) 
            read -p "Enter color (red/green/blue/white): " color
            MODE=${color:-"red"}
            ;;
        3) MODE="off" ;;
        *) MODE="rainbow" ;;
    esac
    
    # Create a wrapper script that runs with proper permissions
    WRAPPER_SCRIPT="$SCRIPT_DIR/fan_control_wrapper.sh"
    cat > "$WRAPPER_SCRIPT" << WRAPPER_EOF
#!/bin/bash
# Wrapper script for LED fan control
cd $SCRIPT_DIR
source $VENV_DIR/bin/activate
exec $VENV_PYTHON $SCRIPT_DIR/fan_control.py $MODE
WRAPPER_EOF
    chmod +x "$WRAPPER_SCRIPT"
    
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=52pi Mini Tower LED Fan Service
After=multi-user.target

[Service]
Type=simple
# Run as root for GPIO access (rpi-ws281x requires root)
ExecStart=$WRAPPER_SCRIPT
Restart=always
RestartSec=10
WorkingDirectory=$SCRIPT_DIR
StandardOutput=journal
StandardError=journal
# Set environment for proper GPIO access
Environment="PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${GREEN}Systemd service created${NC}"
    sudo systemctl daemon-reload
    sudo systemctl enable led_fan.service
    
    echo -e "${GREEN}Service enabled (will start on boot)${NC}"
    echo -e "${YELLOW}To start the service now, run: sudo systemctl start led_fan.service${NC}"
}

# Main execution
main() {
    if [ "$EUID" -ne 0 ] && ! sudo -n true 2>/dev/null; then
        echo -e "${RED}This script requires sudo privileges${NC}"
        echo "Please run: sudo $0"
        exit 1
    fi
    
    detect_distro
    install_packages
    configure_gpio_permissions
    install_python_libraries
    create_fan_script
    create_systemd_service
    
    echo ""
    echo -e "${GREEN}======================================"
    echo -e "${GREEN}LED Fan setup completed!${NC}"
    echo ""
    echo "Usage:"
    echo "  source venv/bin/activate"
    echo "  python fan_control.py [mode]"
    echo ""
    echo "Modes: rainbow, red, green, blue, white, off, wipe"
    echo ""
    echo "To start the service: sudo systemctl start led_fan.service"
    echo "To check status: sudo systemctl status led_fan.service"
}

main "$@"
