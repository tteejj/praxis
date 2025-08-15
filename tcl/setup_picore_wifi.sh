#!/bin/bash

# ==============================================================================
# setup_picore_wifi.sh
#
# This script downloads the necessary TCZ packages and creates the
# configuration files to enable Wi-Fi on a headless piCore 16.0 system
# for a Raspberry Pi Zero 2 W.
#
# Created by Gemini
# ==============================================================================

# --- Configuration ---
BASE_URL="http://www.tinycorelinux.net/16.x/armhf/tcz"
WORK_DIR="picore_wifi_files"

# List of all required TCZ packages
TCZ_PACKAGES=(
    "ncurses.tcz"
    "readline.tcz"
    "libnl.tcz"
    "ca-certificates.tcz"
    "openssl.tcz"
    "wpa_supplicant.tcz"
    "wireless-6.1.69-piCore-v7l.tcz"
    "wireless_tools.tcz"
    "firmware-rpi-wifi.tcz"
    "wifi.tcz"
)

# --- Functions ---

# Function to print colored text
print_info() {
    printf "\033[1;34m%s\033[0m\n" "$1"
}

print_success() {
    printf "\033[1;32m%s\033[0m\n" "$1"
}

print_warning() {
    printf "\033[1;33m%s\033[0m\n" "$1"
}

# Check for wget or curl
if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
    print_warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    print_warning "!!! ERROR: Neither 'wget' nor 'curl' was found on your system."
    print_warning "!!! Please install one of them to proceed."
    print_warning "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
fi

# --- Main Script ---

print_info "### Starting piCore Wi-Fi Setup File Generation ###"

# 1. Create working directories
print_info "\n[1/5] Creating working directory structure..."
mkdir -p "${WORK_DIR}/tcz_packages"
mkdir -p "${WORK_DIR}/sd_card_files/tce/optional"
mkdir -p "${WORK_DIR}/sd_card_files/tce/etc"
mkdir -p "${WORK_DIR}/sd_card_files/tce/opt"
print_success " -> Done."

# 2. Download all TCZ packages
print_info "\n[2/5] Downloading 10 required TCZ packages..."
for pkg in "${TCZ_PACKAGES[@]}"; do
    if [ -f "${WORK_DIR}/tcz_packages/${pkg}" ]; then
        print_warning " -> Skipping ${pkg} (already exists)."
    else
        printf " -> Downloading %s..." "$pkg"
        if command -v wget &> /dev/null; then
            wget -q -P "${WORK_DIR}/tcz_packages/" "${BASE_URL}/${pkg}"
        else
            curl -s -L -o "${WORK_DIR}/tcz_packages/${pkg}" "${BASE_URL}/${pkg}"
        fi
        printf " Done.\n"
    fi
done
print_success " -> All packages downloaded successfully."

# 3. Create onboot.lst
print_info "\n[3/5] Creating onboot.lst..."
cat > "${WORK_DIR}/sd_card_files/tce/onboot.lst" << EOF
ncurses.tcz
readline.tcz
libnl.tcz
ca-certificates.tcz
openssl.tcz
wpa_supplicant.tcz
wireless-6.1.69-piCore-v7l.tcz
wireless_tools.tcz
firmware-rpi-wifi.tcz
wifi.tcz
EOF
print_success " -> Done."

# 4. Create configuration files
print_info "\n[4/5] Creating configuration and boot scripts..."

# Create wpa_supplicant.conf
cat > "${WORK_DIR}/sd_card_files/tce/etc/wpa_supplicant.conf" << EOF
# Configuration file for wpa_supplicant
#
# IMPORTANT:
# Replace "Your_SSID" with your Wi-Fi network name.
# Replace "Your_Password" with your Wi-Fi password.

ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=staff
update_config=1
country=US

network={
    ssid="Your_SSID"
    psk="Your_Password"
}
EOF

# Create mywifi.sh
cat > "${WORK_DIR}/sd_card_files/tce/opt/mywifi.sh" << EOF
#!/bin/sh
# Wait for wlan0 to be loaded by the firmware
for i in $(seq 1 10); do
    [ -d /sys/class/net/wlan0 ] && break
    sleep 1
done
# Copy our custom config and start wpa_supplicant
cp /usr/local/etc/wpa_supplicant.conf /etc/wpa_supplicant.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
udhcpc -i wlan0 -b -p /var/run/udhcpc.wlan0.pid
EOF

# Create bootlocal.sh
cat > "${WORK_DIR}/sd_card_files/tce/opt/bootlocal.sh" << EOF
#!/bin/sh
# Make our wifi script executable
chmod +x /opt/mywifi.sh
# Run our wifi script
/opt/mywifi.sh
EOF
print_success " -> Done."

# 5. Final instructions
print_info "\n[5/5] Finalizing..."
mv "${WORK_DIR}/tcz_packages"/* "${WORK_DIR}/sd_card_files/tce/optional/"
rmdir "${WORK_DIR}/tcz_packages"
print_success " -> All files have been generated and organized."

echo
print_success "############################################################"
print_success "###                  SETUP COMPLETE                      ###"
print_success "############################################################"
echo
print_info "All necessary files have been created in the:"
print_info " -> '${WORK_DIR}/sd_card_files/'"
echo
print_warning "!!!!!!!!!!!!!!!!!!!! IMPORTANT NEXT STEPS !!!!!!!!!!!!!!!!!!!!"
print_warning "1. EDIT THE WI-FI CONFIGURATION FILE:"
print_warning "   -> Open '${WORK_DIR}/sd_card_files/tce/etc/wpa_supplicant.conf'"
print_warning "   -> Change 'Your_SSID' and 'Your_Password' to your credentials."
echo
print_info "2. COPY THE FILES TO YOUR SD CARD (see instructions)."
echo
