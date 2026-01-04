#!/usr/bin/env python3
"""
52pi Mini Tower OLED Display Script
Displays system information on the OLED screen
"""

import time
import subprocess
import sys
from pathlib import Path
from luma.core.interface.serial import i2c
from luma.core.render import canvas
from luma.oled.device import ssd1306
from PIL import ImageFont

# Configuration
I2C_ADDRESS = 0x3C
I2C_PORT = 1
REFRESH_INTERVAL = 2  # seconds
CUSTOM_MESSAGE_FILE = Path.home() / ".oled_message.txt"

def get_ip_address():
    """Get the primary IP address"""
    try:
        # Try to get IP from default route interface
        result = subprocess.run(
            ['ip', 'route', 'get', '8.8.8.8'],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            ip = result.stdout.split('src ')[1].split()[0]
            return ip
    except:
        pass
    
    # Fallback: get first non-loopback IP
    try:
        result = subprocess.run(
            ['hostname', '-I'],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            ips = result.stdout.strip().split()
            for ip in ips:
                if not ip.startswith('127.'):
                    return ip
    except:
        pass
    
    return "No IP"

def get_cpu_usage():
    """Get CPU usage percentage"""
    try:
        result = subprocess.run(
            ['top', '-bn1'],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            cpu_line = [l for l in result.stdout.split('\n') if '%Cpu(s)' in l]
            if cpu_line:
                cpu_str = cpu_line[0].split('%Cpu(s):')[1].split('%us')[0].strip()
                try:
                    cpu_float = float(cpu_str)
                    return f"{cpu_float:.1f}%"
                except:
                    pass
    except:
        pass
    
    # Alternative method using /proc/stat
    try:
        with open('/proc/stat', 'r') as f:
            stats = f.readline().split()
            user = float(stats[1])
            nice = float(stats[2])
            system = float(stats[3])
            idle = float(stats[4])
            iowait = float(stats[5])
            
            total = user + nice + system + idle + iowait
            used = user + nice + system
            cpu_percent = (used / total) * 100
            return f"{cpu_percent:.1f}%"
    except:
        pass
    
    return "N/A"

def get_memory_usage():
    """Get memory usage percentage"""
    try:
        with open('/proc/meminfo', 'r') as f:
            meminfo = f.read()
            mem_total = int([l for l in meminfo.split('\n') if 'MemTotal:' in l][0].split()[1])
            mem_available = int([l for l in meminfo.split('\n') if 'MemAvailable:' in l][0].split()[1])
            mem_used = mem_total - mem_available
            mem_percent = (mem_used / mem_total) * 100
            return f"{mem_percent:.1f}%"
    except:
        return "N/A"

def get_disk_usage():
    """Get disk usage for root filesystem"""
    try:
        result = subprocess.run(
            ['df', '-h', '/'],
            capture_output=True,
            text=True,
            timeout=2
        )
        if result.returncode == 0:
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                parts = lines[1].split()
                if len(parts) >= 5:
                    used = parts[2]
                    total = parts[1]
                    percent = parts[4]
                    return f"{used}/{total} ({percent})"
    except:
        pass
    return "N/A"

def get_temperature():
    """Get CPU temperature"""
    # Try Raspberry Pi thermal zone
    thermal_zones = ['/sys/class/thermal/thermal_zone0/temp']
    
    # Also try other common locations
    for zone in thermal_zones:
        try:
            with open(zone, 'r') as f:
                temp_millidegrees = int(f.read().strip())
                temp_celsius = temp_millidegrees / 1000.0
                return f"{temp_celsius:.1f}°C"
        except:
            continue
    
    return "N/A"

def get_custom_message():
    """Get custom message from file if it exists"""
    try:
        if CUSTOM_MESSAGE_FILE.exists():
            with open(CUSTOM_MESSAGE_FILE, 'r') as f:
                message = f.read().strip()
                if message:
                    return message[:20]  # Limit to 20 chars for display
    except:
        pass
    return None

def main():
    """Main display loop"""
    try:
        # Initialize OLED display
        serial = i2c(port=I2C_PORT, address=I2C_ADDRESS)
        device = ssd1306(serial, width=128, height=64)
        
        print(f"OLED display initialized at I2C address 0x{I2C_ADDRESS:02X}")
        print("Press Ctrl+C to stop")
        
        # Try to load a font (fallback to default if not available)
        try:
            font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 10)
            font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 8)
        except:
            font = ImageFont.load_default()
            font_small = ImageFont.load_default()
        
        while True:
            with canvas(device) as draw:
                y_pos = 0
                line_height = 12
                
                # IP Address
                ip = get_ip_address()
                draw.text((0, y_pos), f"IP: {ip}", fill="white", font=font)
                y_pos += line_height
                
                # CPU Usage
                cpu = get_cpu_usage()
                draw.text((0, y_pos), f"CPU: {cpu}", fill="white", font=font)
                y_pos += line_height
                
                # Memory Usage
                mem = get_memory_usage()
                draw.text((0, y_pos), f"Mem: {mem}", fill="white", font=font)
                y_pos += line_height
                
                # Disk Usage
                disk = get_disk_usage()
                draw.text((0, y_pos), f"Disk: {disk}", fill="white", font=font_small)
                y_pos += line_height
                
                # Temperature
                temp = get_temperature()
                draw.text((0, y_pos), f"Temp: {temp}", fill="white", font=font)
                
                # Custom message (if available)
                custom_msg = get_custom_message()
                if custom_msg:
                    draw.text((0, 56), custom_msg, fill="white", font=font_small)
            
            time.sleep(REFRESH_INTERVAL)
            
    except KeyboardInterrupt:
        print("\nStopping display...")
        sys.exit(0)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
