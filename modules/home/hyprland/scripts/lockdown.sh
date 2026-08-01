#!/usr/bin/env bash
# Lockdown: lid + battery policy for the locked session.
# Suspend/poweroff on battery, gated by lock duration and quickshell's keep-awake flag.

LOCK_SUSPEND_SECONDS=300
LOCK_POWEROFF_SECONDS=900

# quickshell keeps this file up to date whenever the toggle flips.
keep_awake() {
    local f
    f="$HOME/.local/state/quickshell/states.json"
    [ -f "$f" ] || return 1
    awk '{
        line = line $0
    } END {
        if (line ~ /"idle"[^{]*\{[^}]*"inhibit"[[:space:]]*:[[:space:]]*true/) exit 0
        exit 1
    }' "$f"
}

hctl() {
    local sock
    sock="$(ls -t "$XDG_RUNTIME_DIR"/hypr/*/.socket.sock 2>/dev/null | head -n1)"
    if [ -n "$sock" ]; then
        command hyprctl -s "$sock" "$@"
    fi
}

on_battery() {
    local s
    for s in /sys/class/power_supply/*/status; do
        [ -f "$s" ] && [ "$(cat "$s")" = "Discharging" ] && return 0
    done
    return 1
}

lid_closed() {
    local f
    f="$(ls /proc/acpi/button/lid/*/state 2>/dev/null | head -n1)"
    [ -n "$f" ] && grep -q closed "$f"
}

session_locked() {
    local sid
    sid="$(loginctl --no-legend list-sessions 2>/dev/null | awk '$4 == "seat0" { print $1; exit }')"
    [ -n "$sid" ] && [ "$(loginctl show-session "$sid" -p LockedHint 2>/dev/null | cut -d= -f2)" = "yes" ]
}

was_locked=false
lock_started=0
last_poll=$(date +%s)
while true; do
    sleep 2
    now=$(date +%s)

    # A large gap means we just resumed from suspend - restart the lock timer.
    if [ $((now - last_poll)) -gt 30 ]; then
        if session_locked; then
            lock_started=$now
        else
            was_locked=false
        fi
    fi

    if lid_closed; then
        hctl dispatch dpms off
    else
        hctl dispatch dpms on
    fi

    if session_locked; then
        if [ "$was_locked" != true ]; then
            lock_started=$now
        fi
        elapsed=$((now - lock_started))
        if on_battery && ! keep_awake; then
            if [ "$elapsed" -ge "$LOCK_POWEROFF_SECONDS" ]; then
                systemctl poweroff
            elif [ "$elapsed" -ge "$LOCK_SUSPEND_SECONDS" ] || lid_closed; then
                systemctl suspend
            fi
        fi
        was_locked=true
    else
        was_locked=false
    fi
    last_poll=$now
done
