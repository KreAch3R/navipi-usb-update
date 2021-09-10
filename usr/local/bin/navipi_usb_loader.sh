#!/bin/sh
# by KreAch3R 2021
# Automatically called from udev when a USB is plugged.
# Used for loading the actual update initialization script
# /usr/local/bin/navipi_usb_update.sh
# /etc/udev/rules.d/99-navipi_usb_update.rules

SCRIPT="/usr/local/bin/navipi_usb_update.sh"

# https://unix.stackexchange.com/a/146617/90681
# Run long-running command on udev rule (using 'at' command)
cat <<EOF | at now + 1 minute
if [ -f "${SCRIPT}" ]; then
bash "${SCRIPT}" > /home/pi/Logs/navipi_update.log
fi
EOF
