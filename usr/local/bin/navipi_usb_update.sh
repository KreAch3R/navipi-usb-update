#!/bin/bash
# by KreAch3R 2021
# Automatically called from udev when a USB is plugged.
# /usr/local/bin/navipi_usb_loader.sh runs this script.
# from /etc/udev/rules.d/99-navipi_usb_update.rules

# Colors
green=`tput setaf 2`
cyan=`tput setaf 6`
red=`tput setaf 1`
yellow=`tput setaf 3`
reset=`tput sgr0`

# Variables
UPDATETRIGGER="navipi.update"
USBPATH="/home/pi" #default
SCRIPT=$(realpath "$0")
# If you change this, you need to change it in /usr/local/bin/navipi_usb_loader.sh as well
LOGFILE="/home/pi/Logs/navipi_update.log"

# Overloading function
function general_update { :; }

# Runs on background only, before any UI
function locate_usb {
    echo "Locating \"UPDATE\" USB storage media..."
    USBLIST=( $(find "/media/pi"/* -name "${UPDATETRIGGER}" -printf '%h\n') )
    if [ "${#USBLIST[@]}" -eq 1 ]; then
        USBPATH="${USBLIST[0]}"
        echo "Found: ${USBPATH}"
    else
        if [ "${#USBLIST[@]}" -gt 1 ]; then
            USB_WARNING="Multiple USB devices with "${UPDATETRIGGER}" found. Please remove all USB devices, insert only one and retry."
            zenity --error --text="${USB_WARNING}" --width=300 --height=100
        else
            USB_WARNING="No "${UPDATETRIGGER}" on any USB device."
        fi
        echo "${USB_WARNING}"
        return 1
    fi
}

# Needs USBPATH as $1!
function zip_extract {
    USBPATH="$1"
    echo "Starting ZIP extraction..."
    # maxdepth is needed so find can't look too deep into USBPATH, only one directory down
    ZIPS=$(find "${USBPATH}"/* -maxdepth 0 -type f -name "*.zip")
    if [[ -z ${ZIPS} ]] ; then
        NO_ZIPS_ERROR="No Zip files found in the USB media. Please retry."
        zenity --error --text="${NO_ZIPS_ERROR}" --width=300 --height=100
        exit 1
    else
        for ZIP in "${ZIPS}"; do
            FILE="${ZIP##*/}"
            FILENAME="${FILE%.zip}"
            echo "Found: ${yellow}${FILE}${reset}"

            echo "Copying to /tmp..."
            sudo cp "${ZIP}" /tmp/
            sudo unzip -o /tmp/"${FILE}" -d /tmp/
            if [ -f "/tmp/${FILENAME}/${FILENAME}.sh" ]; then
                echo "${green}Found: "${FILENAME}".sh, including it...${reset}"
                . /tmp/"${FILENAME}"/"${FILENAME}".sh
                if [ $? -ne 0 ]; then
                    SCRIPT_LOADING_ERROR="Script loading failed, probably a badly formatted file. Please check the log and fix the script!"
                    zenity --error --text="${SCRIPT_LOADING_ERROR}" --width=300 --height=100
                    exit 1
                fi
            else
                echo "${yellow}No update.sh found, copy-only mode engaged${reset}"
            fi
        done
    fi
}

# Overloading function
function deps_update { :; }

# Installs files from /tmp/* to specified directories
function install_files {
    for FILEPATH in $(cd "/tmp/${FILENAME}" && find * -mindepth 2 -type f); do
        SOURCE_FILEPATH="/tmp/${FILENAME}/${FILEPATH}"
        DESTINATION_PATH="/${FILEPATH%/*}"
        install_system "${SOURCE_FILEPATH}" "${DESTINATION_PATH}"
    done
}

# Internal function of install_files
# Creates backups
function install_system {
    SOURCE_FILEPATH="${1}"
    SOURCE_FILENAME="${1##*/}"
    DESTINATION_PATH="${2}"
    DESTINATION_FILEPATH="${DESTINATION_PATH}/${SOURCE_FILENAME}"
    #echo "SOURCE_FILEPATH: $SOURCE_FILEPATH"
    #echo "SOURCE_FILENAME: $SOURCE_FILENAME"
    #echo "DESTINATION_PATH: $DESTINATION_PATH"
    #echo "DESTINATION_FILEPATH: $DESTINATION_FILEPATH"

    if [ -f "${DESTINATION_FILEPATH}" ]; then
        BACKUP_FILES_COUNT=$(find "${DESTINATION_PATH}" -type f -name *"${SOURCE_FILENAME}".backup.* | wc -l)
        BACKUP_FILE="${DESTINATION_FILEPATH}.backup.${BACKUP_FILES_COUNT}"

        echo "Creating backup file at ${BACKUP_FILE}."
        echo "${cyan}Replacing ${DESTINATION_FILEPATH}.${reset}"
        sudo mv "${DESTINATION_FILEPATH}" "${BACKUP_FILE}"
    else
         echo "${green}Installing ${DESTINATION_FILEPATH}.${reset}"
    fi
    # Preserves permissions
    sudo cp -p "${SOURCE_FILEPATH}" "${DESTINATION_FILEPATH}"
}

# Overloading function
function services_update { :; }

# LOGFILE cleanup from color output
function clean_log {
    sed -i '/^tput/d' "${LOGFILE}"
    sed -i -e 's/\x1B[^m]*m//g' "${LOGFILE}"
}

# Launches a terminal and GUI for the user only after a compatible USB media has been found.
# Needs USBPATH as $1
function terminal {
    USBPATH="$1"

    echo "Killing OpenAuto Pro application."
    pkill autoapp

    zip_extract "${USBPATH}"

    general_update

    deps_update

    install_files

    services_update

    echo "${green}Update finished.${reset}"

    clean_log

    zenity --question --title="Update Finished!" --icon-name=info --text="It's suggested to reboot the system. Reboot now?" --width=300 --height=100
    if [ $? = 0 ]; then
        sudo reboot
    fi
}

####################################################
# Script start
####################################################

# Allow running specific functions as script argument
if [ "$1" ]; then
    $1 "${@:2}"
    exit 0
fi

# Logging starts
echo "NaviPi update script."

echo "Wait for USB media to finish mounting..."
sleep 5

locate_usb
if [ $? = 0 ]; then
    echo "Asking for user confirmation to install."
    zenity --question --title="Update Found!" --icon-name=info --text="USB media contains a NaviPi update. Install it?" --width=300 --height=100
    if [ $? = 0 ]; then
        # Run a bash function in a separate terminal window
        # Used my method of running specific functions as script arguments and combined it with
        # https://stackoverflow.com/a/23002964/4008886
        x-terminal-emulator -e bash -c "${SCRIPT} \"terminal\" \"${USBPATH}\" | tee -a ${LOGFILE}"
    else
        echo "Update aborted."
    fi
else
    echo "No "${UPDATETRIGGER}" found. Aborting."
fi
