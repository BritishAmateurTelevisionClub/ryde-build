#!/bin/bash

# Created by davecrump 20200714 for Ryde on Buster Raspios
# Updated for version 202110120

echo
echo "----------------------------------------"
echo "----- Updating Ryde Receiver System-----"
echo "----------------------------------------"
echo

# Stop the receiver to allow the update
sudo killall python3 >/dev/null 2>/dev/null
sleep 0.3
if pgrep -x "python3" >/dev/null
then
  sudo killall -9 python3 >/dev/null 2>/dev/null
fi

## Check which update to load
GIT_SRC_FILE=".ryde_gitsrc"
if [ -e ${GIT_SRC_FILE} ]; then
  GIT_SRC=$(</home/pi/${GIT_SRC_FILE})
else
  GIT_SRC="BritishAmateurTelevisionClub"
fi

## If previous version was Dev (davecrump), load production by default
if [ "$GIT_SRC" == "davecrump" ]; then
  GIT_SRC="BritishAmateurTelevisionClub"
fi

if [ "$1" == "-d" ]; then
  echo "Overriding to update to latest development version"
  GIT_SRC="davecrump"
fi

if [ "$GIT_SRC" == "BritishAmateurTelevisionClub" ]; then
  echo "Updating to the latest Production Ryde build";
elif [ "$GIT_SRC" == "davecrump" ]; then
  echo "Updating to the latest development Ryde build";
else
  echo "Updating to the latest ${GIT_SRC} development Ryde build";
fi

echo
echo "-----------------------------------------"
echo "----- Noting Previous Configuration -----"
echo "-----------------------------------------"
echo

cd /home/pi

PATHUBACKUP="/home/pi/user_backups"
mkdir "$PATHUBACKUP" >/dev/null 2>/dev/null  

# Note previous version number
cp -f -r /home/pi/ryde-build/installed_version.txt "$PATHUBACKUP"/prev_installed_version.txt

# Make a safe copy of the Config file in "$PATHUBACKUP" to restore at the end

cp -f -r /home/pi/ryde/config.yaml "$PATHUBACKUP"/config.yaml >/dev/null 2>/dev/null

# Capture the RC protocol in the rx.sh file:
cp -f -r /home/pi/ryde-build/rx.sh "$PATHUBACKUP"/rx.sh

# And the dvb-t config
cp -f -r /home/pi/dvbt/dvb-t_config.txt "$PATHUBACKUP"/dvb-t_config.txt >/dev/null 2>/dev/null

# Check the user's audio output to re-apply it after the update.  HDMI is default.
AUDIO_JACK=HDMI
grep -q "^        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Headphones,DEV=0 '" \
  /home/pi/ryde/rydeplayer/player.py
if [ $? -eq 0 ]; then  #  RPi Jack currently selected
  AUDIO_JACK="RPi Jack"
else
  grep -q "^        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Device,DEV=0 '" \
    /home/pi/ryde/rydeplayer/player.py
  if [ $? -eq 0 ]; then  #  USB Dongle currently selected
    AUDIO_JACK=USB
  fi
fi


echo
echo "-------------------------------------------------"
echo "----- Updating the System Software Packages -----"
echo "-------------------------------------------------"
echo

# Download and install the VLC apt Preferences File 202212090
cd /home/pi
wget https://github.com/${GIT_SRC}/ryde-build/raw/master/configs/vlc
sudo cp vlc /etc/apt/preferences.d/vlc

sudo apt -y remove vlc* libvlc*


sudo dpkg --configure -a                          # Make sure that all the packages are properly configured
sudo apt-get clean                                # Clean up the old archived packages
sudo apt-get update --allow-releaseinfo-change    # Update the package list

# --------- Remove any previous hold on VLC -----------------

if apt-mark showhold | grep -q 'vlc'; then
  sudo apt-mark unhold vlc
  sudo apt-mark unhold libvlc-bin
  sudo apt-mark unhold libvlc5
  sudo apt-mark unhold libvlccore9
  sudo apt-mark unhold vlc-bin
  sudo apt-mark unhold vlc-data
  sudo apt-mark unhold vlc-plugin-base
  sudo apt-mark unhold vlc-plugin-qt
  sudo apt-mark unhold vlc-plugin-video-output
  sudo apt-mark unhold vlc-l10n
  sudo apt-mark unhold vlc-plugin-notify
  sudo apt-mark unhold vlc-plugin-samba
  sudo apt-mark unhold vlc-plugin-skins2
  sudo apt-mark unhold vlc-plugin-video-splitter
  sudo apt-mark unhold vlc-plugin-visualization
fi

# --------- Update Packages ------

sudo apt-get -y dist-upgrade # Upgrade all the installed packages to their latest version

echo
echo "Checking for EEPROM Update"
echo

sudo rpi-eeprom-update -a                            # Update will be installed on reboot if required

# --------- Install new packages as Required ---------

sudo apt-get -y install vlc                       # May have been removed earlier
sudo apt-get -y install python3-vlc               # May also have been removed
sudo apt -y remove vlc-data                       # Old dependencies seem to hang around
sudo apt-get -y install vlc-plugin-base           # And re-install
sudo apt-get -y install python3-gpiozero          # for GPIOs
sudo apt-get -y install libfftw3-dev libjpeg-dev  # for DVB-T
sudo apt-get -y install fbi netcat imagemagick    # for DVB-T
sudo apt-get -y install python3-urwid             # for Ryde Utils
sudo apt-get -y install python3-librtmp           # for Stream RX
sudo apt-get -y install vlc-plugin-base           # for Stream RX

pip3 uninstall -y pyftdi                          # uninstall old version of pyftdi
pip3 install pyftdi==0.53.1                       # and install new version

if [ ! -f "/usr/lib/libwiringPi.so" ]; then       # Need to install WiringPi
  echo "Installing WiringPi"
  cd /tmp
  wget https://project-downloads.drogon.net/wiringpi-latest.deb
  sudo dpkg -i wiringpi-latest.deb
  cd /home/pi
fi

# --------- Overwrite and compile all the software components -----

# Download the previously selected version of Ryde Build
echo
echo "----------------------------------------"
echo "----- Updating Ryde Build Utilities-----"
echo "----------------------------------------"
echo
rm -rf /home/pi/ryde-build
wget https://github.com/${GIT_SRC}/ryde-build/archive/master.zip
unzip -o master.zip
mv ryde-build-master ryde-build
rm master.zip
cd /home/pi

# Build the LongMynd version packaged with ryde-build
echo
echo "------------------------------------------"
echo "----- Updating the LongMynd Receiver -----"
echo "------------------------------------------"
echo
rm -rf /home/pi/longmynd
cp -r ryde-build/longmynd/ longmynd/
cd longmynd
make

# Check the minitiouner.rules file and update if required
grep -q "ba2c" /etc/udev/rules.d/minitiouner.rules
if [ $? -ne 0 ]; then  #  file is not there or has the wrong entry for PicoTuner
  sudo cp minitiouner.rules /etc/udev/rules.d/
fi
cd /home/pi

# Download and compile pyDispmanx
echo
echo "--------------------------------"
echo "----- Updating pyDispmanx -----"
echo "--------------------------------"
echo

wget https://github.com/eclispe/pyDispmanx/archive/master.zip
unzip -o master.zip
rm -rf pydispmanx
mv pyDispmanx-master pydispmanx
rm master.zip
cd pydispmanx
python3 setup.py build_ext --inplace

cd /home/pi

# Download the previously selected version of Ryde Player
echo
echo "--------------------------------"
echo "----- Updating Ryde Player -----"
echo "--------------------------------"
echo
rm -rf /home/pi/ryde
wget https://github.com/${GIT_SRC}/rydeplayer/archive/master.zip
unzip -o master.zip
mv rydeplayer-master ryde
rm master.zip
cd /home/pi/ryde

cp /home/pi/pydispmanx/pydispmanx.cpython-37m-arm-linux-gnueabihf.so pydispmanx.cpython-37m-arm-linux-gnueabihf.so

cd /home/pi

# Download and overwrite the latest remote control definitions and images
echo
echo "----------------------------------------------"
echo "----- Downloading Remote Control Configs -----"
echo "----------------------------------------------"
echo

rm -rf /home/pi/RydeHandsets/definitions
rm -rf /home/pi/RydeHandsets/images

git clone -b definitions https://github.com/${GIT_SRC}/RydeHandsets.git RydeHandsets/definitions
git clone -b images https://github.com/${GIT_SRC}/RydeHandsets.git RydeHandsets/images

# Check that Operating System Changes have been applied
echo
echo "--------------------------------------------"
echo "----- Configuring the Operating System -----"
echo "--------------------------------------------"
echo

# Check that the RPi Audio Jack volume is being set
grep -q "amixer set Headphone" ~/.bashrc
if [ $? -ne 0 ]; then  #  Not being set, so enter the code
  echo  >> ~/.bashrc
  echo "# Set RPi Audio Jack volume" >> ~/.bashrc
  echo  "amixer set Headphone 0db >/dev/null 2>/dev/null" >> ~/.bashrc
fi

# If not already done, increase GPU memory so that it copes with 4k displays
# First check if "#gpu_mem=128" is in  /boot/config.txt
grep -q "#gpu_mem=128" /boot/config.txt
if [ $? -ne 0 ]; then  #  "#gpu_mem=128" is not there, so check if "gpu_mem=128" is there
  grep -q "gpu_mem=128" /boot/config.txt
  if [ $? -ne 0 ]; then  # "gpu_mem=128" is not there, so append the commented statement
    sudo bash -c 'echo " " >> /boot/config.txt '
    sudo bash -c 'echo "# Increase GPU memory for 4k displays" >> /boot/config.txt '
    sudo bash -c 'echo "gpu_mem=128" >> /boot/config.txt '
    sudo bash -c 'echo " " >> /boot/config.txt '
  fi
else  ## "#gpu_mem=128" is there, so amend it to read "gpu_mem=128"
  sudo sed -i 's/^#gpu_mem=128/gpu_mem=128/' /boot/config.txt 
fi

# If not already done, set the Composite Video Aspect Ratio to 4:3
grep -q "sdtv_aspect" /boot/config.txt
if [ $? -ne 0 ]; then  #  "sdtv_aspect" is not there so add it
  sudo bash -c 'echo -e "\n# Set the Composite Video Aspect Ratio. 1=4:3, 3=16:9" >> /boot/config.txt'
  sudo bash -c 'echo -e "sdtv_aspect=1\n" >> //boot/config.txt'
fi

# Amend /etc/fstab to create a tmpfs drive at ~/tmp for multiple writes (202101190)
if grep -q /home/pi/tmp /etc/fstab; then
  echo "tmpfs already requested"
else
  sudo sed -i '4itmpfs           /home/pi/tmp    tmpfs   defaults,noatime,nosuid,size=10m  0  0' /etc/fstab
fi

echo
echo "-------------------------------------------"
echo "----- Rebuilding the Interim DVB-T RX -----"
echo "-------------------------------------------"

sudo rm -rf /home/pi/dvbt/ >/dev/null 2>/dev/null
cp -r /home/pi/ryde-build/configs/dvbt /home/pi/dvbt
cd /home/pi/dvbt
make
cd /home/pi

echo
echo "-----------------------------------"
echo "----- Updating the Ryde Utils -----"
echo "-----------------------------------"
echo

wget https://github.com/eclispe/ryde-utils/archive/master.zip
unzip -o master.zip
rm -rf ryde-utils
mv ryde-utils-master ryde-utils
rm master.zip

echo
echo "---------------------------------------------"
echo "----- Restoring the User's Config Files -----"
echo "---------------------------------------------"


grep -q "CombiTunerExpress" "$PATHUBACKUP"/config.yaml
if [ $? == 0 ]; then # User's config file is latest version, so simply copy back
  cp -f -r "$PATHUBACKUP"/config.yaml /home/pi/ryde/config.yaml >/dev/null 2>/dev/null
else # User's config file needs updating, so copy master and reset remote control

  cp /home/pi/ryde-build/config.yaml /home/pi/ryde/config.yaml

  # Check for previous remote type
  grep -q "virgin" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "virgin" 1
    sed -i "/handsets:/{n;s/.*/        - virgin/}" /home/pi/ryde/config.yaml
  fi
  grep -q "nebula_usb" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "nebula_usb" 2
    sed -i "/handsets:/{n;s/.*/        - nebula_usb/}" /home/pi/ryde/config.yaml
  fi
  grep -q "hd-dvb-t2-s2-rx" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "hd-dvb-t2-s2-rx" 3
    sed -i "/handsets:/{n;s/.*/        - hd-dvb-t2-s2-rx/}" /home/pi/ryde/config.yaml
  fi
  grep -q "lg_tv_42" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "lg_tv_42" 4
    sed -i "/handsets:/{n;s/.*/        - lg_tv_42/}" /home/pi/ryde/config.yaml
  fi
  grep -q "lg_bluray-BP530" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "lg_bluray-BP530" 5
    sed -i "/handsets:/{n;s/.*/        - lg_bluray-BP530/}" /home/pi/ryde/config.yaml
  fi
  grep -q "lg_bluray-BP620" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "lg_bluray-BP620" 6
    sed -i "/handsets:/{n;s/.*/        - lg_bluray-BP620/}" /home/pi/ryde/config.yaml
  fi
  grep -q "samsung_32" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "samsung_32" 7
    sed -i "/handsets:/{n;s/.*/        - samsung_32/}" /home/pi/ryde/config.yaml
  fi
  grep -q "elekta_tv" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "elekta_tv" 8
    sed -i "/handsets:/{n;s/.*/        - elekta_tv/}" /home/pi/ryde/config.yaml
  fi
  grep -q "wdtv_live" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "wdtv_live" 9
    sed -i "/handsets:/{n;s/.*/        - wdtv_live/}" /home/pi/ryde/config.yaml
  fi
  grep -q "hauppauge_mvp" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "hauppauge_mvp" 10
    sed -i "/handsets:/{n;s/.*/        - hauppauge_mvp/}" /home/pi/ryde/config.yaml
  fi
  grep -q "hauppauge_usb" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "hauppauge_usb" 11
    sed -i "/handsets:/{n;s/.*/        - hauppauge_usb/}" /home/pi/ryde/config.yaml
  fi
  grep -q "ts1_sat" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "ts1_sat" 12
    sed -i "/handsets:/{n;s/.*/        - ts1_sat/}" /home/pi/ryde/config.yaml
  fi
  grep -q "ts3500_sat" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "ts3500_sat" 13
    sed -i "/handsets:/{n;s/.*/        - ts3500_sat/}" /home/pi/ryde/config.yaml
  fi
  grep -q "f2100_uni" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "f2100_uni" 14
    sed -i "/handsets:/{n;s/.*/        - f2100_uni/}" /home/pi/ryde/config.yaml
  fi
  grep -q "sf8008" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "sf8008" 15
    sed -i "/handsets:/{n;s/.*/        - sf8008/}" /home/pi/ryde/config.yaml
  fi
  grep -q "freesat_v7" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "freesat_v7" 16
    sed -i "/handsets:/{n;s/.*/        - freesat_v7/}" /home/pi/ryde/config.yaml
  fi
  grep -q "rtl0" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "rtl0" 17
    sed -i "/handsets:/{n;s/.*/        - rtl0/}" /home/pi/ryde/config.yaml
  fi
  grep -q "avermediacard" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "avermediacard" 18
    sed -i "/handsets:/{n;s/.*/        - avermediacard/}" /home/pi/ryde/config.yaml
  fi
  grep -q "aeg_dvd" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "aeg_dvd" 19
    sed -i "/handsets:/{n;s/.*/        - aeg_dvd/}" /home/pi/ryde/config.yaml
  fi
  grep -q "g_rcu_023" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "g_rcu_023" 20
    sed -i "/handsets:/{n;s/.*/        - g_rcu_023/}" /home/pi/ryde/config.yaml
  fi
  grep -q "pheonix" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "pheonix" 21
    sed -i "/handsets:/{n;s/.*/        - pheonix/}" /home/pi/ryde/config.yaml
  fi
  grep -q "classic" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "classic" 22
    sed -i "/handsets:/{n;s/.*/        - classic/}" /home/pi/ryde/config.yaml
  fi
  grep -q "tesco_tv" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "tesco_tv" 23
    sed -i "/handsets:/{n;s/.*/        - tesco_tv/}" /home/pi/ryde/config.yaml
  fi
  grep -q "led_tv" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "led_tv" 24
    sed -i "/handsets:/{n;s/.*/        - led_tv/}" /home/pi/ryde/config.yaml
  fi
  grep -q "fortecstar" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "fortecstar" 25
    sed -i "/handsets:/{n;s/.*/        - fortecstar/}" /home/pi/ryde/config.yaml
  fi
  grep -q "cmtronic" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "cmtronic" 26
    sed -i "/handsets:/{n;s/.*/        - cmtronic/}" /home/pi/ryde/config.yaml
  fi
  grep -q "technotrendttc" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "technotrendttc" 27
    sed -i "/handsets:/{n;s/.*/        - technotrendttc/}" /home/pi/ryde/config.yaml
  fi
  grep -q "philipsrc4492" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "philipsrc4492" 28
    sed -i "/handsets:/{n;s/.*/        - philipsrc4492/}" /home/pi/ryde/config.yaml
  fi
  grep -q "mp3_player" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "mp3_player" 29
    sed -i "/handsets:/{n;s/.*/        - mp3_player/}" /home/pi/ryde/config.yaml
  fi
  grep -q "dreamboxurc39931" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "dreamboxurc39931" 30
    sed -i "/handsets:/{n;s/.*/        - dreamboxurc39931/}" /home/pi/ryde/config.yaml
  fi
  grep -q "humaxrmf04" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "humaxrmf04" 31
    sed -i "/handsets:/{n;s/.*/        - humaxrmf04/}" /home/pi/ryde/config.yaml
  fi
  grep -q "xtrendkt1252" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "xtrendkt1252" 32
    sed -i "/handsets:/{n;s/.*/        - xtrendkt1252/}" /home/pi/ryde/config.yaml
  fi
  grep -q "salora" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "salora" 33
    sed -i "/handsets:/{n;s/.*/        - salora/}" /home/pi/ryde/config.yaml
  fi
  grep -q "streamzap" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "streamzap" 34
    sed -i "/handsets:/{n;s/.*/        - streamzap/}" /home/pi/ryde/config.yaml
  fi
  grep -q "sky1" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "sky1" 35
    sed -i "/handsets:/{n;s/.*/        - sky1/}" /home/pi/ryde/config.yaml
  fi
  grep -q "tosh_ct_8541" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "tosh_ct_8541" 36
    sed -i "/handsets:/{n;s/.*/        - tosh_ct_8541/}" /home/pi/ryde/config.yaml
  fi
  grep -q "gtmedia" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "gtmedia" 37
    sed -i "/handsets:/{n;s/.*/        - gtmedia/}" /home/pi/ryde/config.yaml
  fi
  grep -q "strong5434" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "strong5434" 38
    sed -i "/handsets:/{n;s/.*/        - strong5434/}" /home/pi/ryde/config.yaml
  fi
  grep -q "oldvirgin" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "oldvirgin" 39
    sed -i "/handsets:/{n;s/.*/        - oldvirgin/}" /home/pi/ryde/config.yaml
  fi
  grep -q "scottdvd" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "scottdvd" 40
    sed -i "/handsets:/{n;s/.*/        - scottdvd/}" /home/pi/ryde/config.yaml
  fi
  grep -q "sagemstb" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "sagemstb" 41
    sed -i "/handsets:/{n;s/.*/        - sagemstb/}" /home/pi/ryde/config.yaml
  fi
  grep -q "altech_uec_vast_tv" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "altech_uec_vast_tv" 42
    sed -i "/handsets:/{n;s/.*/        - altech_uec_vast_tv/}" /home/pi/ryde/config.yaml
  fi
  grep -q "marantz_rtc002cd" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "marantz_rtc002cd" 43
    sed -i "/handsets:/{n;s/.*/        - marantz_rtc002cd/}" /home/pi/ryde/config.yaml
  fi
  grep -q "k0qit" "$PATHUBACKUP"/config.yaml
  if  [ $? == 0 ]; then   ## Amend new file for "k0qit" 43
    sed -i "/handsets:/{n;s/.*/        - k0qit/}" /home/pi/ryde/config.yaml
  fi
fi

# Restore the user's original audio output (Default is HDMI)
case "$AUDIO_JACK" in
  "RPi Jack")
    sed -i "/--alsa-audio-device/c\        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Headphones,DEV=0 '" \
      /home/pi/ryde/rydeplayer/player.py
  ;;
  "USB")
    sed -i "/--alsa-audio-device/c\        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Device,DEV=0 '" \
      /home/pi/ryde/rydeplayer/player.py
  ;;
esac

# Add RC Volume Control if needed for the update
rm /home/pi/ryde-build/configs/temp.yaml  >/dev/null 2>/dev/null
if ! grep -q "audio:" /home/pi/ryde/config.yaml; then

  # add audio to config.yaml
  awk '/debug:/{system("cat /home/pi/ryde-build/configs/audio.yaml");next}1' \
    /home/pi/ryde/config.yaml > /home/pi/ryde-build/configs/temp.yaml
  cp /home/pi/ryde-build/configs/temp.yaml /home/pi/ryde/config.yaml
  rm /home/pi/ryde-build/configs/temp.yaml

  # And the OSD:
  sed -i "/^        FREQ: null/a \        VOLUME: null" /home/pi/ryde/config.yaml
fi

# Add Band GPIOs if needed for the update
if ! grep -q "^    band:" /home/pi/ryde/config.yaml; then

  # add gpio bcm numbers to config.yaml
  awk '/osd:/{system("cat /home/pi/ryde-build/configs/bandgpio.yaml");next}1' \
    /home/pi/ryde/config.yaml > /home/pi/ryde-build/configs/temp.yaml
  cp /home/pi/ryde-build/configs/temp.yaml /home/pi/ryde/config.yaml
  rm /home/pi/ryde-build/configs/temp.yaml
fi

# Add POWER LEVEL to the OSD if needed for the update
if ! grep -q "POWERLEVEL:" /home/pi/ryde/config.yaml; then
  sed -i "/^        REPORT: null/a \        POWERLEVEL: null" /home/pi/ryde/config.yaml
fi

# Add Stream RX features to config.yaml if needed for the update
if ! grep -q "RTMPSTREAM" /home/pi/ryde/config.yaml; then
  sed -i "/^presets:/i \    BATC Streamer: &stream"        /home/pi/ryde/config.yaml
  sed -i "/^presets:/i \        source: RTMPSTREAM"        /home/pi/ryde/config.yaml
  sed -i "/^presets:/i \        domain: rtmp.batc.org.uk"  /home/pi/ryde/config.yaml
  sed -i "/^presets:/i \        rtmpapp: live"             /home/pi/ryde/config.yaml
  sed -i "/^presets:/i \        networkTimeout: 5"         /home/pi/ryde/config.yaml
  sed -i "/^presets:/i \        networkTimeoutInit: 25"    /home/pi/ryde/config.yaml
  sed -i "/^presets:/i \        gpioid: 0\\n"              /home/pi/ryde/config.yaml

  sed -i "/^default:/i \    GB3HV Stream: &presethv"       /home/pi/ryde/config.yaml
  sed -i "/^default:/i \        band: *stream"             /home/pi/ryde/config.yaml
  sed -i "/^default:/i \        streamname: gb3hv"         /home/pi/ryde/config.yaml
  sed -i "/^default:/i \    GB3JV Stream: &presetjv"       /home/pi/ryde/config.yaml
  sed -i "/^default:/i \        band: *stream"             /home/pi/ryde/config.yaml
  sed -i "/^default:/i \        streamname: gb3jv"         /home/pi/ryde/config.yaml
  sed -i "/^default:/i \    GB3KM Stream: &presetkm"       /home/pi/ryde/config.yaml
  sed -i "/^default:/i \        band: *stream"             /home/pi/ryde/config.yaml
  sed -i "/^default:/i \        streamname: gb3km"         /home/pi/ryde/config.yaml
  sed -i "/^default:/i \    GB3SQ Stream: &presetsq"       /home/pi/ryde/config.yaml
  sed -i "/^default:/i \        band: *stream"             /home/pi/ryde/config.yaml
  sed -i "/^default:/i \        streamname: gb3sq\\n"      /home/pi/ryde/config.yaml

  sed -i "/^shutdownBehavior:/i \watchdog:"                /home/pi/ryde/config.yaml
  sed -i "/^shutdownBehavior:/i \    minRestartTime: 0.1"  /home/pi/ryde/config.yaml
  sed -i "/^shutdownBehavior:/i \    maxRestartTime: 300"  /home/pi/ryde/config.yaml
  sed -i "/^shutdownBehavior:/i \    backoffRate: 2\\n"    /home/pi/ryde/config.yaml
fi

# Add Watchdog service features to config.yaml if needed for the update
if ! grep -q "watchdogService:" /home/pi/ryde/config.yaml; then
  echo >> /home/pi/ryde/config.yaml
  echo "watchdogService:" >> /home/pi/ryde/config.yaml
  echo "    serviceInterval: 1" >> /home/pi/ryde/config.yaml
  echo "    pidPath: \"/home/pi/tmp/rydePlayer.pid\"" >> /home/pi/ryde/config.yaml
fi

cp -f -r "$PATHUBACKUP"/dvb-t_config.txt /home/pi/dvbt/dvb-t_config.txt >/dev/null 2>/dev/null

# Add new alias if needed for the update
if ! grep -q "alias dryde" /home/pi/.bash_aliases; then
  echo "alias dryde='/home/pi/ryde-build/debug_rx.sh'" >> /home/pi/.bash_aliases
fi


# Record the version numbers

cp /home/pi/ryde-build/latest_version.txt /home/pi/ryde-build/installed_version.txt
cp -f -r "$PATHUBACKUP"/prev_installed_version.txt /home/pi/ryde-build/prev_installed_version.txt
rm -rf "$PATHUBACKUP"

# Save (overwrite) the git source used
echo "${GIT_SRC}" > /home/pi/${GIT_SRC_FILE}

echo
echo "--------------------------"
echo "----- Rebooting Ryde -----"
echo "--------------------------"
echo

sudo shutdown -r now

exit




