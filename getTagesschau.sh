#!/bin/sh -eu

#set -x

# Downloads the latest 20:00 o'clock Tagesschau.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.



#### ERRATA ####
# 1. This script will break if the Tagesschau changes its backend. Like, at all.
# 2. You need to compensate for your time zone when calling the script yourself; it is designed to be called at a reasonable time and will spam your syslog.



# get name of this script
scriptname=$(basename "$0")

# get current date, formatted in the Tagesschau file naming scheme
dateTagesschau=$(date '+%Y%m%d')

# get hour of day
hour=$(date '+%H')



# if previous instances of the script didn't manage to grab the newest Tagesschau by midnight, we give up.
if [ "$hour" = 02 ]; then # 2 o'clock UTC == midnight in Germany (summer time)
    echo 'Unable to download the new Tagesschau. Giving up.' | logger -t "$scriptname"
#   exit cleanly
    exit 0
fi

# download latest 20:00 Tagesschau
echo 'Starting...' | logger -t "$scriptname"

# The link to the download section of the current Tagesschau has to be constructed by "scraping" the Tagesschau website.
#id=$(curl -s https://www.tagesschau.de/multimedia/sendung/tagesschau_20_uhr | grep "teaser__link" | grep -o '/tagesschau_20_uhr/.*\.html' | sed 's|/tagesschau_20_uhr/\(.*\)\.html|\1|')
#subLink=$(curl -s https://www.tagesschau.de/multimedia/sendung/tagesschau_20_uhr/"$id".html | tr ';' '\n' | grep -o 'video/.*\.webm\.h264\.mp4' | sed 's|video/\(.*\)\.webm\.h264\.mp4|\1|' | grep -v ',' | grep "$dateTagesschau")
#link=https://media.tagesschau.de/video/"$subLink".webs.h264.mp4

id=$(curl -s https://www.tagesschau.de/multimedia/sendung/tagesschau_20_uhr | grep -A 1 "teaser__link" | grep -o '/tagesschau_20_uhr/.*\.html' | sed 's|/tagesschau_20_uhr/\(.*\)\.html|\1|')
subLink=$(curl -s https://www.tagesschau.de/multimedia/sendung/tagesschau_20_uhr/"$id".html | tr ';' '\n' | grep -o 'video/.*\.webm\.h264\.mp4' | sed 's|video/\(.*\)\.webm\.h264\.mp4|\1|' | grep -v ',')

# If no Tagesschau has been uploaded with today's timestamp, the $subLink variable will not contain the current date.
if echo "$subLink" | grep -q "$dateTagesschau"; then
    subLink=$(echo "$subLink" | grep "$dateTagesschau")
    link=https://media.tagesschau.de/video/"$subLink".webs.h264.mp4
else
    echo 'No new Tagesschau yet. Trying again in one minute.' | logger -t "$scriptname"
#   wait 60 seconds
    sleep 60
#   start a new instance of this script and immediately exit the current one cleanly
    "$0" & exit 0
fi

echo 'Found the new Tagesschau. Downloading.' | logger -t "$scriptname"
curl -s "$link" > /tmp/currentTagesschau.m4a
echo 'Download finished. Converting video to mp3.' | logger -t "$scriptname"
# convert video to mp3
ffmpeg -y -i /tmp/currentTagesschau.m4a -acodec libmp3lame -ac 2 -ab 192k /tmp/playNew.mp3
echo 'Conversion finished. Replacing current file staged for playback.' | logger -t "$scriptname"
# replace the current file staged for playback with the new one
mv -f /tmp/playNew.mp3 /usr/local/sbin/tagesschau/files/play.mp3
echo 'Replaced file staged for playback.' | logger -t "$scriptname"
# wrapping up
echo 'Removing temporary file.' | logger -t "$scriptname"
rm /tmp/currentTagesschau.m4a
echo 'Newest Tagesschau is ready to play. Exiting.' | logger -t "$scriptname" 
# exit cleanly
exit 0
