#!/bin/bash
# by KreAch3R 2021
# Automatically called from udev when a USB is plugged.
# /usr/local/bin/navipi_usb_loader.sh runs this script.
# from /etc/udev/rules.d/99-navipi_usb_update.rules

UPDATETRIGGER="navipi.update"

function general_update { :; }

function locate_usb {
    echo "Locating \"UPDATE\" USB storage media..."
    USBLIST=( $(find "/media/pi"/* -name "${UPDATETRIGGER}" -printf '%h\n') )
    if [ "${#USBLIST[@]}" -eq 1 ]; then
        USBPATH="${USBLIST[0]}"
        echo "Found: ${USBPATH}"
    else
        if [ "${#USBLIST[@]}" -gt 1 ]; then
            echo "Multiple USB devices with "${UPDATETRIGGER}" found. Please re-try."
        else
            echo "Couldn't find "${UPDATETRIGGER}" on any USB device. Please re-try."
        fi
        exit 1
    fi
}

function zip_extract {
    echo "Starting ZIP extraction..."
    for ZIP in $(find "${USBPATH}"/* -type f -name "*.zip"); do
        FILE="${ZIP##*/}"
        FILENAME="${FILE%.zip}"
        echo "Found: ${FILE}"

        echo "Copying to /tmp..."
        sudo cp "${ZIP}" /tmp/
        sudo unzip -o /tmp/"${FILE}" -d /tmp/
        if [ -f "/tmp/${FILENAME}/${FILENAME}.sh" ]; then
            echo "Found: "${FILENAME}".sh, including it..."
            . /tmp/"${FILENAME}"/"${FILENAME}".sh
        else
            echo "No update.sh found, copy-only mode engaged"
        fi
    done
}

function deps_update { :; }

function install_files {
    for FILEPATH in $(cd "/tmp/${FILENAME}" && find * -mindepth 2 -type f); do
        SOURCE_FILEPATH="/tmp/${FILENAME}/${FILEPATH}"
        DESTINATION_PATH="/${FILEPATH%/*}"
        install_system "${SOURCE_FILEPATH}" "${DESTINATION_PATH}"
    done
}

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
        echo "Replacing ${DESTINATION_FILEPATH}."
        sudo mv "${DESTINATION_FILEPATH}" "${BACKUP_FILE}"
    else
         echo "Installing ${DESTINATION_FILEPATH}."
    fi
    sudo cp -p "${SOURCE_FILEPATH}" "${DESTINATION_FILEPATH}"
}

function services_update { :; }

###################################################

echo "NaviPi update script."

echo "Killing OpenAuto Pro application."
pkill autoapp

general_update

locate_usb

zip_extract

deps_update

install_files

services_update

echo "Update done. Its is required to reboot the system. Reboot now."
