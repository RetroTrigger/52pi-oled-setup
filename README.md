# 52pi Mini Tower OLED Screen Setup

Setup scripts for the 0.96-inch OLED display on the 52pi mini tower case for Raspberry Pi 4.

## Files

- `setup_oled.sh` - Main setup script that configures the system and installs dependencies
- `oled_display.py` - Python script that displays system information on the OLED screen

## Features

- **Distro Agnostic**: Works with Debian/Ubuntu, Arch, Fedora, and other Linux distributions
- **System Information Display**: Shows IP address, CPU usage, memory usage, disk usage, and temperature
- **Custom Messages**: Support for custom text messages via `~/.oled_message.txt`
- **Auto-start**: Automatically starts on boot via systemd service

## Quick Start

1. **Run the setup script** (requires sudo):
   ```bash
   sudo ./setup_oled.sh
   ```

2. **Reboot your system**:
   ```bash
   sudo reboot
   ```

3. After reboot, the OLED display should automatically start showing system information.

## Manual Control

- **Start the service manually**:
  ```bash
  sudo systemctl start oled_display.service
  ```

- **Stop the service**:
  ```bash
  sudo systemctl stop oled_display.service
  ```

- **Check service status**:
  ```bash
  sudo systemctl status oled_display.service
  ```

- **View service logs**:
  ```bash
  sudo journalctl -u oled_display.service -f
  ```

- **Run the display script directly** (for testing):
  ```bash
  python3 oled_display.py
  ```

## Custom Messages

To display a custom message on the OLED screen, create a file at `~/.oled_message.txt`:

```bash
echo "Hello World" > ~/.oled_message.txt
```

The message will appear at the bottom of the display (limited to 20 characters).

## Configuration

You can modify the following settings in `oled_display.py`:

- `I2C_ADDRESS` - I2C address of the OLED (default: 0x3C)
- `I2C_PORT` - I2C port number (default: 1)
- `REFRESH_INTERVAL` - Update interval in seconds (default: 2)
- `CUSTOM_MESSAGE_FILE` - Path to custom message file

## Troubleshooting

### I2C Not Detected

1. Verify I2C is enabled:
   ```bash
   sudo i2cdetect -y 1
   ```
   Look for address `0x3C` in the output.

2. If not detected, ensure I2C is enabled and reboot:
   ```bash
   sudo raspi-config  # For Raspberry Pi OS
   # Navigate to Interface Options > I2C > Enable
   sudo reboot
   ```

### Display Not Working

1. Check if the service is running:
   ```bash
   sudo systemctl status oled_display.service
   ```

2. Check the logs for errors:
   ```bash
   sudo journalctl -u oled_display.service -n 50
   ```

3. Test the script directly:
   ```bash
   python3 oled_display.py
   ```

### Permission Issues

If you get permission errors, ensure your user is in the `i2c` group:

```bash
sudo usermod -a -G i2c $USER
# Log out and back in for changes to take effect
```

## Requirements

- Python 3
- I2C interface support
- Root/sudo access for setup
- OLED display connected via I2C (typically at address 0x3C)

## Display Information

The OLED screen displays:
- **IP Address**: Primary network IP address
- **CPU**: CPU usage percentage
- **Mem**: Memory usage percentage
- **Disk**: Disk usage (used/total and percentage)
- **Temp**: CPU temperature in Celsius
- **Custom Message**: Optional custom text from `~/.oled_message.txt`

## License

This script is provided as-is for use with the 52pi mini tower case.
