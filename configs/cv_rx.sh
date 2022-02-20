#!/bin/bash

# Script to set the conditions for VLC Video Player and to launch it

#echo "Making Sure VLC is not already running"

sudo killall vlc >/dev/null 2>/dev/null

sleep 1

#echo "Restaring VLC"

# If a Fushicai EasyCap, adjust the contrast to prevent white crushing
# Default is 464 (scale 0 - 1023) which crushes whites
lsusb | grep -q '1b71:3002'
if [ $? == 0 ]; then   ## Fushicai USBTV007
  ECCONTRAST="contrast=380"
else
  ECCONTRAST=" "
fi

while true; do

  # If VLC is not running, start it
  pgrep vlc >/dev/null 2>/dev/null
  if [[ "$?" != "0" ]]; then
    v4l2-ctl -d /dev/video0 --set-standard=6 >/dev/null 2>/dev/null

    (cvlc -I rc --rc-host 127.0.0.1:1111 \
      v4l2:///dev/video0:width=720:height=576 :input-slave=alsa://plughw:CARD=usbtv,DEV=0 \
      --aspect-ratio 16:9 \
      --gain 3 --alsa-audio-device hw:CARD=b1,DEV=0 \
      >/dev/null 2>/dev/null) &

    sleep 0.7
    v4l2-ctl -d /dev/video0 --set-ctrl "$ECCONTRAST" >/dev/null 2>/dev/null

    # Give VLC 5 seconds to settle if just started
    sleep 5
  fi

  #Check again in 15 seconds
  sleep 15
done

exit


# arecord -f S16_LE -c 2 -r 48000 -D hw:CARD=usbtv,DEV=0 | aplay -D hw:CARD=b1,DEV=0 # works

# arecord -f S16_LE -c 2 -r 48000 -D hw:CARD=USB20,DEV=0 | aplay -D hw:CARD=b1,DEV=0 # doesn't
