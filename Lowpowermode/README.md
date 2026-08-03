You will have to create 2 files:

But first notice that you have to change: "com.'users_macbook_name'.battery_lpm.plist" according to your users name.

•	The shell script, for example:  /usr/local/bin/battery_lpm.sh .
•	The launchd plist, for example:  /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist .

The script does the battery checking, and the plist tells macOS to run that script automatically at boot.

Step 1: Save the script

Open Terminal and create the script file:  

sudo nano /usr/local/bin/battery_lpm.sh

Paste this script:

#!/bin/bash

LOGFILE="/var/log/battery_lpm.log"
LOW_THRESHOLD=30

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

get_battery_pct() {
    pmset -g batt | grep -Eo '[0-9]+%' | cut -d% -f1 | head -n 1
}

get_power_source() {
    pmset -g batt | grep -q "AC Power" && echo "AC" || echo "Battery"
}

get_lpm_status() {
    pmset -g | awk '/lowpowermode/ {print $2; exit}'
}

log "battery_lpm started"

while true; do
    BATT_PCT="$(get_battery_pct)"
    POWER_SRC="$(get_power_source)"
    LPM_STATUS="$(get_lpm_status)"

    if [ -z "$BATT_PCT" ] || [ -z "$LPM_STATUS" ]; then
        log "unable to read status"
        sleep 120
        continue
    fi

    log "check: source=${POWER_SRC}, battery=${BATT_PCT}%, lowpowermode=${LPM_STATUS}"

    if [ "$POWER_SRC" = "Battery" ] && [ "$BATT_PCT" -le "$LOW_THRESHOLD" ] && [ "$LPM_STATUS" -eq 0 ]; then
        log "enabling lowpowermode on battery"
        /usr/bin/sudo /usr/bin/pmset -b lowpowermode 1
    elif [ "$POWER_SRC" = "AC" ] && [ "$LPM_STATUS" -eq 1 ]; then
        log "disabling lowpowermode on AC"
        /usr/bin/sudo /usr/bin/pmset -c lowpowermode 0
    fi

    sleep 120
done

Save and exit with:
•	 Ctrl + O 
•	 Enter 
•	 Ctrl + X 
Then make it executable and root-owned:

sudo chmod +x /usr/local/bin/battery_lpm.sh
sudo chown root:wheel /usr/local/bin/battery_lpm.sh


That makes the script runnable and keeps ownership consistent for a system service.

Step 2: Save the plist

Create the launchd file:

sudo nano /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist

Paste this plist:

<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.'users_macbook_name'.battery_lpm</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/usr/local/bin/battery_lpm.sh</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/var/log/battery_lpm.out.log</string>

    <key>StandardErrorPath</key>
    <string>/var/log/battery_lpm.err.log</string>
</dict>
</plist>

Save and exit the same way:
•	 Ctrl + O 
•	 Enter 
•	 Ctrl + X 
Then set the required ownership and permissions:

sudo chown root:wheel /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist
sudo chmod 644 /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist

That is the normal permission setup for a LaunchDaemon plist in  /Library/LaunchDaemons/ .

Step 3: Validate the plist

Check that the plist is valid XML:

plutil -lint /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist

If it says  OK , the file is fine.

Step 4: Load the daemon

Load it into launchd:

sudo launchctl bootstrap system /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist

Then start it immediately:

sudo launchctl kickstart -k system/com.'users_macbook_name'.battery_lpm

That registers the job as a system service and starts it right away.

Step 5: Confirm it is running

Check the loaded job:

sudo launchctl list | grep battery_lpm

Check the logs:

cat /var/log/battery_lpm.log
cat /var/log/battery_lpm.out.log
cat /var/log/battery_lpm.err.log

If it is working, the log should show startup and battery check messages.
What each file does
•	 /usr/local/bin/battery_lpm.sh  is the actual logic that reads battery status and runs  pmset .
•	 /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist  tells macOS to run that script automatically as a root daemon.
•	 /var/log/battery_lpm.log  records your custom status messages.
•	 /var/log/battery_lpm.out.log  and  /var/log/battery_lpm.err.log  capture standard output and errors from launchd.
What to edit later
If you want to change the battery threshold, edit this line in the script:

LOW_THRESHOLD=30

If you want a different check interval, change:

sleep 120

After editing, reload the daemon:

sudo launchctl bootout system /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist
sudo launchctl bootstrap system /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist
sudo launchctl kickstart -k system/com.'users_macbook_name't.battery_lpm


Temporary stop:

sudo launchctl stop system/com.'users_macbook_name'.battery_lpm

If that does not work or the job restarts, kill the current process:

sudo launchctl kill SIGTERM system/com.'users_macbook_name'.battery_lpm

or, if needed:

sudo launchctl kill SIGKILL system/com.'users_macbook_name'.battery_lpm

These are short-term stops; the job can still be restarted by launchd depending on how it is configured.

Full stop:

sudo launchctl bootout system /Library/LaunchDaemons/com.'users_macbook_name'.battery_lpm.plist

That removes it from launchd and prevents it from running until you load it again.

Confirm it is gone:

sudo launchctl list | grep battery_lpm

If nothing appears, it is no longer loaded.
