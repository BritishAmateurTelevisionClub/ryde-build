#!/bin/bash

# Ryde Menu Application

##########################YAML PARSER ####################
function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|,$s\]$s\$|]|" \
        -e ":1;s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1  - \4|;t1" \
        -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1  - \3|;p" $1 | \
   sed -ne "s|,$s}$s\$|}|" \
        -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1  \3: \4|;t1" \
        -e    "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1  \2|;p" | \
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" | \
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
      if(length($2)== 0){  vname[indent]= ++idx[indent] };
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, vname[indent], $3);
      }
   }'
}
#########################################################


do_update()
{
  /home/pi/ryde-build/check_for_update.sh
}

do_info()
{
  /home/pi/ryde-build/display_info.sh
}


do_Set_RC_Type()
{
  RC_FILE=""

  menuchoice=$(whiptail --title "Set Remote Control Model" --menu "Select Choice" 30 78 20 \
    "1 Virgin" "Virgin Media"  \
    "2 Nebula" "Nebula DigiTV DVB-T USB Receiver" \
    "3 DVB-T2-S2" "eBay DVB-T2-S2 Combo with 12v in " \
    "4 LG TV " "LG 42 inch TV " \
    "5 LG Blu-Ray 1" "LG Blu-Ray Disc Player BP-530R " \
    "6 LG Blu-Ray 2" "LG Blu-Ray Disc Player BP-620R " \
    "7 Samsung TV" "Samsung 32 inch TV" \
    "8 Elekta TV" "Elekta Bravo 19 inch TV" \
    "9 WDTV Live" "WDTV Live Media Player" \
    "10 Hauppauge 1" "Hauppauge MediaMVP Network Media Player" \
    "11 Hauppauge 2" "Hauppauge USB PVR Ex-digilite" \
    "12 TS-1 Sat" "Technosat TS-1 Satellite Receiver" \
    "13 TS-3500" "Technosat TS-3500 Satellite Receiver" \
    "14 F-2100 Uni" "Digi-Wav 2 Pound F2100 Universal Remote" \
    "15 SF8008" "Octagon SF8008 Sat RX Remote" \
    "16 Freesat V7" "Freesat V7 Combo - Some keys changed" \
    "17 RTL-SDR" "RTL-SDR Basic Remote" \
    "18 Avermedia" "AverMedia PC Card Tuner" \
    "19 Exit" "Exit without changing remote control model" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        1\ *) RC_FILE="virgin" ;;
        2\ *) RC_FILE="nebula_usb" ;;
        3\ *) RC_FILE="hd-dvb-t2-s2-rx" ;;
        4\ *) RC_FILE="lg_tv_42" ;;
        5\ *) RC_FILE="lg_bluray-BP530" ;;
        6\ *) RC_FILE="lg_bluray-BP620" ;;
        7\ *) RC_FILE="samsung_32" ;;
        8\ *) RC_FILE="elekta_tv" ;;
        9\ *) RC_FILE="wdtv_live" ;;
        10\ *) RC_FILE="hauppauge_mvp" ;;
        11\ *) RC_FILE="hauppauge_usb" ;;
        12\ *) RC_FILE="ts1_sat" ;;
        13\ *) RC_FILE="ts3500_sat" ;;
        14\ *) RC_FILE="f2100_uni" ;;
        15\ *) RC_FILE="sf8008" ;;
        16\ *) RC_FILE="freesat_v7" ;;
        17\ *) RC_FILE="rtl0" ;;
        18\ *) RC_FILE="avermediacard" ;;
        19\ *) RC_FILE="exit" ;;
    esac

  if [ "$RC_FILE" != "exit" ]; then # Amend the config file

    RC_FILE="        - ${RC_FILE}"
    sed -i "/handsets:/{n;s/.*/$RC_FILE/}" /home/pi/ryde/config.yaml

    # Load the requested file
    #cp /home/pi/RydeHandsets/definitions/"$RC_FILE" /home/pi/ryde/handset.yaml

    # Set the requested protocol setting
    #sudo ir-keytable -p $PROTOCOL >/dev/null 2>/dev/null

    # And change it for the future
    #sed -i "/ir-keytable/c\sudo ir-keytable -p $PROTOCOL >/dev/null 2>/dev/null" /home/pi/ryde-build/rx.sh
  fi
}

do_Set_Freq()
{
  DEFAULT_FREQ=$(whiptail --inputbox "Enter the new Start-up frequency in kHz" 8 78 $DEFAULT_FREQ --title "Frequency Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    sed -i "/freq:/c\    freq: $DEFAULT_FREQ" /home/pi/ryde/config.yaml
  fi
}


do_Set_SR()
{
  DEFAULT_SR=$(whiptail --inputbox "Enter the new Start-up SR in kS" 8 78 $DEFAULT_SR --title "Symbol Rate Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    sed -i "/sr:/c\    sr:   $DEFAULT_SR" /home/pi/ryde/config.yaml
  fi
}


do_Check_RC_Codes()
{
  sudo ir-keytable -p all >/dev/null 2>/dev/null
  reset
  echo "After CTRL-C, type menu to get back to the Menu System"
  echo
  ir-keytable -t
}


do_Reboot()
{
  sudo reboot now
}

do_Nothing()
{
  :
}

do_Norm_HDMI()
{
  # change #enable_tvout=1 or enable_tvout=1 to #enable_tvout=1

  # first check if "#enable_tvout=1" is in /boot/config.txt
  grep -q "#enable_tvout=1" /boot/config.txt
  if [ $? -ne 0 ]; then  #  "#enable_tvout=1" is not there, so check if "enable_tvout=1" is there
    grep -q "enable_tvout=1" /boot/config.txt
    if [ $? -eq 0 ]; then  # "enable_tvout=1" is there, so replace it with "#enable_tvout=1"
      sudo sed -i '/enable_tvout=1/c\#enable_tvout=1' /boot/config.txt  >/dev/null 2>/dev/null
    else                   # not there, so append the commented statement
      sudo bash -c 'echo " " >> /boot/config.txt '
      sudo bash -c 'echo "# Uncomment to enable Comp Vid output" >> /boot/config.txt '
      sudo bash -c 'echo "#enable_tvout=1" >> /boot/config.txt '
      sudo bash -c 'echo " " >> /boot/config.txt '
    fi
  fi

  # change #hdmi_safe=1 or hdmi_safe=1 to #hdmi_safe=1

  # first check if "#hdmi_safe=1" is in /boot/config.txt
  grep -q "#hdmi_safe=1" /boot/config.txt
  if [ $? -ne 0 ]; then  #  "#hdmi_safe=1" is not there, so check if "hdmi_safe=1" is there
    grep -q "hdmi_safe=1" /boot/config.txt
    if [ $? -eq 0 ]; then  # "hdmi_safe=1" is there, so replace it with "#hdmi_safe=1"
      sudo sed -i '/hdmi_safe=1/c\#hdmi_safe=1' /boot/config.txt  >/dev/null 2>/dev/null
    else                   # not there, so append the commented statement
      sudo bash -c 'echo " " >> /boot/config.txt '
      sudo bash -c 'echo "# uncomment if you get no picture on HDMI for a default safe mode" >> /boot/config.txt '
      sudo bash -c 'echo "#hdmi_safe=1" >> /boot/config.txt '
      sudo bash -c 'echo " " >> /boot/config.txt '
    fi
  fi
}



do_Safe_HDMI()
{
  # change #enable_tvout=1 or enable_tvout=1 to #enable_tvout=1

  # first check if "#enable_tvout=1" is in /boot/config.txt
  grep -q "#enable_tvout=1" /boot/config.txt
  if [ $? -ne 0 ]; then  #  "#enable_tvout=1" is not there, so check if "enable_tvout=1" is there
    grep -q "enable_tvout=1" /boot/config.txt
    if [ $? -eq 0 ]; then  # "enable_tvout=1" is there, so replace it with "#enable_tvout=1"
      sudo sed -i '/enable_tvout=1/c\#enable_tvout=1' /boot/config.txt  >/dev/null 2>/dev/null
    else                   # not there, so append the commented statement
      sudo bash -c 'echo " " >> /boot/config.txt '
      sudo bash -c 'echo "# Uncomment to enable Comp Vid output" >> /boot/config.txt '
      sudo bash -c 'echo "#enable_tvout=1" >> /boot/config.txt '
      sudo bash -c 'echo " " >> /boot/config.txt '
    fi
  fi

  # change #hdmi_safe=1 or hdmi_safe=1 to hdmi_safe=1

  # first check if "#hdmi_safe=1" is in /boot/config.txt
  grep -q "#hdmi_safe=1" /boot/config.txt
  if [ $? -eq 0 ]; then  #  "#hdmi_safe=1" is there, so change it to "hdmi_safe=1"
    sudo sed -i '/#hdmi_safe=1/c\hdmi_safe=1' /boot/config.txt  >/dev/null 2>/dev/null
  else                   # "#hdmi_safe=1" is not there so check "hdmi_safe=1" is there
    grep -q "hdmi_safe=1" /boot/config.txt
    if [ $? -ne 0 ]; then  # "hdmi_safe=1" is not there, so add it (else do nothing)
      sudo bash -c 'echo " " >> /boot/config.txt '
      sudo bash -c 'echo "# uncomment if you get no picture on HDMI for a default safe mode" >> /boot/config.txt '
      sudo bash -c 'echo "hdmi_safe=1" >> /boot/config.txt '
      sudo bash -c 'echo " " >> /boot/config.txt '
    fi
  fi
}


do_Comp_Vid_PAL()
{
  # change #hdmi_safe=1 or hdmi_safe=1 to #hdmi_safe=1

  # first check if "#hdmi_safe=1" is in /boot/config.txt
  grep -q "#hdmi_safe=1" /boot/config.txt
  if [ $? -ne 0 ]; then  #  "#hdmi_safe=1" is not there, so check if "hdmi_safe=1" is there
    grep -q "hdmi_safe=1" /boot/config.txt
    if [ $? -eq 0 ]; then  # "hdmi_safe=1" is there, so replace it with "#hdmi_safe=1"
      sudo sed -i '/hdmi_safe=1/c\#hdmi_safe=1' /boot/config.txt  >/dev/null 2>/dev/null
    else                   # not there, so append the commented statement
      sudo bash -c 'echo " " >> /boot/config.txt '
      sudo bash -c 'echo "# uncomment if you get no picture on HDMI for a default safe mode" >> /boot/config.txt '
      sudo bash -c 'echo "#hdmi_safe=1" >> /boot/config.txt '
      sudo bash -c 'echo " " >> /boot/config.txt '
    fi
  fi

  #change #sdtv_mode=1/2 or sdtv_mode=1/2 to sdtv_mode=2

  # first check if "#sdtv_mode=2" is in /boot/config.txt
  grep -q "#sdtv_mode=2" /boot/config.txt
  if [ $? -eq 0 ]; then  #  "#sdtv_mode=2" is there, so change it to "sdtv_mode=2"
    sudo sed -i '/#sdtv_mode=2/c\sdtv_mode=2' /boot/config.txt  >/dev/null 2>/dev/null
  else                   # "#sdtv_mode=2" is not there so check if "#sdtv_mode=1" is there
    grep -q "#sdtv_mode=1" /boot/config.txt
    if [ $? -eq 0 ]; then  #  "#sdtv_mode=1" is there, so change it to "sdtv_mode=2"
      sudo sed -i '/#sdtv_mode=1/c\sdtv_mode=2' /boot/config.txt  >/dev/null 2>/dev/null
    else                   # neither "#sdtv_mode=2" nor "#sdtv_mode=1" are there
      grep -q "sdtv_mode=1" /boot/config.txt  # so check if "sdtv_mode=1" is there
      if [ $? -eq 0 ]; then  #  "sdtv_mode=1" is there, so change it to "sdtv_mode=2"
        sudo sed -i '/sdtv_mode=1/c\sdtv_mode=2' /boot/config.txt  >/dev/null 2>/dev/null
      else       # check if "sdtv_mode=2" is there and add it if not
        grep -q "sdtv_mode=2" /boot/config.txt  
        if [ $? -ne 0 ]; then  # "sdtv_mode=2" is not there, so add it at the end (else do nothing)
          sudo bash -c 'echo " " >> /boot/config.txt '
          sudo bash -c 'echo "# uncomment for composite PAL" >> /boot/config.txt '
          sudo bash -c 'echo "sdtv_mode=2" >> /boot/config.txt '
          sudo bash -c 'echo " " >> /boot/config.txt '
        fi
      fi
    fi
  fi

  # change #enable_tvout=1 or enable_tvout=1 to enable_tvout=1 (Add if not present)

  # first check if "#enable_tvout=1" is in /boot/config.txt
  grep -q "#enable_tvout=1" /boot/config.txt
  if [ $? -eq 0 ]; then  # "#enable_tvout=1" is there, so replace it with "enable_tvout=1"
    sudo sed -i '/#enable_tvout=1/c\enable_tvout=1' /boot/config.txt  >/dev/null 2>/dev/null
  else                   # "#enable_tvout=1" is not there, so check for "enable_tvout=1"
    grep -q "enable_tvout=1" /boot/config.txt
    if [ $? -ne 0 ]; then  #  "enable_tvout=1" is not there, so add it at the end (else do nothing)
      sudo bash -c 'echo " " >> /boot/config.txt '
      sudo bash -c 'echo "# Uncomment to enable Comp Vid output" >> /boot/config.txt '
      sudo bash -c 'echo "enable_tvout=1" >> /boot/config.txt '
      sudo bash -c 'echo " " >> /boot/config.txt '
    fi
  fi
}

do_Comp_Vid_NTSC()
{
  # change #hdmi_safe=1 or hdmi_safe=1 to #hdmi_safe=1

  # first check if "#hdmi_safe=1" is in /boot/config.txt
  grep -q "#hdmi_safe=1" /boot/config.txt
  if [ $? -ne 0 ]; then  #  "#hdmi_safe=1" is not there, so check if "hdmi_safe=1" is there
    grep -q "hdmi_safe=1" /boot/config.txt
    if [ $? -eq 0 ]; then  # "hdmi_safe=1" is there, so replace it with "#hdmi_safe=1"
      sudo sed -i '/hdmi_safe=1/c\#hdmi_safe=1' /boot/config.txt  >/dev/null 2>/dev/null
    else                   # not there, so append the commented statement
      sudo bash -c 'echo " " >> /boot/config.txt '
      sudo bash -c 'echo "# uncomment if you get no picture on HDMI for a default safe mode" >> /boot/config.txt '
      sudo bash -c 'echo "#hdmi_safe=1" >> /boot/config.txt '
      sudo bash -c 'echo " " >> /boot/config.txt '
    fi
  fi

  #change #sdtv_mode=1/2 or sdtv_mode=1/2 to sdtv_mode=1

  # first check if "#sdtv_mode=1" is in /boot/config.txt
  grep -q "#sdtv_mode=1" /boot/config.txt
  if [ $? -eq 0 ]; then  #  "#sdtv_mode=1" is there, so change it to "sdtv_mode=1"
    sudo sed -i '/#sdtv_mode=1/c\sdtv_mode=1' /boot/config.txt  >/dev/null 2>/dev/null
  else                   # "#sdtv_mode=1" is not there so check if "#sdtv_mode=2" is there
    grep -q "#sdtv_mode=2" /boot/config.txt
    if [ $? -eq 0 ]; then  #  "#sdtv_mode=2" is there, so change it to "sdtv_mode=1"
      sudo sed -i '/#sdtv_mode=2/c\sdtv_mode=1' /boot/config.txt  >/dev/null 2>/dev/null
    else                   # neither "#sdtv_mode=1" nor "#sdtv_mode=2" are there
      grep -q "sdtv_mode=2" /boot/config.txt  # so check if "sdtv_mode=2" is there
      if [ $? -eq 0 ]; then  #  "sdtv_mode=2" is there, so change it to "sdtv_mode=1"
        sudo sed -i '/sdtv_mode=2/c\sdtv_mode=1' /boot/config.txt  >/dev/null 2>/dev/null
      else       # check if "sdtv_mode=1" is there and add it if not
        grep -q "sdtv_mode=1" /boot/config.txt  
        if [ $? -ne 0 ]; then  # "sdtv_mode=1" is not there, so add it at the end (else do nothing)
          sudo bash -c 'echo " " >> /boot/config.txt '
          sudo bash -c 'echo "# uncomment for composite PAL" >> /boot/config.txt '
          sudo bash -c 'echo "sdtv_mode=1" >> /boot/config.txt '
          sudo bash -c 'echo " " >> /boot/config.txt '
        fi
      fi
    fi
  fi

  # change #enable_tvout=1 or enable_tvout=1 to enable_tvout=1 (Add if not present)

  # first check if "#enable_tvout=1" is in /boot/config.txt
  grep -q "#enable_tvout=1" /boot/config.txt
  if [ $? -eq 0 ]; then  # "#enable_tvout=1" is there, so replace it with "enable_tvout=1"
    sudo sed -i '/#enable_tvout=1/c\enable_tvout=1' /boot/config.txt  >/dev/null 2>/dev/null
  else                   # "#enable_tvout=1" is not there, so check for "enable_tvout=1"
    grep -q "enable_tvout=1" /boot/config.txt
    if [ $? -ne 0 ]; then  #  "enable_tvout=1" is not there, so add it at the end (else do nothing)
      sudo bash -c 'echo " " >> /boot/config.txt '
      sudo bash -c 'echo "# Uncomment to enable Comp Vid output" >> /boot/config.txt '
      sudo bash -c 'echo "enable_tvout=1" >> /boot/config.txt '
      sudo bash -c 'echo " " >> /boot/config.txt '
    fi
  fi
}


do_video_change()
{
  menuchoice=$(whiptail --title "Video Output Menu" --menu "Select Choice" 16 78 10 \
    "1 Normal HDMI" "Recommended Mode"  \
    "2 HDMI Safe Mode" "Use for HDMI Troubleshooting" \
    "3 PAL Composite Video" "Use the RPi Video Output Jack" \
    "4 NTSC Composite Video" "Use the RPi Video Output Jack" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        1\ *) do_Norm_HDMI ;;
        2\ *) do_Safe_HDMI ;;
        3\ *) do_Comp_Vid_PAL ;;
        4\ *) do_Comp_Vid_NTSC ;;
    esac

  menuchoice=$(whiptail --title "Reboot Now?" --menu "Reboot to Apply Changes?" 16 78 10 \
    "1 Yes" "Immediate Reboot"  \
    "2 No" "Apply changes at next Reboot" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        1\ *) do_Reboot ;;
        2\ *) do_Nothing ;;
    esac
}

do_Shutdown()
{
  sudo shutdown now
}

do_Exit()
{
  exit
}


do_shutdown_menu()
{
menuchoice=$(whiptail --title "Shutdown Menu" --menu "Select Choice" 16 78 10 \
    "1 Shutdown now" "Immediate Shutdown"  \
    "2 Reboot now" "Immediate reboot" \
    "3 Exit to Linux" "Exit menu to Command Prompt" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        1\ *) do_Shutdown ;;
        2\ *) do_Reboot ;;
        3\ *) do_Exit ;;
    esac
}

do_stop()
{
  sudo killall python3 >/dev/null 2>/dev/null
  
  sleep 0.3
  if pgrep -x "python3" >/dev/null 2>/dev/null
  then
    sudo killall -9 python3 >/dev/null 2>/dev/null
  fi
}

do_receive()
{
  /home/pi/ryde-build/rx.sh &

  # Wait here receiving until user presses a key
  whiptail --title "Receiving on $DEFAULT_FREQ kHz at SR $DEFAULT_SR kS" --msgbox "Touch any key to stop receiving" 8 78
  do_stop
}

#on $DEFAULT_FREQ kHz at SR $DEFAULT_SR kS

#********************************************* MAIN MENU *********************************
#************************* Execution of Console Menu starts here *************************

status=0

# Stop the Receiver
do_stop

# Look up the default frequency and SR

# Read and trim the default frequency
DEFAULT_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'default__freq=')"
DEFAULT_FREQ="$(echo "$DEFAULT_FREQ_LINE" | sed 's/default__freq=\"//' | sed 's/\"//')"

# Read and trim the default SR
DEFAULT_SR_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'default__sr=')"
DEFAULT_SR="$(echo "$DEFAULT_SR_LINE" | sed 's/default__sr=\"//' | sed 's/\"//')"

# Loop round main menu
while [ "$status" -eq 0 ] 
  do

    # Display main menu

    menuchoice=$(whiptail --title "Ryde Main Menu" --menu "INFO" 16 82 10 \
	"0 Receive" "Start the Ryde Receiver on $DEFAULT_FREQ kHz at SR $DEFAULT_SR kS" \
        "1 Stop" "Stop the Ryde Receiver" \
	"2 Freq" "Set the start-up Receive Frequency" \
	"3 SR" "Set start-up Receive Symbol Rate" \
	"4 Video" "Select the Video Output Mode" \
	"5 Remote" "Select the Remote Control Type" \
	"6 IR Check" "View the IR Codes From a new Remote" \
	"7 Info" "Display System Info" \
	"8 Update" "Check for Update" \
	"9 Shutdown" "Reboot or Shutdown" \
 	3>&2 2>&1 1>&3)

        case "$menuchoice" in
	    0\ *) do_receive   ;;
            1\ *) do_stop   ;;
	    2\ *) do_Set_Freq ;;
   	    3\ *) do_Set_SR ;;
	    4\ *) do_video_change ;;
   	    5\ *) do_Set_RC_Type ;;
   	    6\ *) do_Check_RC_Codes ;;
	    7\ *) do_info ;;
	    8\ *) do_update ;;
	    9\ *) do_shutdown_menu ;;
               *)

        # Display exit message if user jumps out of menu
        whiptail --title "Exiting to Linux Prompt" --msgbox "To return to the menu system, type menu" 8 78

        # Set status to exit
        status=1

        # Sleep while user reads message, then exit
        sleep 1
      exit ;;
    esac
    exitstatus1=$status1
  done
exit