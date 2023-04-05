#!/bin/bash
# by KreAch3R 2021 - 2023
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
# Version: 1.5
UPDATETRIGGER="navipi.update"
USBPATH="/home/pi" #default
SCRIPT=$(realpath "$0")
# If you change this, you need to change it in /usr/local/bin/navipi_usb_loader.sh as well
LOGFILE="/home/pi/Logs/navipi_update.log"
# Changes to true only if an openauto_update_package.zip is found
oap_update=false

# Overloading function
function general_update { :; }

# Overloading function
function deps_update { :; }

# Overloading function
function services_update { :; }

# Overloading function
function openauto_update {
    if [ "$oap_update" = true ] ; then
        echo "${yellow}Starting OAP system update...!${reset}"
        # Run update.sh in the correct subdirectory in another sub shell
        (cd /tmp/openauto_update_package/ && . update.sh)
    fi
}

# Runs on background
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

# Installs files from /tmp/* to specified directories
# Needs $FILENAME as $1
function install_files {
    FILENAME="${1}"
    if [ -d "/tmp/${FILENAME}" ]; then
        for FILEPATH in $(cd "/tmp/${FILENAME}" && find * -mindepth 2 -type f); do
            SOURCE_FILEPATH="/tmp/${FILENAME}/${FILEPATH}"
            DESTINATION_PATH="/${FILEPATH%/*}"
            install_system "${SOURCE_FILEPATH}" "${DESTINATION_PATH}"
        done
    else
        MISSING_DIR_ERROR="No directory /tmp/${FILENAME} found, probably a badly formatted zip file, please check the log and retry!"
        echo "${MISSING_DIR_ERROR}"
        zenity --error --text="${MISSING_DIR_ERROR}" --width=300 --height=100
        abort
    fi
}

# Internal function of install_files
# Creates backups
function install_system {
    SOURCE_FILEPATH="${1}"
    SOURCE_PATH="$(dirname ${1})"
    SOURCE_FILENAME="${1##*/}"
    DESTINATION_PATH="${2}"
    DESTINATION_FILEPATH="${DESTINATION_PATH}/${SOURCE_FILENAME}"
    echo "SOURCE_PATH: $SOURCE_PATH"
    echo "SOURCE_FILEPATH: $SOURCE_FILEPATH"
    echo "SOURCE_FILENAME: $SOURCE_FILENAME"
    echo "DESTINATION_PATH: $DESTINATION_PATH"
    echo "DESTINATION_FILEPATH: $DESTINATION_FILEPATH"

    if [ -f "${DESTINATION_FILEPATH}" ]; then
        BACKUP_FILES_COUNT=$(find "${DESTINATION_PATH}" -type f -name *"${SOURCE_FILENAME}".backup.* | wc -l)
        BACKUP_FILE="${DESTINATION_FILEPATH}.backup.${BACKUP_FILES_COUNT}"

        echo "Creating backup file at ${BACKUP_FILE}."
        echo "${cyan}Replacing ${DESTINATION_FILEPATH}.${reset}"
        sudo mv "${DESTINATION_FILEPATH}" "${BACKUP_FILE}"
        # If backup fails, abort
        test $? -eq 0 || abort
    else
        echo "${green}Installing ${DESTINATION_FILEPATH}.${reset}"
        # Create install directory if it doesn't exist
        sudo mkdir -p "${DESTINATION_PATH}"
        # If creating dirs fails, abort
        test $? -eq 0 || abort
    fi
    # Preserves permissions (2/3)
    sudo cp -p "${SOURCE_FILEPATH}" "${DESTINATION_FILEPATH}"
    # If installing files fails, abort
    test $? -eq 0 || abort
    # Restores permissions (3/3)
    # https://unix.stackexchange.com/a/718192
    sudo mtree -cp "${SOURCE_PATH}" | sudo mtree -Utp "${DESTINATION_PATH}"
    # If restoring perms fails, abort
    test $? -eq 0 || abort
}

# Overloading function
# Needs $FILENAME as $1
function do_install {
    FILENAME="${1}"
    install_files "${FILENAME}"
    general_update
    deps_update
    services_update
    openauto_update
}

# Needs USBPATH as $1!
function extract_install {
    USBPATH="${1}"
    echo "Starting ZIP extraction..."
    # maxdepth is needed so find can't look too deep into USBPATH, only one directory down
    ZIPS=$(find "${USBPATH}"/* -maxdepth 0 -type f -name "*.zip")
    if [[ -z ${ZIPS} ]] ; then
        NO_ZIPS_ERROR="No Zip files found in the USB media. Please retry."
        zenity --error --text="${NO_ZIPS_ERROR}" --width=300 --height=100
        abort
    else
        for ZIP in ${ZIPS}; do
            FILE="${ZIP##*/}"
            FILENAME="${FILE%.zip}"
            echo "Found: ${yellow}${FILE}${reset}"

            echo "Copying to /tmp..."
            sudo cp "${ZIP}" /tmp/
            # Preserves permissions on extract (1/3), needs to be sudo
            sudo unzip -X -o /tmp/"${FILE}" -d /tmp/
            if [ -f "/tmp/${FILENAME}/${FILENAME}.sh" ]; then
                echo "${green}Found: "${FILENAME}".sh, including it...${reset}"
                . /tmp/"${FILENAME}"/"${FILENAME}".sh
                if [ $? -ne 0 ]; then
                    SCRIPT_LOADING_ERROR="Script loading failed, probably a badly formatted file. Please check the log and fix the script!"
                    zenity --error --text="${SCRIPT_LOADING_ERROR}" --width=300 --height=100
                    abort
                fi
            elif [ -f "/tmp/openauto_update_package/update.sh" ]; then
                 echo "${yellow}OPENAUTO System update found!{$reset}"
                 echo "${cyan}OAP update queued!{$reset}"
                 oap_update=true
            else
                echo "${yellow}No update.sh found, copy-only mode engaged${reset}"
            fi
            # Install everything
            do_install "${FILENAME}"
        done
    fi
}

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

    extract_install "${USBPATH}"

    echo "${green}Update finished.${reset}"

    clean_log

    zenity --question --title="Update Finished!" --icon-name=info --text="It's suggested to reboot the system. Reboot now?" --width=300 --height=100
    if [ $? = 0 ]; then
        sudo reboot
    fi
}

function abort {
    echo "Update aborted."
    clean_log
    exit 1
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
        x-terminal-emulator -e bash -c "${SCRIPT} \"terminal\" \"${USBPATH}\" 2>&1 | tee -a ${LOGFILE}"
    else
        abort
    fi
else
    echo "No "${UPDATETRIGGER}" found. Aborting."
fi
