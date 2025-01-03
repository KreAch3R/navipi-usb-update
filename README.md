# NaviPi USB update

Update your car PRI solution (mine is named "NaviPi", hence the name) automagically just by plugging in any USB stick with the installation files zipped up in the same directory structure as the original installation. Specific installation commands can be run as well in different points of the install.

<a href="https://www.paypal.com/donate/?business=R9V8AAFPNV684&no_recurring=0&currency_code=EUR">
<img src="https://raw.githubusercontent.com/stefan-niedermann/paypal-donate-button/master/paypal-donate-button.png" alt="Donate with PayPal" width="300">
</a>

# Requirements
* root/sudo
* The scripts need to be manually installed the first time.
* Any USB storage media with any file system capable of holding zip files. Yes, that includes FAT32. Due to the zip mechanism, unix permissions are kept intact!
* A file named `navipi.update` in the root of the USB storage.
* Script output is saved in `~/Logs/navipi_update.log` (Script variable, in both `navipi_usb_loader.sh` and `navipi_usb_update.sh`). Change it at your heart's desire.

# Dependencies

```
sudo apt install at
sudo apt install at-spi2-core
```

# Installation

1. Copy files into the specific directories as in the git repo.
2. Reload the udev rules: `udevadm control --reload`
3. Install the `at` command
4. IMPORTANT: Create the log folder path `~/Logs` (or change it to something else and create that).

# ZIP Preparation

1. Create a root folder somewhere and inside it create the subdirectories of the installation relative to the / (root) folder of your RPI. E.g.
```
~/Downloads/ --> test_update/
               ----> usr/local/bin
               ----> etc/systemd/system
               ----> home/pi
               ----> test_update.sh
```

etc.

2. Specific instructions: Please study the format of the `navipi_usb_update.sh` script. There are functions that can be overloaded by a zip-included script named exactly the same as the zip and the root folder.

   Example: If your zip is named `daynightlocation_update.zip`, you need to place a `daynightlocation_update.sh` file inside the root of the zip.      
**Caution**: the zip needs to have a root folder with the same name as well (check the screenshot below):
<img src="screenshots/dir-structure.png?raw=true">

  **Overloading functions** (and examples):
  1. `general_update`
  2. `deps_update`
  3. `services_update`

  ZIP script example:
```
#!/bin/bash
# NaviPi update script by KreAch3R

function general_update {
    sudo apt-get update
    sudo apt-get upgrade -y
    sudo apt-get dist-upgrade -y
}

function deps_update {
    echo "Installing required software."
    # Include here all the necessary dependencies
    sudo apt-get install libgeos-dev
    pip3 install astral
    pip3 install tzwhere
}

function services_update {
    echo "Enabling services"
    # Include here all the necessary changes to services
    sudo systemctl enable daynightlocation.timer
}
```

3. Zip up the root folder with the command:
```
zip -r test_update.zip test_update/
```

(Again, check screenshot for the correct structure.)

4. Place the zip inside the USB storage, then create a file `navipi.update` (again, hardcoded, rename it inside `navipi_usb_update.sh`) in the root folder of the USB.

5. Insert the USB and check the magic!

[![NaviPi Pluggable USB update (RPI)](http://i.ytimg.com/vi/uOoGoRgWOGo/hqdefault.jpg)](https://www.youtube.com/watch?v=uOoGoRgWOGo "NaviPi Pluggable USB update (RPI)")


