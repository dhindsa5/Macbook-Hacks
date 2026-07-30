#!/bin/bash

LOGFILE="/var/log/battery_lpm.log"
LOW_THRESHOLD=30
HIGH_THRESHOLD=40

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
    elif [ "$POWER_SRC" = "Battery" ] && [ "$BATT_PCT" -ge "$HIGH_THRESHOLD" ] && [ "$LPM_STATUS" -eq 1 ]; then
        log "disabling lowpowermode above threshold on battery"
        /usr/bin/sudo /usr/bin/pmset -b lowpowermode 0
    fi

    sleep 120
done
