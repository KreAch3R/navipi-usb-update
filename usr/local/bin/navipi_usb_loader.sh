#!/bin/sh
# by KreAch3R 2021
# Automatically called from udev when a USB is plugged.
# Used for loading the actual update initialization script
# /usr/local/bin/navipi_usb_update.sh
# /etc/udev/rules.d/99-navipi_usb_update.rules

# Variables
SCRIPT="/usr/local/bin/navipi_usb_update.sh"
# If you change this, you need to change it in /usr/local/bin/navipi_usb_update.sh as well
LOGFILE="/home/pi/Logs/navipi_update.log"

# https://unix.stackexchange.com/a/146617/90681
# Run long-running command on udev rule (using 'at' command)
# Run X apps using 'at' command (it doesn't use DISPLAY)
# https://stackoverflow.com/a/39022979/4008886
at <<EOF now
export DISPLAY=:0.0
export XAUTHORITY='/var/run/lightdm/root/:0'
bash -c "${SCRIPT} 2>&1 | tee ${LOGFILE}"
EOF
