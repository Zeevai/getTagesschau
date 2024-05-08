#!/bin/sh -eu

#set -x # Toggle for testing purposes

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
# 0. This should really be done in Python using Beautiful Soup. This script is a training exercise in POSIX-compliance.
# 1. Since "set -o pipefail" isn't supported under POSIX, every pipe should be replaced by outputting to a temporary variable and then using that variable as the input for the next command to catch errors within pipes.
#    For the sake of everyone's sanity, this has not been implemented (yet).
# 2. This script will break if the Tagesschau changes its backend. Like, at all (already happened once).
# 3. You need to compensate for your time zone when calling the script; it is designed to be called at a reasonable time and will otherwise spam your syslog.
####



#### BEGINN ERROR LOGGING ####
# This section is an attempt to faithfully emulate the functionality of "exec 2> >(logger -t $(basename "$0"))" in POSIX.
# Since command substitution isn't POSIX-compliant, we end up with this.

log_error() {
    # Log each line of the error log file if it exists and is not empty
    if [ -s "$error_log" ]; then
        while IFS= read -r line; do
            logger -t "$scriptName" "Error: $line"
        done < "$error_log"
    fi
    # Clean up: Remove the temporary error log file if it exists
    rm -f "$error_log"
}

# Get the name of this script
scriptName=$(basename "$0")

# Create a temporary file for error logging
error_log=$(mktemp "/tmp/${scriptName}_error.log.XXXXXX")

# Redirect stderr to the error log file
exec 2>"$error_log"

# Trigger the error logger on exit and handle signals
trap 'log_error; exit' EXIT INT HUP TERM QUIT
#### END ERROR LOGGING ####



#### BEGIN INFO LOGGING ####
log() {
    echo "$1" | logger -t "$scriptName"
}
#### END INFO LOGGING ####



# Get current date, formatted in the Tagesschau file naming scheme
dateTagesschau=$(date '+%Y%m%d')

# Get hour of day
hour=$(date '+%H')

# If previous instances of the script didn't manage to grab the newest Tagesschau by midnight, we give up.
if [ "$hour" = 02 ]; then # 2 o'clock UTC == midnight in Germany (summer time). I did not compensate for DST vs non-DST yet, neither did I compensate for the time zone of the machine running this script.
    log 'Unable to download the new Tagesschau. Giving up.'
#   exit cleanly
    exit 0
fi

# Download latest 20:00 Tagesschau
log 'Starting...'

# Web scraping to find the URL of today's Tagesschau file. This is why web scraping should be done in Python.
id=$(curl -s https://www.tagesschau.de/multimedia/sendung/tagesschau_20_uhr | grep -A 1 "teaser__link" | grep -o '/tagesschau_20_uhr/.*\.html' | sed 's|/tagesschau_20_uhr/\(.*\)\.html|\1|')
subLink=$(curl -s https://www.tagesschau.de/multimedia/sendung/tagesschau_20_uhr/"$id".html | tr ';' '\n' | grep -o 'video/.*\.webm\.h264\.mp4' | sed 's|video/\(.*\)\.webm\.h264\.mp4|\1|' | grep -v ',')

# If no Tagesschau has been uploaded with today's timestamp, the $subLink variable will not contain the current date.
if echo "$subLink" | grep -q "$dateTagesschau"; then
    subLink=$(echo "$subLink" | grep "$dateTagesschau")
    link=https://media.tagesschau.de/video/"$subLink".webs.h264.mp4
else
    log 'No new Tagesschau yet. Trying again in one minute.'
#   Wait 60 seconds
    sleep 60
#   Start a new instance of this script and immediately exit the current one cleanly
    "$0" & exit 0
fi

log 'Found the new Tagesschau. Downloading.'
curl -s "$link" > /tmp/currentTagesschau.mp4
log 'Download finished. Converting video to mp3.'
# Convert video to mp3
ffmpeg -loglevel error -y -i /tmp/currentTagesschau.mp4 -acodec libmp3lame -ac 2 -ab 192k /tmp/playNew.mp3
log 'Conversion finished. Replacing current file staged for playback.'
# Replace the current file staged for playback with the new one. Source directory of this script needs to contain the dir "files".
mv -f /tmp/playNew.mp3 "$(dirname "$0")"/files/play.mp3
log 'Replaced file staged for playback.'
# Wrapping up
log 'Removing temporary file.'
rm /tmp/currentTagesschau.mp4
log 'Newest Tagesschau is ready to play. Exiting.'
# Exit cleanly
exit 0
