#!/bin/bash

# Ryde Menu Application

##########################YAML PARSER ####################
function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_.-]*' fs=$(echo @|tr @ '\034')
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

############ Function to Write to DVB-T Config File ###############

set_config_var() {
lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
if line:match("^#?%s*"..key.."=.*$") then
line=key.."="..value
made_change=true
end
print(line)
end
if not made_change then
print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}



############ Function to Read from DVB-T Config File ###############

get_config_var() {
lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
local val = line:match("^#?%s*"..key.."=(.*)$")
if (val ~= nil) then
print(val)
break
end
end
EOF
}

############ Function to Read value with - from Config File ###############

get-config_var() {
lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
local val = line:match("^#?%s*"..key.."=[+-]?(.*)$")
if (val ~= nil) then
print(val)
break
end
end
EOF
}

#########################################################

CONFIGDVBT="/home/pi/dvbt/dvb-t_config.txt"


do_dvbt_stop()
{
  echo shutdown | nc 127.0.0.1 1111 >/dev/null 2>/dev/null
  sleep 1

  sudo killall play_dvbt >/dev/null 2>/dev/null
}

do_dvbt_rx()
{
  /home/pi/dvbt/play_dvbt >/dev/null 2>/dev/null &

  # Wait here receiving until user presses a key
  whiptail --title "Receiving DVB-T Frequency: "$DVBT_FREQ" kHz BW: "$DVBT_BW" kHz" --msgbox "Touch any key to stop receiving" 8 78
  do_dvbt_stop
}

do_Set_dvbt_frequency()
{
  DVBT_FREQ=$(get_config_var freq $CONFIGDVBT)
  DVBT_FREQ=$(whiptail --inputbox "Set DVB-T Receive freq in kHz" 8 78 $DVBT_FREQ --title "DVB-T Receive Frequency" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    set_config_var freq "$DVBT_FREQ" $CONFIGDVBT
  fi
}

do_Set_dvbt_bandwidth()
{
  DVBT_BW=$(get_config_var bw $CONFIGDVBT)
  DVBT_BW=$(whiptail --inputbox "Set DVB-T Receive bandwidth in kHz" 8 78 $DVBT_BW --title "DVB-T Receive Bandwidth" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    set_config_var bw "$DVBT_BW" $CONFIGDVBT
  fi
}

do_Set_dvbt_channel()
{
  DVBT_CHAN=$(get_config_var chan $CONFIGDVBT)
  DVBT_CHAN=$(whiptail --inputbox "Set Stream Channel (0 for default)" 8 78 $DVBT_CHAN --title "DVB-T Display Channel" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    set_config_var chan "$DVBT_CHAN" $CONFIGDVBT
  fi
}

do_Set_dvbt_audio()
{
  DVBT_AUDIO=$(get_config_var audio $CONFIGDVBT)
  case "$DVBT_AUDIO" in
  hdmi)
    Radio1=ON
    Radio2=OFF
  ;;
  rpi)
    Radio1=OFF
    Radio2=ON
  esac

  DVBT_AUDIO=$(whiptail --title "Seect DVB-T Audio to HDMI or RPi Jack" --radiolist \
    "Select one using arrow keys and space bar" 20 78 8 \
    "hdmi" "Audio to the HDMI Output" $Radio1 \
    "rpi" "Audio to the RPi Audio Jack " $Radio2 \
    3>&2 2>&1 1>&3)

  if [ $? -eq 0 ]; then                     ## If the selection has changed
    set_config_var audio "$DVBT_AUDIO" $CONFIGDVBT
  fi
}

do_dvbt()
{
  DVBT_FREQ=$(get_config_var freq $CONFIGDVBT)
  DVBT_BW=$(get_config_var bw $CONFIGDVBT)
  DVBT_CHAN=$(get_config_var chan $CONFIGDVBT)
  DVBT_AUDIO=$(get_config_var audio $CONFIGDVBT)
  status=0
  while [ "$status" -eq 0 ] 
  do
    menuchoice=$(whiptail --title "Ryde DVB-T Receiver Menu" --menu "Select Choice and press enter:" 20 78 13 \
	"0 Receive" "Start the DVB-T Receiver" \
    "1 Stop" "Stop the DVB-T Receiver" \
    "2 Frequency" "Set the Receive Frequency "$DVBT_FREQ" kHz" \
    "3 Bandwidth" "Set the Receive Bandwidth "$DVBT_BW" kHz" \
    "4 Channel" "Set the Channel from the video stream ("$DVBT_CHAN")" \
    "5 Audio" "Set Audio Output, currently "$DVBT_AUDIO" " \
	"6 Main Menu" "Go back to the Main Menu" \
 	3>&2 2>&1 1>&3)

    case "$menuchoice" in
	  0\ *) do_dvbt_rx   ;;
      1\ *) do_dvbt_stop   ;;
      2\ *) do_Set_dvbt_frequency ;;
      3\ *) do_Set_dvbt_bandwidth ;;
      4\ *) do_Set_dvbt_channel ;;
      5\ *) do_Set_dvbt_audio ;;
	  6\ *) status=1 ;;
    esac
  done
  status=0
}

do_update()
{
  /home/pi/ryde-build/check_for_update.sh
}

do_keypad()
{
  /home/pi/ryde-build/rx.sh &

  cd /home/pi/ryde-utils
  python3 consolehandset.py -i
  cd /home/pi
  do_stop
}

do_ftdi()
{
  cd /home/pi/ryde-utils
  python3 ftdiconf.py -u
  cd /home/pi
}

do_info()
{
  /home/pi/ryde-build/display_info.sh
}

do_vlc()
{
  VLCPAR=""
  # First check if it is a comp vid display set to 16:9
  grep -q "^enable_tvout=1" /boot/config.txt
  if [ $? -eq 0 ]; then    # comp vid display
    grep -q "sdtv_aspect=3" /boot/config.txt
    if [ $? -eq 0 ]; then  #  "sdtv_aspect=3" 16:9
      VLCPAR="--monitor-par=4:3"
    fi
  fi

  cvlc -I rc --rc-host 127.0.0.1:1111 $VLCPAR rtmp://rtmp.batc.org.uk/live/"$STREAM" /dev/null 2>/dev/null & 

  # Wait here displaying the stream until user presses a key
  whiptail --title "Displaying "$STREAM" Stream" --msgbox "Touch any key to stop the stream display and return to the menu" 8 78

  echo shutdown | nc 127.0.0.1 1111
  sleep 0.5
  if  $(pgrep vlc >/dev/null)  ; then
    sleep 0.5
    sudo killall -9 vlc >/dev/null 2>/dev/null
  fi
}

do_custom_stream()
{
  STREAM=$(whiptail --inputbox "Enter Stream Name (lower Case)" 8 78 $STREAM --title "Stream Name" 3>&1 1>&2 2>&3)
}

do_stream_display()
{
  status=0
  while [ "$status" -eq 0 ] 
  do
    menuchoice=$(whiptail --title "BATC Stream Viewer Menu" --menu "Select Choice, ctrl-c to stop stream:" 20 78 10 \
	"0 GB3BH" "View GB3BH" \
    "1 GB3HV" "View GB3HV" \
    "2 GB3KM" "View GB3KM" \
    "3 GB3TV" "View GB3TV" \
    "4 GB3TZ" "View GB3TZ" \
    "5 GB3SQ" "View GB3SQ" \
    "6 GB3VL" "View GB3VL" \
    "7 GB3ZZ" "View GB3ZZ" \
    "8 Custom" "Set Custom Stream" \
	"9 Main Menu" "Go back to the Main Menu" \
 	3>&2 2>&1 1>&3)

    case "$menuchoice" in
	  0\ *) STREAM="gb3bh" ;;
      1\ *) STREAM="gb3hv" ;;
      2\ *) STREAM="gb3km" ;;
      3\ *) STREAM="gb3tv" ;;
      4\ *) STREAM="gb3tz" ;;
      5\ *) STREAM="gb3sq" ;;
      6\ *) STREAM="gb3vl" ;;
      7\ *) STREAM="gb3zz" ;;
      8\ *) do_custom_stream ;;
	  9\ *) status=1 ;;
    esac

    if [ $status -eq 0 ]; then
      do_vlc 
    fi
  done
  status=0
}

do_pydispmanx_test()
{
  reset
  printf "Circles should flash on display and text should look like this:\n\n" 
  printf "pygame 1.9.4.post1\n"
  printf "Hello from the pygame community. https://www.pygame.org/contribute.html\n"
  printf "(1920, 1080)\n"
  printf "(1, 1)\n"
  printf "29.270518356986372\n"
  printf "no surface\n"
  printf "no layer\n\n"
  printf "Your System Response:\n\n"
  cd /home/pi/pydispmanx
  python3 demo.py
  cd /home/pi
  printf "\nPress any key to return to the menu\n"
  read -n 1
}

do_cmd_line_ryde()
{
  reset
  cd /home/pi/ryde
  python3 -m rydeplayer /home/pi/ryde/config.yaml
  cd /home/pi
  printf "\nPress any key to return to the menu\n"
  read -n 1
}

do_utils()
{
  status=0
  while [ "$status" -eq 0 ] 
  do
    menuchoice=$(whiptail --title "Select Ryde Utility" --menu "Select Choice" 20 78 7 \
    "1 Keypad" "Ryde Network Control Handset"  \
    "2 FTDI" "FTDI Module Configuration Utility" \
    "3 Stream" "BATC Stream Viewer" \
    "4 Info" "Display System Information" \
    "5 Display Test" "Test the display for use with the Ryde" \
    "6 Ryde Test" "Run Ryde with the ability to read errors" \
	"7 Main Menu" "Go back to the Main Menu" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
      1\ *) do_keypad ;;
      2\ *) do_ftdi ;;
      3\ *) do_stream_display ;;
      4\ *) do_info ;;
      5\ *) do_pydispmanx_test ;;
      6\ *) do_cmd_line_ryde ;;
	  7\ *) status=1 ;;
    esac
  done
  status=0
}


do_Set_RC_Type_1()
{
  RC_FILE="exit"

  menuchoice=$(whiptail --title "Set Remote Control Model (1)" --menu "Select Choice and press enter" 20 78 11 \
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
    "99 Exit" "Exit without changing remote control model" \
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
        99\ *) RC_FILE="exit" ;;
    esac

  if [ "$RC_FILE" != "exit" ]; then # Amend the config file
    RC_FILE="        - ${RC_FILE}"
    sed -i "/handsets:/{n;s/.*/$RC_FILE/}" /home/pi/ryde/config.yaml
  fi
}

do_Set_RC_Type_2()
{
  RC_FILE="exit"

  menuchoice=$(whiptail --title "Set Remote Control Model (2)" --menu "Select Choice and press enter" 20 78 11 \
    "11 Hauppauge 2" "Hauppauge USB PVR Ex-digilite" \
    "12 TS-1 Sat" "Technosat TS-1 Satellite Receiver" \
    "13 TS-3500" "Technosat TS-3500 Satellite Receiver" \
    "14 F-2100 Uni" "Digi-Wav 2 Pound F2100 Universal Remote" \
    "15 SF8008" "Octagon SF8008 Sat RX Remote" \
    "16 Freesat V7" "Freesat V7 Combo - Some keys changed" \
    "17 RTL-SDR" "RTL-SDR Basic Remote" \
    "18 Avermedia" "AverMedia PC Card Tuner" \
    "19 AEG DVD" "German AEG DVD Remote" \
    "20 G-RCU-023" "German Remote from an Opticum HD AX150, labelled G-RCU-023" \
    "99 Exit" "Exit without changing remote control model" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        11\ *) RC_FILE="hauppauge_usb" ;;
        12\ *) RC_FILE="ts1_sat" ;;
        13\ *) RC_FILE="ts3500_sat" ;;
        14\ *) RC_FILE="f2100_uni" ;;
        15\ *) RC_FILE="sf8008" ;;
        16\ *) RC_FILE="freesat_v7" ;;
        17\ *) RC_FILE="rtl0" ;;
        18\ *) RC_FILE="avermediacard" ;;
        19\ *) RC_FILE="aeg_dvd" ;;
        20\ *) RC_FILE="g_rcu_023" ;;
        99\ *) RC_FILE="exit" ;;
    esac

  if [ "$RC_FILE" != "exit" ]; then # Amend the config file
    RC_FILE="        - ${RC_FILE}"
    sed -i "/handsets:/{n;s/.*/$RC_FILE/}" /home/pi/ryde/config.yaml
  fi
}

do_Set_RC_Type_3()
{
  RC_FILE="exit"

  menuchoice=$(whiptail --title "Set Remote Control Model (3)" --menu "Select Choice and press enter" 20 78 11 \
    "21 Pheonix" "Pheonix Satellite RX Remote" \
    "22 Classic" "Classic remote marked IRC83079" \
    "23 Tesco TV" "Tesco 18.5 inch TV Model LCD 19-229" \
    "24 LED TV" "Anonymous LED TV" \
    "25 Fortec" "Fortech Star Sat RX" \
    "26 CMtronic" "CMtronic" \
    "27 Technotrend" "Technotrend TT Connect" \
    "28 Philips TV" "Philips RC 4492/01B TV" \
    "29 MP3 Player" "MP3 Player" \
    "30 Dreambox TV" "Dreambox URC39931RJ0-06 TV" \
    "99 Exit" "Exit without changing remote control model" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        21\ *) RC_FILE="pheonix" ;;
        22\ *) RC_FILE="classic" ;;
        23\ *) RC_FILE="tesco_tv" ;;
        24\ *) RC_FILE="led_tv" ;;
        25\ *) RC_FILE="fortecstar" ;;
        26\ *) RC_FILE="cmtronic" ;;
        27\ *) RC_FILE="technotrendttc" ;;
        28\ *) RC_FILE="philipsrc4492" ;;
        29\ *) RC_FILE="mp3_player" ;;
        30\ *) RC_FILE="dreamboxurc39931" ;;
        99\ *) RC_FILE="exit" ;;
    esac

  if [ "$RC_FILE" != "exit" ]; then # Amend the config file
    RC_FILE="        - ${RC_FILE}"
    sed -i "/handsets:/{n;s/.*/$RC_FILE/}" /home/pi/ryde/config.yaml
  fi
}


do_Set_RC_Type_4()
{
  RC_FILE="exit"

  menuchoice=$(whiptail --title "Set Remote Control Model (4)" --menu "Select Choice and press enter" 20 78 11 \
    "31 Humax PVR" "Humax RM-F04 PVR" \
    "32 Xtrend TV" "Xtrend KT1252-XHY TV" \
    "33 Salora" "Salora TV or DVD Remote" \
    "34 StreamZap" "StreamZap PC Remote Control" \
    "35 Sky" "Sky Remote Control" \
    "36 CT-8541" "Toshiba CT-8541 Remote Control" \
    "37 GTMedia" "GTMedia Remote Control" \
    "38 Strong 5434" "Strong SRT-5434" \
    "39 Old Virgin" "Old-model Virgin Media" \
    "40 Scott DVD" "Scott DVD Player" \
    "99 Exit" "Exit without changing remote control model" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        31\ *) RC_FILE="humaxrmf04" ;;
        32\ *) RC_FILE="xtrendkt1252" ;;
        33\ *) RC_FILE="salora" ;;
        34\ *) RC_FILE="streamzap" ;;
        35\ *) RC_FILE="sky1" ;;
        36\ *) RC_FILE="tosh_ct_8541" ;;
        37\ *) RC_FILE="gtmedia" ;;
        38\ *) RC_FILE="strong5434" ;;
        39\ *) RC_FILE="oldvirgin" ;;
        40\ *) RC_FILE="scottdvd" ;;
        99\ *) RC_FILE="exit" ;;
    esac

  if [ "$RC_FILE" != "exit" ]; then # Amend the config file
    RC_FILE="        - ${RC_FILE}"
    sed -i "/handsets:/{n;s/.*/$RC_FILE/}" /home/pi/ryde/config.yaml
  fi
}


do_Set_RC_Type_5()
{
  RC_FILE="exit"

  menuchoice=$(whiptail --title "Set Remote Control Model (5)" --menu "Select Choice and press enter" 20 78 11 \
    "41 Sagem STB" "Sagem Set Top box" \
    "42 Altech TV" "Altech UEC Vast TV" \
    "43 Marantz CD" "Marantz RTC002 CD Player" \
    "44 K0QIT" "K0QIT" \
    "45 Sagem STB 2" "Another SAGEM Set Top Box" \
    "46 Sony RM-ED005" "Sony RM-ED005 or RMT-TX101D" \
    "47 Sony RMT-D248P" "Sony RMT-D248P HDD Recorder"
    "99 Exit" "Exit without changing remote control model" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        41\ *) RC_FILE="sagemstb" ;;
        42\ *) RC_FILE="altech_uec_vast_tv" ;;
        43\ *) RC_FILE="marantz_rtc002cd" ;;
        44\ *) RC_FILE="k0qit" ;;
        45\ *) RC_FILE="sagemstb2" ;;
        46\ *) RC_FILE="sony_rm-ed005" ;;
        47\ *) RC_FILE="sony_rmt-d248p" ;;
        99\ *) RC_FILE="exit" ;;
    esac

  if [ "$RC_FILE" != "exit" ]; then # Amend the config file
    RC_FILE="        - ${RC_FILE}"
    sed -i "/handsets:/{n;s/.*/$RC_FILE/}" /home/pi/ryde/config.yaml
  fi
}


do_Set_RC_Type()
{
  menuchoice=$(whiptail --title "Select Page 1, 2 or 3" --menu "Select Choice (key on BATC Wiki)" 20 78 6 \
    "1  1 - 10" "Virgin, Nebula, LG, Samsung"  \
    "2 11 - 20" "Various Sat Receivers" \
    "3 21 - 30" "Odds and Ends" \
    "4 31 - 40" "More Odds and Ends" \
    "5 41 - 50" "Even More Odds and Ends" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
      1\ *) do_Set_RC_Type_1 ;;
      2\ *) do_Set_RC_Type_2 ;;
      3\ *) do_Set_RC_Type_3 ;;
      4\ *) do_Set_RC_Type_4 ;;
      5\ *) do_Set_RC_Type_5 ;;
    esac
}

do_Set_Freq()
{
  PRESET_FREQ=0
  PRESET_SCAN_FREQ_1=0
  PRESET_SCAN_FREQ_2=0
  PRESET_SCAN_FREQ_3=0
  PRESET_SCAN_FREQ_4=0

  # Read and trim the preset FREQ Values
  PRESET_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq=)"
  if [ "$PRESET_FREQ_LINE" != "" ]; then
    PRESET_FREQ="$(echo "$PRESET_FREQ_LINE" | sed "s/presets__"$AMEND_PRESET"__freq=\"//" | sed 's/\"//')"
    SCAN_FREQ_VALUES=0
  else
    PRESET_SCAN_FREQ_1_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_1=)"
    if [ "$PRESET_SCAN_FREQ_1_LINE" != "" ]; then
      PRESET_SCAN_FREQ_1="$(echo "$PRESET_SCAN_FREQ_1_LINE" | sed "s/presets__"$AMEND_PRESET"__freq_1=\"//" | sed 's/\"//')"
      SCAN_FREQ_VALUES=1
      PRESET_SCAN_FREQ_2_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_2=)"
      if [ "$PRESET_SCAN_FREQ_2_LINE" != "" ]; then
        PRESET_SCAN_FREQ_2="$(echo "$PRESET_SCAN_FREQ_2_LINE" | sed "s/presets__"$AMEND_PRESET"__freq_2=\"//" | sed 's/\"//')"
        SCAN_FREQ_VALUES=2
        PRESET_SCAN_FREQ_3_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_3=)"
        if [ "$PRESET_SCAN_FREQ_3_LINE" != "" ]; then
          PRESET_SCAN_FREQ_3="$(echo "$PRESET_SCAN_FREQ_3_LINE" | sed "s/presets__"$AMEND_PRESET"__freq_3=\"//" | sed 's/\"//')"
          SCAN_FREQ_VALUES=3
          PRESET_SCAN_FREQ_4_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_4=)"
          if [ "$PRESET_SCAN_FREQ_4_LINE" != "" ]; then
            PRESET_SCAN_FREQ_4="$(echo "$PRESET_SCAN_FREQ_4_LINE" | sed "s/presets__"$AMEND_PRESET"__freq_4=\"//" | sed 's/\"//')"
            SCAN_FREQ_VALUES=4
          fi
        fi
      fi
    fi
  fi

  if [ "$SCAN_FREQ_VALUES" != "0" ]; then  # In scanning FREQ mode, so convert back to single FREQ
    
    # Set the preset FREQ to the first scanning FREQ
    PRESET_FREQ=$PRESET_SCAN_FREQ_1

    # Delete the scanning FREQ lines
    if [ "$SCAN_FREQ_VALUES" == "4" ]; then  # delete row 3
      sed -i "/^    "$AMEND_PRESET":/!b;n;n;d" /home/pi/ryde/config.yaml
      SCAN_FREQ_VALUES=3  # and decrement the number of rows
    fi
    if [ "$SCAN_FREQ_VALUES" == "3" ]; then  # delete row 3
      sed -i "/^    "$AMEND_PRESET":/!b;n;n;d" /home/pi/ryde/config.yaml
      SCAN_FREQ_VALUES=2  # and decrement the number of rows
    fi
    if [ "$SCAN_FREQ_VALUES" == "2" ]; then  # delete row 3
      sed -i "/^    "$AMEND_PRESET":/!b;n;n;d" /home/pi/ryde/config.yaml
      SCAN_FREQ_VALUES=1  # and decrement the number of rows
    fi
    if [ "$SCAN_FREQ_VALUES" == "1" ]; then  # delete row 3
      sed -i "/^    "$AMEND_PRESET":/!b;n;n;d" /home/pi/ryde/config.yaml
      SCAN_FREQ_VALUES=0  # and decrement the number of rows
    fi

    # Delete the first line that just said "        frequency:"
    sed -i "/^    "$AMEND_PRESET":/!b;n;d" /home/pi/ryde/config.yaml
    # Insert a new frequency line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;};a \        freq: $PRESET_FREQ" /home/pi/ryde/config.yaml
  fi

  PRESET_FREQ=$(whiptail --inputbox "Enter the new $AMEND_PRESET preset frequency in kHz" 8 78 $PRESET_FREQ --title "Frequency Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    # Delete the first line that just said "        frequency:"
    sed -i "/^    "$AMEND_PRESET":/!b;n;d" /home/pi/ryde/config.yaml
    # Insert a new frequency line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;};a \        freq: $PRESET_FREQ" /home/pi/ryde/config.yaml
  fi
}

do_Set_Scan_Freq()
{
  PRESET_FREQ=0
  PRESET_SCAN_FREQ_1=0
  PRESET_SCAN_FREQ_2=0
  PRESET_SCAN_FREQ_3=0
  PRESET_SCAN_FREQ_4=0

  # Read and trim the preset FREQ Values
  PRESET_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq=)"
  if [ "$PRESET_FREQ_LINE" != "" ]; then
    PRESET_FREQ="$(echo "$PRESET_FREQ_LINE" | sed "s/presets__"$AMEND_PRESET"__freq=\"//" | sed 's/\"//')"
    SCAN_FREQ_VALUES=0
  else
    PRESET_SCAN_FREQ_1_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_1=)"
    if [ "$PRESET_SCAN_FREQ_1_LINE" != "" ]; then
      PRESET_SCAN_FREQ_1="$(echo "$PRESET_SCAN_FREQ_1_LINE" | sed "s/presets__"$AMEND_PRESET"__freq_1=\"//" | sed 's/\"//')"
      SCAN_FREQ_VALUES=1
      PRESET_SCAN_FREQ_2_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_2=)"
      if [ "$PRESET_SCAN_FREQ_2_LINE" != "" ]; then
        PRESET_SCAN_FREQ_2="$(echo "$PRESET_SCAN_FREQ_2_LINE" | sed "s/presets__"$AMEND_PRESET"__freq_2=\"//" | sed 's/\"//')"
        SCAN_FREQ_VALUES=2
        PRESET_SCAN_FREQ_3_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_3=)"
        if [ "$PRESET_SCAN_FREQ_3_LINE" != "" ]; then
          PRESET_SCAN_FREQ_3="$(echo "$PRESET_SCAN_FREQ_3_LINE" | sed "s/presets__"$AMEND_PRESET"__freq_3=\"//" | sed 's/\"//')"
          SCAN_FREQ_VALUES=3
          PRESET_SCAN_FREQ_4_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_4=)"
          if [ "$PRESET_SCAN_FREQ_4_LINE" != "" ]; then
            PRESET_SCAN_FREQ_4="$(echo "$PRESET_SCAN_FREQ_4_LINE" | sed "s/presets__"$AMEND_PRESET"__freq_4=\"//" | sed 's/\"//')"
            SCAN_FREQ_VALUES=4
          fi
        fi
      fi
    fi
  fi

  # Convert to multi-FREQ format if single freq
  if [ "$SCAN_FREQ_VALUES" == 0 ]; then
    # Delete the first line that had the frequency value on it
    sed -i "/^    "$AMEND_PRESET":/!b;n;d" /home/pi/ryde/config.yaml
    # Insert a new blank frequency line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;};a \        freq:" /home/pi/ryde/config.yaml
    # Create the blank second line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;};n;a \          -" /home/pi/ryde/config.yaml
    # Put the previous single freq on the second line
    sed -i "/^    "$AMEND_PRESET":/!b;n;n;c\          - $PRESET_FREQ" /home/pi/ryde/config.yaml
    # So now the file is as if it was set up for multiples, but with one value
    SCAN_FREQ_VALUES=1
    PRESET_SCAN_FREQ_1=$PRESET_FREQ
  fi

  # Amend FREQ 1

  PRESET_SCAN_FREQ_1=$(whiptail --inputbox "Enter the first frequency in kHz" 8 78 $PRESET_SCAN_FREQ_1 --title "Frequency 1 Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    # Put it on the second line
    sed -i "/^    "$AMEND_PRESET":/!b;n;n;c\          - $PRESET_SCAN_FREQ_1" /home/pi/ryde/config.yaml
  fi

  # At this stage FREQ1 has been entered, so ask for FREQ 2

  PRESET_SCAN_FREQ_2=$(whiptail --inputbox "Enter the second frequency in kHz (enter 0 for no more freqs)" 8 78 $PRESET_SCAN_FREQ_2 --title "Frequency 2 Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then  # value has been changed
    if [ "$SCAN_FREQ_VALUES" == "1" ] ; then  # Previously only a single FREQ
      if [ "$PRESET_SCAN_FREQ_2" != "0" ] && [[ ! -z "$PRESET_SCAN_FREQ_2" ]]; then      # new valid FREQ entered (else do nothing)
        # row 3 does not exist, so create it
        sed -i "/^    "$AMEND_PRESET":/!{p;d;};n;n;a \          -" /home/pi/ryde/config.yaml
        # Put FREQ 2 on the third line
        sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;c\          - $PRESET_SCAN_FREQ_2" /home/pi/ryde/config.yaml
        SCAN_FREQ_VALUES=2
      fi
    else                                    # Previously multiple FREQs
      if [ "$PRESET_SCAN_FREQ_2" != "0" ] && [[ ! -z "$PRESET_SCAN_FREQ_2" ]]; then      # new valid FREQ entered, so now at least 2 freqs
        # so replace row 3 with new $PRESET_SCAN_FREQ_2
        sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;c\          - $PRESET_SCAN_FREQ_2" /home/pi/ryde/config.yaml
      else                                  # no more scanning FREQs, so delete 2nd 3rd and 4th freqs
        if [ "$SCAN_FREQ_VALUES" == "4" ]; then  # delete row 4
          sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;d" /home/pi/ryde/config.yaml
          SCAN_FREQ_VALUES=3  # and decrement the number of rows
        fi
        if [ "$SCAN_FREQ_VALUES" == "3" ]; then  # delete row 4
          sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;d" /home/pi/ryde/config.yaml
          SCAN_FREQ_VALUES=2  # and decrement the number of rows
        fi
        if [ "$SCAN_FREQ_VALUES" == "2" ]; then  # delete row 4
          sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;d" /home/pi/ryde/config.yaml
          SCAN_FREQ_VALUES=1  # and decrement the number of rows
        fi
      fi
    fi
  fi

  # At this stage FREQ2 has been entered, or SCAN_FREQ_VALUES=1 and we will do nothing more
  if [ "$SCAN_FREQ_VALUES" != "1" ]; then
    PRESET_SCAN_FREQ_3=$(whiptail --inputbox "Enter the third frequency in kHz (enter 0 for no more freqs)" 8 78 $PRESET_SCAN_FREQ_3 --title "Frequency 3 Entry Menu" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then  # value has been changed
      if [ "$SCAN_FREQ_VALUES" == "2" ] ; then  # Previously only 2 FREQs
        if [ "$PRESET_SCAN_FREQ_3" != "0" ] && [[ ! -z "$PRESET_SCAN_FREQ_3" ]]; then      # new valid FREQ entered (else do nothing)
          # row 4 does not exist, so create it
          sed -i "/^    "$AMEND_PRESET":/!{p;d;};n;n;n;a \          -" /home/pi/ryde/config.yaml
          # Put FREQ 3 on the 4th line
          sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;n;c\          - $PRESET_SCAN_FREQ_3" /home/pi/ryde/config.yaml
          # and set the FREQ scan values to 3
          SCAN_FREQ_VALUES=3
        fi
      else                                    # Previously multiple FREQs
        if [ "$PRESET_SCAN_FREQ_3" != "0" ] && [[ ! -z "$PRESET_SCAN_FREQ_3" ]]; then      # new valid FREQ entered
          # so replace row 4 with new $SCAN_FREQ_3
          sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;n;c\          - $PRESET_SCAN_FREQ_3" /home/pi/ryde/config.yaml
        else                                  # no more scanning FREQs, so delete lines
          if [ "$SCAN_FREQ_VALUES" == "4" ]; then  # delete row 5
            sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;n;d" /home/pi/ryde/config.yaml
            SCAN_FREQ_VALUES=3  # and decrement the number of rows
          fi
          if [ "$SCAN_FREQ_VALUES" == "3" ]; then  # delete row 4
            sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;n;d" /home/pi/ryde/config.yaml
            SCAN_FREQ_VALUES=2  # and decrement the number of rows
          fi
        fi
      fi
    fi
    # At this stage FREQ3 has been entered, or SCAN_FREQ_VALUES=2 and we will do nothing more

    if [ "$SCAN_FREQ_VALUES" != "2" ]; then
      PRESET_SCAN_FREQ_4=$(whiptail --inputbox "Enter the fourth frequency in kHz (enter 0 for no more freqs)" 8 78 $PRESET_SCAN_FREQ_4 --title "Frequency 4 Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then  # value has been changed
        if [ "$SCAN_FREQ_VALUES" == "3" ] ; then  # Previously only 3 FREQs
          if [ "$PRESET_SCAN_FREQ_4" != "0" ] && [[ ! -z "$PRESET_SCAN_FREQ_4" ]]; then      # new valid FREQ entered (else do nothing)
            # row 5 does not exist, so create it
            sed -i "/^    "$AMEND_PRESET":/!{p;d;};n;n;n;n;a \          -" /home/pi/ryde/config.yaml
            # Put FREQ 4 on the 5th line
            sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;n;n;c\          - $PRESET_SCAN_FREQ_4" /home/pi/ryde/config.yaml
            # and set the FREQ scan values to 4
            SCAN_FREQ_VALUES=4
          fi
        else                                    # Previously 4 FREQs
          if [ "$PRESET_SCAN_FREQ_4" != "0" ] && [[ ! -z "$PRESET_SCAN_FREQ_4" ]]; then      # new valid FREQ entered
            # so replace row 5 with new $SCAN_FREQ_4
            sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;n;n;c\          - $PRESET_SCAN_FREQ_4" /home/pi/ryde/config.yaml
          else                                  # no more scanning FREQs, so delete lines
            if [ "$SCAN_FREQ_VALUES" == "4" ]; then  # delete row 5
              sed -i "/^    "$AMEND_PRESET":/!b;n;n;n;n;n;d" /home/pi/ryde/config.yaml
              SCAN_FREQ_VALUES=3  # and decrement the number of rows
            fi
          fi
        fi
      fi
    fi
  fi
}


do_Set_SR()
{
  #First, detect how may freq: lines there are

  PRESET_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq=)"
  if [ "$PRESET_FREQ_LINE" != "" ]; then
    SCAN_FREQ_VALUES=0
  else
    PRESET_SCAN_FREQ_1_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_1=)"
    if [ "$PRESET_SCAN_FREQ_1_LINE" != "" ]; then
      SCAN_FREQ_VALUES=1
      PRESET_SCAN_FREQ_2_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_2=)"
      if [ "$PRESET_SCAN_FREQ_2_LINE" != "" ]; then
        SCAN_FREQ_VALUES=2
        PRESET_SCAN_FREQ_3_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_3=)"
        if [ "$PRESET_SCAN_FREQ_3_LINE" != "" ]; then
          SCAN_FREQ_VALUES=3
          PRESET_SCAN_FREQ_4_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_4=)"
          if [ "$PRESET_SCAN_FREQ_4_LINE" != "" ]; then
            SCAN_FREQ_VALUES=4
          fi
        fi
      fi
    fi
  fi
  # 0 means 1 line, 1 means 2 etc

 # Now create a pad element that counts down that many lines
  PAD=";n"
  case "$SCAN_FREQ_VALUES" in
    "0") PAD=";n" ;;
    "1") PAD=";n;n" ;;
    "2") PAD=";n;n;n" ;;
    "3") PAD=";n;n;n;n" ;;
    "4") PAD=";n;n;n;n;n" ;;
  esac

  PRESET_SR=0
  PRESET_SCAN_SR_1=0
  PRESET_SCAN_SR_2=0
  PRESET_SCAN_SR_3=0
  PRESET_SCAN_SR_4=0

  # Read and trim the preset SR Values
  PRESET_SR_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr=)"
  if [ "$PRESET_SR_LINE" != "" ]; then
    PRESET_SR="$(echo "$PRESET_SR_LINE" | sed "s/presets__"$AMEND_PRESET"__sr=\"//" | sed 's/\"//')"
    SCAN_SR_VALUES=0
  else
    PRESET_SCAN_SR_1_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_1=)"
    if [ "$PRESET_SCAN_SR_1_LINE" != "" ]; then
      PRESET_SCAN_SR_1="$(echo "$PRESET_SCAN_SR_1_LINE" | sed "s/presets__"$AMEND_PRESET"__sr_1=\"//" | sed 's/\"//')"
      SCAN_SR_VALUES=1
      PRESET_SCAN_SR_2_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_2=)"
      if [ "$PRESET_SCAN_SR_2_LINE" != "" ]; then
        PRESET_SCAN_SR_2="$(echo "$PRESET_SCAN_SR_2_LINE" | sed "s/presets__"$AMEND_PRESET"__sr_2=\"//" | sed 's/\"//')"
        SCAN_SR_VALUES=2
        PRESET_SCAN_SR_3_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_3=)"
        if [ "$PRESET_SCAN_SR_3_LINE" != "" ]; then
          PRESET_SCAN_SR_3="$(echo "$PRESET_SCAN_SR_3_LINE" | sed "s/presets__"$AMEND_PRESET"__sr_3=\"//" | sed 's/\"//')"
          SCAN_SR_VALUES=3
          PRESET_SCAN_SR_4_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_4=)"
          if [ "$PRESET_SCAN_SR_4_LINE" != "" ]; then
            PRESET_SCAN_SR_4="$(echo "$PRESET_SCAN_SR_4_LINE" | sed "s/presets__"$AMEND_PRESET"__sr_4=\"//" | sed 's/\"//')"
            SCAN_SR_VALUES=4
          fi
        fi
      fi
    fi
  fi

  if [ "$SCAN_SR_VALUES" != "0" ]; then  # In scanning SR mode, so convert back to single SR
    
    # Set the preset SR to the first scanning SR
    PRESET_SR=$PRESET_SCAN_SR_1

    # Delete the scanning SR lines
    if [ "$SCAN_SR_VALUES" == "4" ]; then  # delete row 3
      sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";n;d" /home/pi/ryde/config.yaml
      SCAN_SR_VALUES=3  # and decrement the number of rows
    fi
    if [ "$SCAN_SR_VALUES" == "3" ]; then  # delete row 3
      sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";n;d" /home/pi/ryde/config.yaml
      SCAN_SR_VALUES=2  # and decrement the number of rows
    fi
    if [ "$SCAN_SR_VALUES" == "2" ]; then  # delete row 3
      sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";n;d" /home/pi/ryde/config.yaml
      SCAN_SR_VALUES=1  # and decrement the number of rows
    fi
    if [ "$SCAN_SR_VALUES" == "1" ]; then  # delete row 3
      sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";n;d" /home/pi/ryde/config.yaml
      SCAN_SR_VALUES=0  # and decrement the number of rows
    fi

    # Delete the first line that just said "        sr:"
    sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";d" /home/pi/ryde/config.yaml
    # Insert a new sr line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";a \        sr:   $PRESET_SR" /home/pi/ryde/config.yaml
  fi

  PRESET_SR=$(whiptail --inputbox "Enter the new $AMEND_PRESET preset SR in kS" 8 78 $PRESET_SR --title "Symbol Rate Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    # Delete the first line that just said "        sr:"
    sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";d" /home/pi/ryde/config.yaml
    # Insert a new sr line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";a \        sr:   $PRESET_SR" /home/pi/ryde/config.yaml
  fi
}

do_Set_Scan_SR()
{
  #First, detect how may freq: lines there are

  PRESET_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq=)"
  if [ "$PRESET_FREQ_LINE" != "" ]; then
    SCAN_FREQ_VALUES=0
  else
    PRESET_SCAN_FREQ_1_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_1=)"
    if [ "$PRESET_SCAN_FREQ_1_LINE" != "" ]; then
      SCAN_FREQ_VALUES=1
      PRESET_SCAN_FREQ_2_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_2=)"
      if [ "$PRESET_SCAN_FREQ_2_LINE" != "" ]; then
        SCAN_FREQ_VALUES=2
        PRESET_SCAN_FREQ_3_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_3=)"
        if [ "$PRESET_SCAN_FREQ_3_LINE" != "" ]; then
          SCAN_FREQ_VALUES=3
          PRESET_SCAN_FREQ_4_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_4=)"
          if [ "$PRESET_SCAN_FREQ_4_LINE" != "" ]; then
            SCAN_FREQ_VALUES=4
          fi
        fi
      fi
    fi
  fi
  # 0 means 1 line, 1 means 2 etc

 # Now create a pad element that counts down that many lines
  PAD=";n"
  case "$SCAN_FREQ_VALUES" in
    "0") PAD=";n" ;;
    "1") PAD=";n;n" ;;
    "2") PAD=";n;n;n" ;;
    "3") PAD=";n;n;n;n" ;;
    "4") PAD=";n;n;n;n;n" ;;
  esac

  PRESET_SCAN_SR_1=0
  PRESET_SCAN_SR_2=0
  PRESET_SCAN_SR_3=0
  PRESET_SCAN_SR_4=0

  # Read and trim the preset SR Values
  PRESET_SR_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr=)"
  if [ "$PRESET_SR_LINE" != "" ]; then
    PRESET_SR="$(echo "$PRESET_SR_LINE" | sed "s/presets__"$AMEND_PRESET"__sr=\"//" | sed 's/\"//')"
    SCAN_SR_VALUES=0
  else
    PRESET_SCAN_SR_1_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_1=)"
    if [ "$PRESET_SCAN_SR_1_LINE" != "" ]; then
      PRESET_SCAN_SR_1="$(echo "$PRESET_SCAN_SR_1_LINE" | sed "s/presets__"$AMEND_PRESET"__sr_1=\"//" | sed 's/\"//')"
      SCAN_SR_VALUES=1
      PRESET_SCAN_SR_2_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_2=)"
      if [ "$PRESET_SCAN_SR_2_LINE" != "" ]; then
        PRESET_SCAN_SR_2="$(echo "$PRESET_SCAN_SR_2_LINE" | sed "s/presets__"$AMEND_PRESET"__sr_2=\"//" | sed 's/\"//')"
        SCAN_SR_VALUES=2
        PRESET_SCAN_SR_3_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_3=)"
        if [ "$PRESET_SCAN_SR_3_LINE" != "" ]; then
          PRESET_SCAN_SR_3="$(echo "$PRESET_SCAN_SR_3_LINE" | sed "s/presets__"$AMEND_PRESET"__sr_3=\"//" | sed 's/\"//')"
          SCAN_SR_VALUES=3
          PRESET_SCAN_SR_4_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_4=)"
          if [ "$PRESET_SCAN_SR_4_LINE" != "" ]; then
            PRESET_SCAN_SR_4="$(echo "$PRESET_SCAN_SR_4_LINE" | sed "s/presets__"$AMEND_PRESET"__sr_4=\"//" | sed 's/\"//')"
            SCAN_SR_VALUES=4
          fi
        fi
      fi
    fi
  fi

  # Convert to multi-SR format if in single-SR format
  if [ "$SCAN_SR_VALUES" == 0 ]; then
    # Delete the first line that had the SR value on it
    sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;d" /home/pi/ryde/config.yaml
    # Insert a new blank sr line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";a \        sr:" /home/pi/ryde/config.yaml
    # Create the blank second line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";n;a \          -" /home/pi/ryde/config.yaml
    # Put the previous single sr on the second line
    sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";n;c\          - $PRESET_SR" /home/pi/ryde/config.yaml
    # So now the file is as if it was set up for multiples, but with one value
    SCAN_SR_VALUES=1
    PRESET_SCAN_SR_1=$PRESET_SR
  fi

  # Amend SR 1

  PRESET_SCAN_SR_1=$(whiptail --inputbox "Enter the first SR in kS" 8 78 $PRESET_SCAN_SR_1 --title "Symbol Rate 1 Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    # Put it on the second line
    sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;c\          - $PRESET_SCAN_SR_1" /home/pi/ryde/config.yaml
  fi

  # At this stage SR1 has been entered, so ask for SR 2

  PRESET_SCAN_SR_2=$(whiptail --inputbox "Enter the second SR in kS (enter 0 for no more SRs)" 8 78 $PRESET_SCAN_SR_2 --title "Symbol Rate 2 Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then  # value has been changed
    if [ "$SCAN_SR_VALUES" == "1" ] ; then  # Previously only a single SR
      if [ "$PRESET_SCAN_SR_2" != "0" ] && [[ ! -z "$PRESET_SCAN_SR_2" ]]; then      # new valid SR entered (else do nothing)
        # row 3 does not exist, so create it
        sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";n;n;a \          -" /home/pi/ryde/config.yaml
        # Put SR 2 on the third line
        sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;c\          - $PRESET_SCAN_SR_2" /home/pi/ryde/config.yaml
        SCAN_SR_VALUES=2
      fi
    else                                    # Previously multiple SRs
      if [ "$PRESET_SCAN_SR_2" != "0" ] && [[ ! -z "$PRESET_SCAN_SR_2" ]]; then      # new valid SR entered, so now at least 2 srs
        # so replace row 3 with new $PRESET_SCAN_SR_2
        sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;c\          - $PRESET_SCAN_SR_2" /home/pi/ryde/config.yaml
      else                                  # no more scanning SRs, so delete 2nd 3rd and 4th SRs
        if [ "$SCAN_SR_VALUES" == "4" ]; then  # delete row 4
          sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;d" /home/pi/ryde/config.yaml
          SCAN_SR_VALUES=3  # and decrement the number of rows
        fi
        if [ "$SCAN_SR_VALUES" == "3" ]; then  # delete row 4
          sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;d" /home/pi/ryde/config.yaml
          SCAN_SR_VALUES=2  # and decrement the number of rows
        fi
        if [ "$SCAN_SR_VALUES" == "2" ]; then  # delete row 4
          sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;d" /home/pi/ryde/config.yaml
          SCAN_SR_VALUES=1  # and decrement the number of rows
        fi
      fi
    fi
  fi

  # At this stage SR2 has been entered, or SCAN_SR_VALUES=1 and we will do nothing more
  if [ "$SCAN_SR_VALUES" != "1" ]; then
    PRESET_SCAN_SR_3=$(whiptail --inputbox "Enter the third SR in kS (enter 0 for no more SRs)" 8 78 $PRESET_SCAN_SR_3 --title "Symbol Rate 3 Entry Menu" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then  # value has been changed
      if [ "$SCAN_SR_VALUES" == "2" ] ; then  # Previously only 2 SRs
        if [ "$PRESET_SCAN_SR_3" != "0" ] && [[ ! -z "$PRESET_SCAN_SR_3" ]]; then      # new valid SR entered (else do nothing)
          # row 4 does not exist, so create it
          sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";n;n;n;a \          -" /home/pi/ryde/config.yaml
          # Put SR 3 on the 4th line
          sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;n;c\          - $PRESET_SCAN_SR_3" /home/pi/ryde/config.yaml
          # and set the SR scan values to 3
          SCAN_SR_VALUES=3
        fi
      else                                    # Previously multiple SRs
        if [ "$PRESET_SCAN_SR_3" != "0" ] && [[ ! -z "$PRESET_SCAN_SR_3" ]]; then      # new valid SR entered
          # so replace row 4 with new $SCAN_SR_3
          sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;n;c\          - $PRESET_SCAN_SR_3" /home/pi/ryde/config.yaml
        else                                  # no more scanning SRs, so delete lines
          if [ "$SCAN_SR_VALUES" == "4" ]; then  # delete row 5
            sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;n;d" /home/pi/ryde/config.yaml
            SCAN_SR_VALUES=3  # and decrement the number of rows
          fi
          if [ "$SCAN_SR_VALUES" == "3" ]; then  # delete row 4
            sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;n;d" /home/pi/ryde/config.yaml
            SCAN_SR_VALUES=2  # and decrement the number of rows
          fi
        fi
      fi
    fi
    # At this stage SR3 has been entered, or SCAN_SR_VALUES=2 and we will do nothing more

    if [ "$SCAN_SR_VALUES" != "2" ]; then
      PRESET_SCAN_SR_4=$(whiptail --inputbox "Enter the fourth SR in kS (enter 0 for no more SRs)" 8 78 $PRESET_SCAN_SR_4 --title "Symbol Rate 4 Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then  # value has been changed
        if [ "$SCAN_SR_VALUES" == "3" ] ; then  # Previously only 3 SRs
          if [ "$PRESET_SCAN_SR_4" != "0" ] && [[ ! -z "$PRESET_SCAN_SR_4" ]]; then      # new valid SR entered (else do nothing)
            # row 5 does not exist, so create it
            sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";n;n;n;n;a \          -" /home/pi/ryde/config.yaml
            # Put SR 4 on the 5th line
            sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;n;n;c\          - $PRESET_SCAN_SR_4" /home/pi/ryde/config.yaml
            # and set the SR scan values to 4
            SCAN_SR_VALUES=4
          fi
        else                                    # Previously 4 SRs
          if [ "$PRESET_SCAN_SR_4" != "0" ] && [[ ! -z "$PRESET_SCAN_SR_4" ]]; then      # new valid SR entered
            # so replace row 5 with new $SCAN_SR_4
            sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;n;n;c\          - $PRESET_SCAN_SR_4" /home/pi/ryde/config.yaml
          else                                  # no more scanning SRs, so delete lines
            if [ "$SCAN_SR_VALUES" == "4" ]; then  # delete row 5
              sed -i "/^    "$AMEND_PRESET":/!b"$PAD";n;n;n;n;n;d" /home/pi/ryde/config.yaml
              SCAN_SR_VALUES=3  # and decrement the number of rows
            fi
          fi
        fi
      fi
    fi
  fi
}

do_Set_Preset_Band()
{
  BAND_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__band=)"
  BAND="$(echo "$BAND_LINE" | sed "s/presets__"$AMEND_PRESET"__band=\"//" | sed 's/\"//')"

  Radio1=OFF
  Radio2=OFF
  Radio3=OFF
  Radio4=OFF
  Radio5=OFF
  Radio6=OFF
  Radio7=OFF
  Radio8=OFF
  Radio9=OFF
  Radio10=OFF

  case "$BAND" in
    "*bandlnblow")
      Radio1=ON
    ;;
    "*band146")
      Radio2=ON
    ;;
    "*band437")
      Radio3=ON
    ;;
    "*band1255")
      Radio4=ON
    ;;
    "*band2400")
      Radio5=ON
    ;;
    "*band3400")
      Radio6=ON
    ;;
    "*band5760")
      Radio7=ON
    ;;
    "*band10368")
      Radio8=ON
    ;;
    "*band146T")
      Radio9=ON
    ;;
    "*band437T")
      Radio10=ON
    ;;
    *)
      Radio1=ON
    ;;
  esac

  NEW_BAND=$(whiptail --title "Select the new $AMEND_PRESET preset band" --radiolist \
    "Highlight choice, select with space bar and then press enter" 20 78 12 \
    "QO-100" "QO-100 Band" $Radio1 \
    "146" "146 MHz Band" $Radio2 \
    "437" "437 MHz Band" $Radio3 \
    "1255" "1255 MHz Band" $Radio4 \
    "2400" "2400 MHz Band" $Radio5 \
    "3400" "3400 MHz Band" $Radio6 \
    "5760" "5760 MHz Band" $Radio7 \
    "10368" "10368 MHz Band" $Radio8 \
    "146T" "146 MHz Band DVB-T" $Radio9 \
    "437T" "437 MHz Band DVB-T" $Radio10 \
    3>&2 2>&1 1>&3)

  if [ $? -eq 0 ]; then  # The band has changed, so amend it
    case "$NEW_BAND" in
      "QO-100")
        NEW_BAND=*bandlnblow
      ;;
      "146")
        NEW_BAND=*band146
      ;;
      "437")
        NEW_BAND=*band437
      ;;
      "1255")
        NEW_BAND=*band1255
      ;;
      "2400")
        NEW_BAND=*band2400
      ;;
      "3400")
        NEW_BAND=*band3400
      ;;
      "5760")
        NEW_BAND=*band5760
      ;;
      "10368")
      NEW_BAND=*band10368
      ;;
      "146T")
        NEW_BAND=*band146T
      ;;
      "437T")
        NEW_BAND=*band437T
      ;;

    esac

    # First, detect how may freq: lines there are

    PRESET_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq=)"
    if [ "$PRESET_FREQ_LINE" != "" ] || [ "$NEW_BAND" == "*band146T" ] || [ "$NEW_BAND" == "*band437T" ]; then
      SCAN_FREQ_VALUES=0
    else
      PRESET_SCAN_FREQ_1_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_1=)"
      if [ "$PRESET_SCAN_FREQ_1_LINE" != "" ]; then
        SCAN_FREQ_VALUES=1
        PRESET_SCAN_FREQ_2_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_2=)"
        if [ "$PRESET_SCAN_FREQ_2_LINE" != "" ]; then
          SCAN_FREQ_VALUES=2
          PRESET_SCAN_FREQ_3_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_3=)"
          if [ "$PRESET_SCAN_FREQ_3_LINE" != "" ]; then
            SCAN_FREQ_VALUES=3
            PRESET_SCAN_FREQ_4_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq_4=)"
            if [ "$PRESET_SCAN_FREQ_4_LINE" != "" ]; then
              SCAN_FREQ_VALUES=4
            fi
          fi
        fi
      fi
    fi
    # 0 means 1 line, 1 means 2 etc

    # Next, detect how may sr: lines there are

    PRESET_SR_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr=)"
    if [ "$PRESET_SR_LINE" != "" ] || [ "$NEW_BAND" == "*band146T" ] || [ "$NEW_BAND" == "*band437T" ] ; then
      SCAN_SR_VALUES=0
    else
      PRESET_SCAN_SR_1_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_1=)"
      if [ "$PRESET_SCAN_SR_1_LINE" != "" ]; then
        SCAN_SR_VALUES=1
        PRESET_SCAN_SR_2_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_2=)"
        if [ "$PRESET_SCAN_SR_2_LINE" != "" ]; then
          SCAN_SR_VALUES=2
          PRESET_SCAN_SR_3_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_3=)"
          if [ "$PRESET_SCAN_SR_3_LINE" != "" ]; then
            SCAN_SR_VALUES=3
            PRESET_SCAN_SR_4_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__sr_4=)"
            if [ "$PRESET_SCAN_SR_4_LINE" != "" ]; then
              SCAN_SR_VALUES=4
            fi
          fi
        fi
      fi
    fi
    # 0 means 1 line, 1 means 2 etc

    # Add the SR and Freq Lines:
    let "VALUES=$SCAN_FREQ_VALUES + $SCAN_SR_VALUES + 1"

    # Now create a pad element that counts down that many lines
    PAD=";n"
    case "$VALUES" in
      "0") PAD=";n" ;;
      "1") PAD=";n;n" ;;
      "2") PAD=";n;n;n" ;;
      "3") PAD=";n;n;n;n" ;;
      "4") PAD=";n;n;n;n;n" ;;
      "5") PAD=";n;n;n;n;n;n" ;;
      "6") PAD=";n;n;n;n;n;n;n" ;;
      "7") PAD=";n;n;n;n;n;n;n;n" ;;
      "8") PAD=";n;n;n;n;n;n;n;n;n" ;;
      "9") PAD=";n;n;n;n;n;n;n;n;n;n" ;;
    esac

    # Delete the line that just said "        band:"
    sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";d" /home/pi/ryde/config.yaml
    # Insert a new band line
    sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";a \        band: $NEW_BAND" /home/pi/ryde/config.yaml
  fi
}

do_Set_Presets()
{
  menuchoice=$(whiptail --title "Select Preset for Amendment" --menu "Select Choice" 20  78 12 \
    "1  QO-100_Beacon" "Amend details for the QO-100_Beacon preset" \
    "2  QO-100_9.25_333" "Amend details for the QO-100_9.25_333 preset" \
    "3  QO-100_Custom" "Amend details for the QO-100_Custom preset" \
    "4  QO-100_Scan" "Amend details for the QO-100_Scan preset" \
    "5  146.5_MHz_125" "Amend details for the 146.5_MHz_125 preset" \
    "6  146.5_MHz_333" "Amend details for the 146.5_MHz_333 preset" \
    "7  437.0_MHz_333" "Amend details for the 437.0_MHz_333 preset" \
    "8  437.0_MHz_1000" "Amend details for the 437.0_MHz_1000 preset" \
    "9  1255_MHz_333" "Amend details for the 1255_MHz_333 preset" \
    "10 1255_MHz_Custom" "Amend details for the 1255_MHz_Custom preset" \
    "11 146_MHz_333_T" "Amend details for the 146.5_MHz_333 DVB-T preset" \
    "12 437_MHz_333_T" "Amend details for the 437.0_MHz_333 DVB-T preset" \
      3>&2 2>&1 1>&3)

      case "$menuchoice" in
        1\ *) AMEND_PRESET="QO-100_Beacon" ;;
        2\ *) AMEND_PRESET="QO-100_9.25_333"  ;;
        3\ *) AMEND_PRESET="QO-100_Custom" ;;
        4\ *) AMEND_PRESET="QO-100_Scan"  ;;
        5\ *) AMEND_PRESET="146.5_MHz_125" ;;
        6\ *) AMEND_PRESET="146.5_MHz_333"  ;;
        7\ *) AMEND_PRESET="437.0_MHz_333" ;;
        8\ *) AMEND_PRESET="437.0_MHz_1000"  ;;
        9\ *) AMEND_PRESET="1255_MHz_333" ;;
        10\ *) AMEND_PRESET="1255_MHz_Custom"  ;;
        11\ *) AMEND_PRESET="146_333_T" ;;
        12\ *) AMEND_PRESET="437_333_T"  ;;
      esac

  do_Set_Preset_Band
  if [ "$AMEND_PRESET" != "146_333_T" ] && [ "$AMEND_PRESET" != "146_333_T" ]; then
    # DVB-S and DVB-S2 presets


    menuchoice=$(whiptail --title "Amend frequency details for the $AMEND_PRESET preset" --menu "Select Choice" 16 78 10 \
      "1 Freq" "Set a Single Receive Frequency" \
      "2 Scan Freqs" "Set Multiple Receive Frequencies for Scanning" \
        3>&2 2>&1 1>&3)
      case "$menuchoice" in
        1\ *) do_Set_Freq ;;
        2\ *) do_Set_Scan_Freq ;;
      esac

    menuchoice=$(whiptail --title "Amend SR details for the $AMEND_PRESET preset" --menu "Select Choice" 16 78 10 \
      "1 SR" "Set a Single Receive SR" \
      "2 Scan SRs" "Set Multiple Receive SRs for Scanning" \
        3>&2 2>&1 1>&3)
      case "$menuchoice" in
        1\ *) do_Set_SR ;;
        2\ *) do_Set_Scan_SR ;;
      esac
  else
    # DVB-T presets
    PRESET_FREQ=0
    PRESET_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__freq=)"
    if [ "$PRESET_FREQ_LINE" != "" ]; then
      PRESET_FREQ="$(echo "$PRESET_FREQ_LINE" | sed "s/presets__"$AMEND_PRESET"__freq=\"//" | sed 's/\"//')"
    fi
    PRESET_FREQ=$(whiptail --inputbox "Enter the new $AMEND_PRESET preset frequency in kHz" 8 78 $PRESET_FREQ --title "Frequency Entry Menu" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      # Delete the first line that just said "        freq:"
      sed -i "/^    "$AMEND_PRESET":/!b;n;d" /home/pi/ryde/config.yaml
      # Insert a new frequency line
      sed -i "/^    "$AMEND_PRESET":/!{p;d;};a \        freq: $PRESET_FREQ" /home/pi/ryde/config.yaml
    fi

    SCAN_FREQ_VALUES=0
    # Now create a pad element that counts down that many lines
    PAD=";n"

    PRESET_BW=0

    # Read and trim the preset BW Value
    PRESET_BW_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep presets__"$AMEND_PRESET"__bw=)"
    if [ "$PRESET_BW_LINE" != "" ]; then
      PRESET_BW="$(echo "$PRESET_BW_LINE" | sed "s/presets__"$AMEND_PRESET"__bw=\"//" | sed 's/\"//')"
    fi
    PRESET_BW=$(whiptail --inputbox "Enter the new $AMEND_PRESET preset BW in kHz" 8 78 $PRESET_BW --title "DVB-T Bandwidth Entry Menu" 3>&1 1>&2 2>&3)
    if [ $? -eq 0 ]; then
      # Delete the first line that just said "        bw:"
      sed -i "/^    "$AMEND_PRESET":/!b;n"$PAD";d" /home/pi/ryde/config.yaml
      # Insert a new bw line
      sed -i "/^    "$AMEND_PRESET":/!{p;d;}"$PAD";a \        bw:   $PRESET_BW" /home/pi/ryde/config.yaml
    fi
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

do_Set_TSTimeout()
{
  # Read and trim the current TS Timeout
  TS_TIMEOUT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'LONGMYND__tstimeout=')"
  TS_TIMEOUT="$(echo "$TS_TIMEOUT_LINE" | sed 's/sources__LONGMYND__tstimeout=\"//' | sed 's/\"//')"

  # Deal with the $TS_TIMEOUT=-1 case, which does not work with whiptail
  if [ "$TS_TIMEOUT" == "-1" ]; then
    TS_TIMEOUT=""
  fi

  TS_TIMEOUT=$(whiptail --inputbox "Enter the new TS Timeout in mS (default 5000 - ie 5 seconds)" 8 78 $TS_TIMEOUT --title "TS TimeOut Entry Menu" 3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    sed -i "/        tstimeout:/c\        tstimeout: $TS_TIMEOUT" /home/pi/ryde/config.yaml
  fi
}

do_Restore_Factory()
{
  cp /home/pi/ryde-build/config.yaml /home/pi/ryde/config.yaml
  cp /home/pi/ryde-build/configs/dvbt/dvb-t_config.txt /home/pi/dvbt/dvb-t_config.txt
  # Wait here until user presses a key
  whiptail --title "Factory Setting Restored" --msgbox "Touch any key to continue.  You will need to reselect your remote control type." 8 78
}

do_Debug_Menu()
{
  # Read and trim the current Debug Menu Setting
  DEBUG_MENU_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'debug__enableMenu=')"
  DEBUG_MENU="$(echo "$DEBUG_MENU_LINE" | sed 's/debug__enableMenu=\"//' | sed 's/\"//')"

  Radio1=OFF
  Radio2=OFF
  case "$DEBUG_MENU" in
    "False")
      Radio1=ON
    ;;
    "True")
      Radio2=ON
    ;;
    *)
      Radio1=ON
    ;;
  esac
  DEBUG_MENU=$(whiptail --title "Select Whether the Debug Menu is Displayed" --radiolist \
    "Highlight choice, select with space bar and then press enter" 20 78 5 \
    "False" "Debug Menu Not Displayed" $Radio1 \
    "True" "Debug Menu Displayed" $Radio2 \
    3>&2 2>&1 1>&3)
  if [ $? -eq 0 ]; then
    sed -i "/    enableMenu:/c\    enableMenu: $DEBUG_MENU" /home/pi/ryde/config.yaml
  fi
}


do_Power_Button()
{
  # Read and trim the current Power Button Setting
  POWER_BUTTON_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'shutdownBehavior=')"
  POWER_BUTTON="$(echo "$POWER_BUTTON_LINE" | sed 's/shutdownBehavior=\"//' | sed 's/\"//')"

  Radio1=OFF
  Radio2=OFF
  case "$POWER_BUTTON" in
    "APPSTOP")
      Radio1=ON
    ;;
    "APPREST")
      Radio2=ON
    ;;
    *)
      Radio1=ON
    ;;
  esac
  POWER_BUTTON=$(whiptail --title "Select Action on Power Button Double Press" --radiolist \
    "Highlight choice, select with space bar and then press enter" 20 78 5 \
    "APPSTOP" "Ryde Application Stops, RPi keeps Running" $Radio1 \
    "APPREST" "Ryde Application Restarts" $Radio2 \
    3>&2 2>&1 1>&3)
  if [ $? -eq 0 ]; then
    sed -i "/shutdownBehavior:/c\shutdownBehavior: $POWER_BUTTON" /home/pi/ryde/config.yaml
  fi
}

do_SD_Button()
{
  Radio1=OFF
  Radio2=OFF

  # Check current status
  # If /home/pi/.pi-sdn exists then it is loaded

  if test -f "/home/pi/.pi-sdn"; then
    Radio1=ON
  else
    Radio2=ON
  fi
  SD_BUTTON=$(whiptail --title "Select Hardware Shutdown Function" --radiolist \
    "Highlight choice, select with space bar and then press enter" 20 78 5 \
    "SHUTDOWN" "RPi Immediately Shuts Down" $Radio1 \
    "DO NOTHING" "Nothing happens" $Radio2 \
    3>&2 2>&1 1>&3)
  if [ $? -eq 0 ]; then
    if [ "$SD_BUTTON" == "SHUTDOWN" ]; then
      cp /home/pi/ryde-build/text.pi-sdn /home/pi/.pi-sdn  ## Load it at logon
      /home/pi/.pi-sdn                                     ## Load it now
    else
      rm /home/pi/.pi-sdn >/dev/null 2>/dev/null           ## Stop it being loaded at log-on
      sudo pkill -x pi-sdn                                 ## kill the current process
    fi
  fi
}

do_Watchdog()
{
  Radio1=OFF
  Radio2=OFF

  # Check current status
  # If /home/pi/ryde-build/watchdog.sh is in .bashrc then it is enabled

  grep -q "^  /home/pi/ryde-build/watchdog.sh" /home/pi/.bashrc
  if [ $? -eq 0 ]; then  #  Watchdog is enabled
    Radio2=ON
  else
    Radio1=ON
  fi

  WATCHDOG=$(whiptail --title "Enable/disable Watchdog Function" --radiolist \
    "Highlight choice, select with space bar and then press enter" 20 78 5 \
    "DISABLE" "No Watchdog" $Radio1 \
    "ENABLE" "Watchdog Enabled" $Radio2 \
    3>&2 2>&1 1>&3)
  if [ $? -eq 0 ]; then
    if [ "$WATCHDOG" == "ENABLE" ]; then
      # Check if line just needs changing
      grep -q "~  #/home/pi/ryde-build/watchdog.sh" /home/pi/.bashrc
      if [ $? -eq 0 ]; then
        # Line just needs changing to
        sed -i -E 's+^  \#/home/pi/ryde-build/watchdog.sh \&+  /home/pi/ryde-build/watchdog.sh \&+' /home/pi/.bashrc
      else
        # Insert both comment and Watchdog start lines

        ## Set constants for the amendment of /home/pi/.bashrc
        lead='^  amixer set Headphone 0db >\/dev\/null 2>\/dev\/null'  ## Marker for start of inserted text
        tail='^  # Start Ryde'                                         ## Marker for end of inserted text
        CHANGEFILE="/home/pi/.bashrc"                                  ## File requiring added text
        TRANSFILE="/home/pi/tmp/transfer.txt"                          ## File used for transfer
        INSERTFILE="/home/pi/ryde-build/watchdog_start_text.txt"       ## File with text to be added

        grep -q "$lead" "$CHANGEFILE"                                  ## Check first marker present
        if [ $? -ne 0 ]; then
          echo "Problem with inserting watchdog text. 1st marker not found"
        else
          grep -q "$tail" "$CHANGEFILE"                                ## Check second marker present
          if [ $? -ne 0 ]; then
            echo "Problem with inserting watchdog text. 2nd marker not found"
          else
            ## Replace whatever is between the markers with the watchdog start text
            sed -e "/$lead/,/$tail/{ /$lead/{p; r $INSERTFILE
                    }; /$tail/p; d }" $CHANGEFILE >> $TRANSFILE

            cp "$TRANSFILE" "$CHANGEFILE"                              ## Copy from the transfer file
            rm $TRANSFILE                                              ## Delete the transfer file
          fi
        fi
      fi
    fi

    if [ "$WATCHDOG" == "DISABLE" ]; then
      sed -i -E 's+^  /home/pi/ryde-build/watchdog.sh \&+  \#/home/pi/ryde-build/watchdog.sh \&+' /home/pi/.bashrc
    fi
  fi
}


do_Check_HDMI()
{
  reset
  tvservice -n
  tvservice -s
  cd /home/pi/pydispmanx && python3 demo.py
  cd /home/pi
  read -p "Press enter to continue"
}
 
do_VtoH()
{
  mv /home/pi/ryde-build/rx.sh /home/pi/ryde-build/configs/ryde_rx.sh
  cp /home/pi/ryde-build/configs/cv_rx.sh /home/pi/ryde-build/rx.sh
  printf "\nComposite Video conversion starts on reboot\n"
  printf "\nPress any key to return to the menu\n"
  read -n 1
}


do_Reverse_VtoH()
{
  rm /home/pi/ryde-build/rx.sh
  cp /home/pi/ryde-build/configs/ryde_rx.sh /home/pi/ryde-build/rx.sh
  printf "\nNormal Ryde Functionality Restored\n"
  printf "\nPress any key to return to the menu\n"
  read -n 1
}


do_Settings()
{
  status=0
  while [ "$status" -eq 0 ] 
  do
    menuchoice=$(whiptail --title "Advanced Settings Menu" --menu "Select Choice and press enter" 18 78 12 \
      "1 Tuner Timeout" "Adjust the Tuner Reset Time when no valid TS " \
      "2 Restore Factory" "Reset all settings to default" \
      "3 Check HDMI" "List HDMI settings for fault-finding" \
      "4 Debug Menu" "Enable or Disable the Debug Menu" \
      "5 Power Button" "Set behaviour on double press of power button" \
      "6 Daily Reboot" "Enable 12-hourly reboot for Repeater Operation" \
      "7 Stop Reboot" "Disable 12-hourly reboot for Repeater Operation" \
      "8 Video to HDMI" "Convert to a Video to HDMI Converter" \
      "9 Stop V to H" "Restore normal Ryde Functionality" \
      "10 Hardware Shutdown" "Enable or disable hardware shutdown function" \
      "11 LongMynd Watchdog" "Enable or disable DVB-S/S2 Receiver watchdog" \
	  "12 Main Menu" "Go back to the Main Menu" \
        3>&2 2>&1 1>&3)
      case "$menuchoice" in
        1\ *) do_Set_TSTimeout ;;
        2\ *) do_Restore_Factory ;;
        3\ *) do_Check_HDMI ;;
        4\ *) do_Debug_Menu ;;
        5\ *) do_Power_Button ;;
        6\ *) sudo crontab /home/pi/ryde-build/configs/rptrcron ;;
        7\ *) sudo crontab /home/pi/ryde-build/configs/blankcron ;;
        8\ *) do_VtoH ;;
        9\ *) do_Reverse_VtoH ;;
        10\ *) do_SD_Button ;;
        11\ *) do_Watchdog ;;
	    12\ *) status=1 ;;
      esac
  done
  status=0
}


do_Set_Bands()
{
  menuchoice=$(whiptail --title "Select band for Amendment" --menu "Select Choice and then press enter" 20 78 11 \
    "1 QO-100" "Set the LNB Offset frequency for QO-100" \
    "2 146" "Amend details for the 146 MHz Band" \
    "3 437" "Amend details for the 437 MHz Band" \
    "4 1255" "Amend details for the 1255 MHz Band" \
    "5 2400" "Amend details for the 2400 MHz Band" \
    "6 3400" "Amend details for the 3400 MHz Band" \
    "7 5760" "Amend details for the 5760 MHz Band" \
    "8 10368" "Amend details for the 10368 MHz Band" \
    "9 146T" "Amend details for the 146 MHz DVB-T Band" \
    "10 437T" "Amend details for the 437 MHz DVB-T Band" \
    "11 Exit" "Return to the Main Menu" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
      1\ *) AMEND_BAND="QO-100" ;;
      2\ *) AMEND_BAND="146"  ;;
      3\ *) AMEND_BAND="437" ;;
      4\ *) AMEND_BAND="1255"  ;;
      5\ *) AMEND_BAND="2400" ;;
      6\ *) AMEND_BAND="3400"  ;;
      7\ *) AMEND_BAND="5760" ;;
      8\ *) AMEND_BAND="10368"  ;;
      9\ *) AMEND_BAND="146T"  ;;
      10\ *) AMEND_BAND="437T" ;;
      11\ *) AMEND_BAND="menu_exit"  ;;
    esac

  case "$AMEND_BAND" in
    "QO-100")
      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__QO-100__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__QO-100__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the QO-100 Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    QO-100:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__QO-100__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__QO-100__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new QO-100 LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    QO-100:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    QO-100:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__QO-100__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__QO-100__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the QO-100 Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency (normal)" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    QO-100:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the polarity
      POL_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__QO-100__pol=')"
      POL="$(echo "$POL_LINE" | sed 's/bands__QO-100__pol=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      Radio3=OFF
      case "$POL" in
        "NONE")
          Radio1=ON
        ;;
        "VERTICAL")
          Radio2=ON
        ;;
        "HORIZONTAL")
          Radio3=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_POL=$(whiptail --title "Select the new QO-100 Polarity" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "NONE" "No LNB Voltage" $Radio1 \
        "VERTICAL" "Vertical Polarity 13 Volts" $Radio2 \
        "HORIZONTAL" "Horizontal Polarity 18 Volts (QO-100)" $Radio3 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    QO-100:/!b;n;n;n;n;c\        pol: $NEW_POL" /home/pi/ryde/config.yaml
      fi

      # Read and trim the port
      PORT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__QO-100__port=')"
      PORT="$(echo "$PORT_LINE" | sed 's/bands__QO-100__port=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      case "$PORT" in
        "TOP")
          Radio1=ON
        ;;
        "BOTTOM")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_PORT=$(whiptail --title "Select the new QO-100 Tuner Port" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "TOP" "Top Tuner Port    (Socket A)" $Radio1 \
        "BOTTOM" "Bottom Tuner Port (Socket B)" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    QO-100:/!b;n;n;n;n;n;c\        port: $NEW_PORT" /home/pi/ryde/config.yaml
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__QO-100__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__QO-100__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new QO-100 Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    QO-100:/!b;n;n;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;
    "146")
      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__146__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 146 Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    146:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__146__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 146 MHz Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    146:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    146:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__146__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 146 MHz Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    146:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the polarity
      POL_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146__pol=')"
      POL="$(echo "$POL_LINE" | sed 's/bands__146__pol=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      Radio3=OFF
      case "$POL" in
        "NONE")
          Radio1=ON
        ;;
        "VERTICAL")
          Radio2=ON
        ;;
        "HORIZONTAL")
          Radio3=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_POL=$(whiptail --title "Select the new 146 MHz Band Polarity" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "NONE" "No LNB Voltage" $Radio1 \
        "VERTICAL" "Vertical Polarity 13 Volts" $Radio2 \
        "HORIZONTAL" "Horizontal Polarity 18 Volts" $Radio3 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    146:/!b;n;n;n;n;c\        pol: $NEW_POL" /home/pi/ryde/config.yaml
      fi

      # Read and trim the port
      PORT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146__port=')"
      PORT="$(echo "$PORT_LINE" | sed 's/bands__146__port=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      case "$PORT" in
        "TOP")
          Radio1=ON
        ;;
        "BOTTOM")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_PORT=$(whiptail --title "Select the new 146 MHz Band Tuner Port" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "TOP" "Top Tuner Port    (Socket A)" $Radio1 \
        "BOTTOM" "Bottom Tuner Port (Socket B)" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    146:/!b;n;n;n;n;n;c\        port: $NEW_PORT" /home/pi/ryde/config.yaml
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__146__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 146 MHz Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    146:/!b;n;n;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;
    "437")
      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__437__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 437 Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    437:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__437__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 437 MHz Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    437:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    437:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__437__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 437 MHz Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    437:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the polarity
      POL_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437__pol=')"
      POL="$(echo "$POL_LINE" | sed 's/bands__437__pol=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      Radio3=OFF
      case "$POL" in
        "NONE")
          Radio1=ON
        ;;
        "VERTICAL")
          Radio2=ON
        ;;
        "HORIZONTAL")
          Radio3=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_POL=$(whiptail --title "Select the new 437 MHz Band Polarity" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "NONE" "No LNB Voltage" $Radio1 \
        "VERTICAL" "Vertical Polarity 13 Volts" $Radio2 \
        "HORIZONTAL" "Horizontal Polarity 18 Volts" $Radio3 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    437:/!b;n;n;n;n;c\        pol: $NEW_POL" /home/pi/ryde/config.yaml
      fi

      # Read and trim the port
      PORT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437__port=')"
      PORT="$(echo "$PORT_LINE" | sed 's/bands__437__port=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      case "$PORT" in
        "TOP")
          Radio1=ON
        ;;
        "BOTTOM")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_PORT=$(whiptail --title "Select the new 437 MHz Band Tuner Port" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "TOP" "Top Tuner Port    (Socket A)" $Radio1 \
        "BOTTOM" "Bottom Tuner Port (Socket B)" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    437:/!b;n;n;n;n;n;c\        port: $NEW_PORT" /home/pi/ryde/config.yaml
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__437__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 437 MHz Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    437:/!b;n;n;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;
    "1255")
      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__1255__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__1255__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 1255 Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    1255:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__1255__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__1255__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 1255 MHz Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    1255:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    1255:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__1255__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__1255__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 1255 MHz Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    1255:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the polarity
      POL_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__1255__pol=')"
      POL="$(echo "$POL_LINE" | sed 's/bands__1255__pol=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      Radio3=OFF
      case "$POL" in
        "NONE")
          Radio1=ON
        ;;
        "VERTICAL")
          Radio2=ON
        ;;
        "HORIZONTAL")
          Radio3=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_POL=$(whiptail --title "Select the new 1255 MHz Band Polarity" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "NONE" "No LNB Voltage" $Radio1 \
        "VERTICAL" "Vertical Polarity 13 Volts" $Radio2 \
        "HORIZONTAL" "Horizontal Polarity 18 Volts" $Radio3 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    1255:/!b;n;n;n;n;c\        pol: $NEW_POL" /home/pi/ryde/config.yaml
      fi

      # Read and trim the port
      PORT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__1255__port=')"
      PORT="$(echo "$PORT_LINE" | sed 's/bands__1255__port=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      case "$PORT" in
        "TOP")
          Radio1=ON
        ;;
        "BOTTOM")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_PORT=$(whiptail --title "Select the new 1255 MHz Band Tuner Port" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "TOP" "Top Tuner Port    (Socket A)" $Radio1 \
        "BOTTOM" "Bottom Tuner Port (Socket B)" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    1255:/!b;n;n;n;n;n;c\        port: $NEW_PORT" /home/pi/ryde/config.yaml
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__1255__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__1255__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 1255 MHz Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    1255:/!b;n;n;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;
    "2400")
      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__2400__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__2400__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 2400 Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    2400:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__2400__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__2400__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 2400 MHz Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    2400:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    2400:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__2400__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__2400__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 2400 MHz Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    2400:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the polarity
      POL_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__2400__pol=')"
      POL="$(echo "$POL_LINE" | sed 's/bands__2400__pol=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      Radio3=OFF
      case "$POL" in
        "NONE")
          Radio1=ON
        ;;
        "VERTICAL")
          Radio2=ON
        ;;
        "HORIZONTAL")
          Radio3=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_POL=$(whiptail --title "Select the new 2400 MHz Band Polarity" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "NONE" "No LNB Voltage" $Radio1 \
        "VERTICAL" "Vertical Polarity 13 Volts" $Radio2 \
        "HORIZONTAL" "Horizontal Polarity 18 Volts" $Radio3 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    2400:/!b;n;n;n;n;c\        pol: $NEW_POL" /home/pi/ryde/config.yaml
      fi

      # Read and trim the port
      PORT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__2400__port=')"
      PORT="$(echo "$PORT_LINE" | sed 's/bands__2400__port=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      case "$PORT" in
        "TOP")
          Radio1=ON
        ;;
        "BOTTOM")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_PORT=$(whiptail --title "Select the new 2400 MHz Band Tuner Port" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "TOP" "Top Tuner Port    (Socket A)" $Radio1 \
        "BOTTOM" "Bottom Tuner Port (Socket B)" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    2400:/!b;n;n;n;n;n;c\        port: $NEW_PORT" /home/pi/ryde/config.yaml
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__2400__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__2400__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 2400 MHz Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    2400:/!b;n;n;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;
    "3400")
      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__3400__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__3400__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 3400 Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    3400:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__3400__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__3400__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 3400 MHz Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    3400:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    3400:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__3400__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__3400__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 3400 MHz Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency (normal)" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    3400:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the polarity
      POL_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__3400__pol=')"
      POL="$(echo "$POL_LINE" | sed 's/bands__3400__pol=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      Radio3=OFF
      case "$POL" in
        "NONE")
          Radio1=ON
        ;;
        "VERTICAL")
          Radio2=ON
        ;;
        "HORIZONTAL")
          Radio3=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_POL=$(whiptail --title "Select the new 3400 MHz Band Polarity" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "NONE" "No LNB Voltage" $Radio1 \
        "VERTICAL" "Vertical Polarity 13 Volts" $Radio2 \
        "HORIZONTAL" "Horizontal Polarity 18 Volts" $Radio3 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    3400:/!b;n;n;n;n;c\        pol: $NEW_POL" /home/pi/ryde/config.yaml
      fi

      # Read and trim the port
      PORT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__3400__port=')"
      PORT="$(echo "$PORT_LINE" | sed 's/bands__3400__port=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      case "$PORT" in
        "TOP")
          Radio1=ON
        ;;
        "BOTTOM")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_PORT=$(whiptail --title "Select the new 3400 MHz Band Tuner Port" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "TOP" "Top Tuner Port    (Socket A)" $Radio1 \
        "BOTTOM" "Bottom Tuner Port (Socket B)" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    3400:/!b;n;n;n;n;n;c\        port: $NEW_PORT" /home/pi/ryde/config.yaml
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__3400__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__3400__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 3400 MHz Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    3400:/!b;n;n;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;
    "5760")
      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__5760__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__5760__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 5760 Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    5760:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__5760__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__5760__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 5760 MHz Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    5760:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    5760:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__5760__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__5760__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 5760 MHz Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency (normal)" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    5760:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the polarity
      POL_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__5760__pol=')"
      POL="$(echo "$POL_LINE" | sed 's/bands__5760__pol=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      Radio3=OFF
      case "$POL" in
        "NONE")
          Radio1=ON
        ;;
        "VERTICAL")
          Radio2=ON
        ;;
        "HORIZONTAL")
          Radio3=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_POL=$(whiptail --title "Select the new 5760 MHz Band Polarity" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "NONE" "No LNB Voltage" $Radio1 \
        "VERTICAL" "Vertical Polarity 13 Volts" $Radio2 \
        "HORIZONTAL" "Horizontal Polarity 18 Volts" $Radio3 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    5760:/!b;n;n;n;n;c\        pol: $NEW_POL" /home/pi/ryde/config.yaml
      fi

      # Read and trim the port
      PORT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__5760__port=')"
      PORT="$(echo "$PORT_LINE" | sed 's/bands__5760__port=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      case "$PORT" in
        "TOP")
          Radio1=ON
        ;;
        "BOTTOM")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_PORT=$(whiptail --title "Select the new 5760 MHz Band Tuner Port" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "TOP" "Top Tuner Port    (Socket A)" $Radio1 \
        "BOTTOM" "Bottom Tuner Port (Socket B)" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    5760:/!b;n;n;n;n;n;c\        port: $NEW_PORT" /home/pi/ryde/config.yaml
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__5760__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__5760__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 5760 MHz Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    5760:/!b;n;n;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;
    "10368")
      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__10368__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__10368__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 10368 Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    10368:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__10368__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__10368__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 10368 MHz Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    10368:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    10368:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__10368__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__10368__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 10368 MHz Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency (normal)" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    10368:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the polarity
      POL_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__10368__pol=')"
      POL="$(echo "$POL_LINE" | sed 's/bands__10368__pol=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      Radio3=OFF
      case "$POL" in
        "NONE")
          Radio1=ON
        ;;
        "VERTICAL")
          Radio2=ON
        ;;
        "HORIZONTAL")
          Radio3=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_POL=$(whiptail --title "Select the new 10368 MHz Band Polarity" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "NONE" "No LNB Voltage" $Radio1 \
        "VERTICAL" "Vertical Polarity 13 Volts" $Radio2 \
        "HORIZONTAL" "Horizontal Polarity 18 Volts" $Radio3 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    10368:/!b;n;n;n;n;c\        pol: $NEW_POL" /home/pi/ryde/config.yaml
      fi

      # Read and trim the port
      PORT_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__10368__port=')"
      PORT="$(echo "$PORT_LINE" | sed 's/bands__10368__port=\"//' | sed 's/\"//')"
      Radio1=OFF
      Radio2=OFF
      case "$PORT" in
        "TOP")
          Radio1=ON
        ;;
        "BOTTOM")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      NEW_PORT=$(whiptail --title "Select the new 10368 MHz Band Tuner Port" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "TOP" "Top Tuner Port    (Socket A)" $Radio1 \
        "BOTTOM" "Bottom Tuner Port (Socket B)" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    10368:/!b;n;n;n;n;n;c\        port: $NEW_PORT" /home/pi/ryde/config.yaml
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__10368__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__10368__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 10368 MHz Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    10368:/!b;n;n;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;

    "146T")

      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146T__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__146T__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 146T Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    146T:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146T__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__146T__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 146 MHz DVB-T Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    146T:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    146T:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146T__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__146T__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 146 MHz DVB-T Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency (normal)" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    146T:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__146T__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__146T__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 146 MHz DVB-T Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    146T:/!b;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;

    "437T")

      # Read and trim the source
      SOURCE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437T__source=')"
      SOURCE="$(echo "$SOURCE_LINE" | sed 's/bands__437T__source=\"//' | sed 's/\"//')"

      Radio1=OFF
      Radio2=OFF

      case "$SOURCE" in
        "LONGMYND")
          Radio1=ON
        ;;
        "COMBITUNER")
          Radio2=ON
        ;;
        *)
          Radio1=ON
        ;;
      esac
      SOURCE=$(whiptail --title "Select the Source (tuner) for the 437T Band" --radiolist \
        "Highlight choice, select with space bar and then press enter" 20 78 5 \
        "LONGMYND" "DVB-S or DVB-S2 using a MiniTiouner" $Radio1 \
        "COMBITUNER" "DVB-T using a Knucker Tuner" $Radio2 \
        3>&2 2>&1 1>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    437T:/!b;n;c\        source: $SOURCE" /home/pi/ryde/config.yaml
      fi

      # Read and trim the LO frequency
      LO_FREQ_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437T__lofreq=')"
      LO_FREQ="$(echo "$LO_FREQ_LINE" | sed 's/bands__437T__lofreq=\"//' | sed 's/\"//')"
      LO_FREQ=$(whiptail --inputbox "Enter the new 437 MHz DVB-T Band LO frequency in kHz (for example 9750000)" 8 78 $LO_FREQ --title "LO Frequency Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    437T:/!b;n;n;c\        lofreq: $LO_FREQ" /home/pi/ryde/config.yaml
        if [ "$LO_FREQ" == "0" ]; then  # set LO Side to SUM
          sed -i "/    437T:/!b;n;n;n;c\        loside: SUM" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the LO side
      LO_SIDE_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437T__loside=')"
      LO_SIDE="$(echo "$LO_SIDE_LINE" | sed 's/bands__437T__loside=\"//' | sed 's/\"//')"
      if [ "$LO_FREQ" != "0" ]; then  # Set LO side
        Radio1=OFF
        Radio2=OFF
        Radio3=OFF
        case "$LO_SIDE" in
          "LOW")
            Radio1=ON
          ;;
          "HIGH")
            Radio2=ON
          ;;
          "SUM")
            Radio3=ON
          ;;
          *)
            Radio1=ON
          ;;
        esac
        LO_SIDE=$(whiptail --title "Select the LO Configuration for the 437 MHz DVB-T Band" --radiolist \
          "Highlight choice, select with space bar and then press enter" 20 78 5 \
          "LOW" "Tuner Frequency = Signal Frequency - LO Frequency (normal)" $Radio1 \
          "HIGH" "Tuner Frequency = LO Frequency - Signal Frequency" $Radio2 \
          "SUM" "Tuner Frequency = LO Frequency + Signal Frequency" $Radio3 \
          3>&2 2>&1 1>&3)
        if [ $? -eq 0 ]; then
          sed -i "/    437T:/!b;n;n;n;c\        loside: $LO_SIDE" /home/pi/ryde/config.yaml
        fi
      fi

      # Read and trim the GPIO Band Setting
      GPIOID_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'bands__437T__gpioid=')"
      GPIOID="$(echo "$GPIOID_LINE" | sed 's/bands__437T__gpioid=\"//' | sed 's/\"//')"
      GPIOID=$(whiptail --inputbox "Enter the new 437 MHz DVB-T Band GPIO setting (0 - 7)" 8 78 \
      $GPIOID --title "Band GPIO Entry Menu" 3>&1 1>&2 2>&3)
      if [ $? -eq 0 ]; then
        sed -i "/    437T:/!b;n;n;n;n;c\        gpioid: $GPIOID" /home/pi/ryde/config.yaml
      fi
    ;;

    "menu_exit")
    ;;
  esac
}


do_Set_Defaults()
{
  # Read and trim the current start-up preset     default="*preset01"
  DEFAULT_PRESET_LINE="$(parse_yaml /home/pi/ryde/config.yaml | grep 'default=')"
  DEFAULT_PRESET="$(echo "$DEFAULT_PRESET_LINE" | sed 's/default=\"//' | sed 's/\"//')"

  Radio1=OFF
  Radio2=OFF
  Radio3=OFF
  Radio4=OFF
  Radio5=OFF
  Radio6=OFF
  Radio7=OFF
  Radio8=OFF
  Radio9=OFF
  Radio10=OFF
  Radio11=OFF
  Radio12=OFF
  Radio13=OFF
  Radio14=OFF

  case "$DEFAULT_PRESET" in
    "*preset01")
      Radio1=ON
    ;;
    "*preset02")
      Radio2=ON
    ;;
    "*preset03")
      Radio3=ON
    ;;
    "*preset04")
      Radio4=ON
    ;;
    "*preset05")
      Radio5=ON
    ;;
    "*preset06")
      Radio6=ON
    ;;
    "*preset07")
      Radio7=ON
    ;;
    "*preset08")
      Radio8=ON
    ;;
    "*preset09")
      Radio9=ON
    ;;
    "*preset10")
      Radio10=ON
    ;;
    "*presethv")
      Radio11=ON
    ;;
    "*presetjv")
      Radio12=ON
    ;;
    "*presetkm")
      Radio13=ON
    ;;
    "*presetsq")
      Radio14=ON
    ;;
    *)
      Radio1=ON
    ;;
  esac
  
  NEW_DEFAULT_PRESET=$(whiptail --title "Select the new Default Preset" --radiolist \
    "Highlight choice, select with space bar and then press enter" 21 78 14 \
    "QO-100_Beacon" "The QO-100_Beacon preset" $Radio1 \
    "QO-100_9.25_333" "The QO-100_9.25_333 preset" $Radio2 \
    "QO-100_Custom" "The QO-100_Custom preset" $Radio3 \
    "QO-100_Scan" "The QO-100_Scan preset" $Radio4 \
    "146.5_MHz_125" "The 146.5_MHz_125 preset" $Radio5 \
    "146.5_MHz_333" "The 146.5_MHz_333 preset" $Radio6 \
    "437.0_MHz_333" "The 437.0_MHz_333 preset" $Radio7 \
    "437.0_MHz_1000" "The 437.0_MHz_1000 preset" $Radio8 \
    "1255_MHz_333" "The 1255_MHz_333 preset" $Radio9 \
    "1255_MHz_Custom" "The 1255_MHz_Custom preset" $Radio10 \
    "GB3HV Stream" "The GB3HV Repeater Stream" $Radio11 \
    "GB3JV Stream" "The GB3JV Repeater Stream" $Radio12 \
    "GB3KM Stream" "The GB3KM Repeater Stream" $Radio13 \
    "GB3SQ Stream" "The GB3SQ Repeater Stream" $Radio14 \
     3>&2 2>&1 1>&3)
  if [ $? -eq 0 ]; then
    case "$NEW_DEFAULT_PRESET" in
      "QO-100_Beacon") NEW_DEFAULT_PRESET="*preset01" ;;
      "QO-100_9.25_333") NEW_DEFAULT_PRESET="*preset02" ;;
      "QO-100_Custom") NEW_DEFAULT_PRESET="*preset03" ;;
      "QO-100_Scan") NEW_DEFAULT_PRESET="*preset04" ;;
      "146.5_MHz_125") NEW_DEFAULT_PRESET="*preset05" ;;
      "146.5_MHz_333") NEW_DEFAULT_PRESET="*preset06" ;;
      "437.0_MHz_333") NEW_DEFAULT_PRESET="*preset07" ;;
      "437.0_MHz_1000") NEW_DEFAULT_PRESET="*preset08" ;;
      "1255_MHz_333") NEW_DEFAULT_PRESET="*preset09" ;;
      "1255_MHz_Custom") NEW_DEFAULT_PRESET="*preset10" ;;
      "GB3HV Stream") NEW_DEFAULT_PRESET="*presethv" ;;
      "GB3JV Stream") NEW_DEFAULT_PRESET="*presetjv" ;;
      "GB3KM Stream") NEW_DEFAULT_PRESET="*presetkm" ;;
      "GB3SQ Stream") NEW_DEFAULT_PRESET="*presetsq" ;;
    esac
    sed -i "/^default: /c\default: $NEW_DEFAULT_PRESET" /home/pi/ryde/config.yaml
  fi
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

do_Comp_Vid_Aspect_4_3()
{
  grep -q "sdtv_aspect=1" /boot/config.txt
  if [ $? -ne 0 ]; then  #  "sdtv_aspect=1" is not there so change it
    sudo sed -i 's/sdtv_aspect=3/sdtv_aspect=1/' /boot/config.txt
  fi
}

do_Comp_Vid_Aspect_16_9()
{
  grep -q "sdtv_aspect=3" /boot/config.txt
  if [ $? -ne 0 ]; then  #  "sdtv_aspect=3" is not there so change it
    sudo sed -i 's/sdtv_aspect=1/sdtv_aspect=3/' /boot/config.txt
  fi
}


do_Comp_Vid_Aspect()
{
  Radio1=OFF
  Radio2=OFF
  Radio3=OFF

  grep -q "sdtv_aspect=1" /boot/config.txt
  if [ $? -eq 0 ]; then  #  "sdtv_aspect=1" 4:3
    Radio1=ON
  else
    grep -q "sdtv_aspect=3" /boot/config.txt
    if [ $? -eq 0 ]; then  #  "sdtv_aspect=3" 16:9
      Radio2=ON
    else
      Radio3=ON
    fi
  fi

  NEW_VA=$(whiptail --title "Choose the Composite Video Aspect Ratio" --radiolist \
    "Highlight choice, select with space bar and then press enter" 20 78 5 \
    "4:3" "4:3 for older displays" $Radio1 \
    "16:9" "16:9 for widescreen displays" $Radio2 \
    "Not Set" "Defaults to 4:3" $Radio3 \
    3>&2 2>&1 1>&3)
  if [ $? -eq 0 ]; then
    case "$NEW_VA" in
      "4:3")
        do_Comp_Vid_Aspect_4_3
      ;;
      "16:9")
        do_Comp_Vid_Aspect_16_9
      ;;
    esac
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

  # Ask about aspect ratio
  do_Comp_Vid_Aspect
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

  # Ask about aspect ratio
  do_Comp_Vid_Aspect
}

do_Audio_Jack()
{
  Radio1=OFF
  Radio2=OFF
  Radio3=OFF
  Radio4=OFF

  grep -q "^#        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Headphones,DEV=0 '" \
    /home/pi/ryde/rydeplayer/player.py
  if [ $? -eq 0 ]; then  #  Line commented, so HDMI currently selected
    Radio1=ON
  else
    grep -q "^        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Headphones,DEV=0 '" \
      /home/pi/ryde/rydeplayer/player.py
    if [ $? -eq 0 ]; then  #  RPi Jack currently selected
      Radio2=ON
    else
      grep -q "^        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Device,DEV=0 '" \
        /home/pi/ryde/rydeplayer/player.py
      if [ $? -eq 0 ]; then  #  USB Dongle currently selected
        Radio3=ON
      else
        Radio4=ON
      fi
    fi
  fi

  AUDIO_JACK=$(whiptail --title "Choose the Audio Output Port" --radiolist \
    "Highlight choice, select with space bar and then press enter" 20 78 6 \
    "HDMI" "Audio on HDMI" $Radio1 \
    "RPi Jack" "Audio on the RPi 3.5 mm Jack" $Radio2 \
    "USB" "Audio on a White USB Dongle" $Radio3 \
    "Not Set" "Defaults to same as video" $Radio4 \
    3>&2 2>&1 1>&3)
  if [ $? -eq 0 ]; then
    case "$AUDIO_JACK" in
      "HDMI")
        sed -i "/--alsa-audio-device/c\#        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Headphones,DEV=0 '" \
          /home/pi/ryde/rydeplayer/player.py
      ;;
      "RPi Jack")
        sed -i "/--alsa-audio-device/c\        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Headphones,DEV=0 '" \
          /home/pi/ryde/rydeplayer/player.py
      ;;
      "USB")
        sed -i "/--alsa-audio-device/c\        vlcArgs += '--gain 4 --alsa-audio-device hw:CARD=Device,DEV=0 '" \
          /home/pi/ryde/rydeplayer/player.py
      ;;
    esac
  fi
  REBOOT_REQUIRED=no
}


do_video_change()
{
  REBOOT_REQUIRED=yes
  menuchoice=$(whiptail --title "Video Output Menu" --menu "Select Choice" 16 78 6 \
    "1 Normal HDMI" "Recommended Mode"  \
    "2 HDMI Safe Mode" "Use for HDMI Troubleshooting" \
    "3 PAL Composite Video" "Use the RPi Video Output Jack" \
    "4 NTSC Composite Video" "Use the RPi Video Output Jack" \
    "5 Audio Output" "Change Audio Output Destination" \
      3>&2 2>&1 1>&3)
    case "$menuchoice" in
        1\ *) do_Norm_HDMI ;;
        2\ *) do_Safe_HDMI ;;
        3\ *) do_Comp_Vid_PAL ;;
        4\ *) do_Comp_Vid_NTSC ;;
        5\ *) do_Audio_Jack ;;
    esac

  if [ "$REBOOT_REQUIRED" == "yes" ]; then
    menuchoice=$(whiptail --title "Reboot Now?" --menu "Reboot to Apply Changes?" 16 78 10 \
      "1 Yes" "Immediate Reboot"  \
      "2 No" "Apply changes at next Reboot" \
        3>&2 2>&1 1>&3)
      case "$menuchoice" in
        1\ *) do_Reboot ;;
        2\ *) do_Nothing ;;
      esac
  fi
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
  menuchoice=$(whiptail --title "Shutdown Menu" --menu "Select Choice and press enter" 16 78 4 \
    "1 Shutdown now" "Immediate Shutdown"  \
    "2 Reboot now" "Immediate Reboot" \
    "3 Exit to Linux" "Exit Menu to Command Prompt" \
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

  sudo killall longmynd >/dev/null 2>/dev/null

  sudo pkill rx.sh >/dev/null 2>/dev/null
  pgrep vlc >/dev/null 2>/dev/null
  if [[ "$?" == "0" ]]; then
    sleep 1
    sudo killall vlc >/dev/null 2>/dev/null
  fi
}


do_receive()
{
  /home/pi/ryde-build/rx.sh &

  # Wait here receiving until user presses a key
  whiptail --title "Receiving" --msgbox "Touch any key to stop receiving" 8 78
  do_stop
}


#********************************************* MAIN MENU *********************************
#************************* Execution of Console Menu starts here *************************

status=0
STREAM="oscar100net"

# Stop the Receiver
do_stop

# Disable the Watchdog
sudo killall watchdog.sh >/dev/null 2>/dev/null

# Loop round main menu
while [ "$status" -eq 0 ] 
  do
    # Display main menu

    menuchoice=$(whiptail --title "BATC Ryde Receiver Main Menu" --menu "Select Choice and press enter:" 20 78 13 \
	"0 Receive" "Start the Ryde Receiver" \
    "1 Stop" "Stop the Ryde Receiver" \
    "2 Start-up" "Set the start-up Preset" \
    "3 Bands" "Set the band details such as LNB Offset" \
    "4 Presets" "Set the details for each preset" \
	"5 Video" "Select the Video and Audio Output Mode" \
	"6 Remote" "Select the Remote Control Type" \
	"7 IR Check" "View the IR Codes From a new Remote" \
    "8 Settings" "Advanced Settings" \
	"9 Utils" "Ryde Utilities and Stream Viewer" \
	"10 Update" "Check for Software Update" \
	"11 DVB-T RX" "Menu-driven DVB-T RX using Knucker Tuner"\
    "12 Shutdown" "Shutdown, Reboot or exit to the Linux command prompt" \
 	3>&2 2>&1 1>&3)

        case "$menuchoice" in
	    0\ *) do_receive   ;;
        1\ *) do_stop   ;;
        2\ *) do_Set_Defaults ;;
        3\ *) do_Set_Bands ;;
        4\ *) do_Set_Presets ;;
	    5\ *) do_video_change ;;
   	    6\ *) do_Set_RC_Type ;;
   	    7\ *) do_Check_RC_Codes ;;
	    8\ *) do_Settings ;;
        9\ *) do_utils ;;
	    10\ *) do_update ;;
	    11\ *) do_dvbt ;;
        12\ *) do_shutdown_menu ;;
            *)

        # Display exit message if user jumps out of menu
        whiptail --title "Exiting to Linux Prompt" --msgbox "To return to the menu system, type menu" 8 78

        # Set status to exit
        status=1

        # Sleep while user reads message, then exit
        #sleep 1
      exit ;;
    esac
  done
exit