This project represents an exercise in POSIX-compliant shell scripting (meaning it should, theoretically, run in every unixoid shell, given the dependencies are met). It downloads today's 8 pm episode (if there is one yet) of the German news outlet Tagesschau by finding the direct link to the smallest available video file, downloading it and converting it to audio only. If there has not been a new episode at the time of running the script, it will try again until it either finds it or 2 o'clock AM UTC is reached (currently hard-coded). It logs the meaningful steps and every error to syslog. The commentary style is chosen to help others on their journey to learn shell scripting, POSIX or otherwise.

The error logging section is meant to be copy-pasted at the beginning of any shell script to enable logging to syslog, without any further modification required. Mind the comment about how to do it when strict POSIX-compliance is **not** needed.

#### Dependencies you may need to install:
- logger
- curl
- ffmpeg

#### Dependencies usually provided by the BusyBox:
- grep
- sed
- date
- mktemp
- mv
- rm
- sleep
- trap
- dirname
- basename

#### File System
The source directory of the script must contain a sub-directory "files". This is where the mp3 of today's Tagesschau will be stored.
