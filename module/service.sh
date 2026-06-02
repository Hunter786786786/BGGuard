#!/system/bin/sh
# BGGuard v2.0 Service — CPU Friendly
# /proc only, no dumpsys, 60s interval, config-file based whitelist

D="/data/adb/bgguard"
LOG="$D/logs/bgguard.log"
KLOG="$D/logs/killed.log"
BGT="$D/bg_tracker"
ACT="$D/active_tracker"
CONF="$D/whitelist.conf"
PID_F="$D/service.pid"

KILL_TIMEOUT=120
FOOTPRINT_TIMEOUT=300
INTERVAL=60
OOM_LOCK=-900

log_i() { echo "[$(date '+%H:%M:%S')] [I] $1" >> "$LOG"; }
log_k() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [KILL] $1" >> "$KLOG"
    echo "[$(date '+%H:%M:%S')] [K] $1" >> "$LOG"
}
log_c() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CLEAN] $1" >> "$KLOG"
    echo "[$(date '+%H:%M:%S')] [C] $1" >> "$LOG"
}

# ── Whitelist থেকে protected packages পড়ে
load_whitelist() {
    WHITELIST=""
    [ -f "$CONF" ] || return
    while IFS= read -r line; do
        # Comment ও blank line skip
        echo "$line" | grep -qE '^\s*#|^\s*$' && continue
        pkg=$(echo "$line" | tr -d ' \r\n')
        [ -n "$pkg" ] && WHITELIST="$WHITELIST $pkg"
    done < "$CONF"
}

# ── /proc থেকে PID বের করে (Android 16 compatible, CPU হালকা)
get_pid_proc() {
    local pkg="$1"
    for d in /proc/[0-9]*/; do
        [ -f "${d}cmdline" ] || continue
        local cmd
        cmd=$(cat "${d}cmdline" 2>/dev/null | tr '\0' '\n' | head -1)
        if [ "$cmd" = "$pkg" ]; then
            local p="${d%/}"; echo "${p##*/}"; return
        fi
    done
}

# ── /proc থেকে সব user app PID+package বের করে
# UID 10000+ = user apps
scan_user_apps() {
    for d in /proc/[0-9]*/; do
        [ -f "${d}status" ] || continue
        local uid
        uid=$(grep "^Uid:" "${d}status" 2>/dev/null | awk '{print $2}')
        [ -z "$uid" ] && continue
        # UID 10000-19999 = normal user apps
        [ "$uid" -ge 10000 ] && [ "$uid" -lt 20000 ] 2>/dev/null || continue
        local cmd
        cmd=$(cat "${d}cmdline" 2>/dev/null | tr '\0' '\n' | head -1)
        # Valid package name (has dot)
        echo "$cmd" | grep -qE '^[a-zA-Z][a-zA-Z0-9_]*\.[a-zA-Z]' || continue
        # Skip : suffix (child processes like :remote)
        echo "$cmd" | grep -q ':' && continue
        local pid="${d%/}"; echo "${pid##*/}:$cmd"
    done
}

# ── Foreground app (হালকা method)
get_fg() {
    cat /proc/[0-9]*/wchan 2>/dev/null | head -1 || true
    # Reliable fallback:
    dumpsys activity activities 2>/dev/null \
        | grep "mResumedActivity" \
        | grep -oE '[a-zA-Z][a-zA-Z0-9._]+/[a-zA-Z0-9._]+' \
        | head -1 | cut -d'/' -f1
}

# ── Protected চেক
is_whitelisted() {
    local pkg="$1"
    for p in $WHITELIST; do
        [ "$pkg" = "$p" ] && return 0
    done
    return 1
}

# ── OOM lock
oom_lock() {
    local pid="$1"
    [ -n "$pid" ] && [ -f "/proc/$pid/oom_score_adj" ] && \
        echo "$OOM_LOCK" > "/proc/$pid/oom_score_adj" 2>/dev/null
}

# ── Whitelist apply (battery + standby)
apply_whitelist_settings() {
    for pkg in $WHITELIST; do
        dumpsys deviceidle whitelist "+$pkg" 2>/dev/null
        am set-standby-bucket "$pkg" active 2>/dev/null
    done
    log_i "Whitelist applied ($(echo $WHITELIST | wc -w) apps)"
}

# ── Tracker helpers
bg_get()   { local f="$BGT/$1"; [ -f "$f" ] && cat "$f" || echo 0; }
bg_set()   { echo "$(date +%s)" > "$BGT/$1"; }
bg_clr()   { rm -f "$BGT/$1"; }
ac_get()   { local f="$ACT/$1"; [ -f "$f" ] && cat "$f" || echo 0; }
ac_set()   { echo "$(date +%s)" > "$ACT/$1"; }
ac_clr()   { rm -f "$ACT/$1"; }

# ── Main loop
# HUP signal এ whitelist reload (app থেকে Save করলে)
trap 'load_whitelist; apply_whitelist_settings; log_i "Whitelist reloaded (HUP)"' HUP

main() {
    mkdir -p "$D/logs" "$BGT" "$ACT"
    log_i "BGGuard v2.0 started | interval:${INTERVAL}s"
    echo $$ > "$PID_F"

    log_i "Waiting 50s for boot..."
    sleep 50

    # Pending APK install (যদি flash এর সময় install না হয়ে থাকে)
    if [ -f "$D/.install_pending" ] && [ -f "$D/BGGuard.apk" ]; then
        log_i "Installing pending BGGuard APK..."
        if pm install -r "$D/BGGuard.apk" >/dev/null 2>&1; then
            log_i "APK installed successfully"
            rm -f "$D/.install_pending" "$D/BGGuard.apk"
        else
            log_i "APK install failed — will retry next boot"
        fi
    fi

    load_whitelist
    apply_whitelist_settings

    local tick=0
    while true; do
        tick=$(( tick + 1 ))
        local now; now=$(date +%s)

        # Whitelist reload every 5 min
        [ $(( tick % 5 )) -eq 0 ] && load_whitelist

        # Foreground app
        local fg; fg=$(get_fg)

        # Scan all user apps via /proc
        local app_list; app_list=$(scan_user_apps)

        # OOM lock whitelisted apps + auto-kill others
        echo "$app_list" | while IFS=: read -r pid pkg; do
            [ -z "$pid" ] || [ -z "$pkg" ] && continue

            if is_whitelisted "$pkg"; then
                # Protected — lock OOM
                oom_lock "$pid"
                bg_clr "$pkg"
            else
                # Not protected
                [ "$pkg" = "$fg" ] && { bg_clr "$pkg"; continue; }

                local bg_s; bg_s=$(bg_get "$pkg")
                if [ "$bg_s" = "0" ]; then
                    bg_set "$pkg"
                else
                    local el=$(( now - bg_s ))
                    if [ $el -ge $KILL_TIMEOUT ]; then
                        am kill "$pkg" 2>/dev/null
                        log_k "$pkg | ${el}s"
                        bg_clr "$pkg"
                    fi
                fi
            fi
        done

        # Footprint cleanup for whitelisted delivery apps
        for pkg in $WHITELIST; do
            local pid; pid=$(get_pid_proc "$pkg")
            [ -z "$pid" ] && { ac_clr "$pkg"; continue; }

            if [ "$pkg" = "$fg" ]; then
                ac_clr "$pkg"
            else
                local ac_s; ac_s=$(ac_get "$pkg")
                if [ "$ac_s" = "0" ]; then
                    ac_set "$pkg"
                else
                    local idle=$(( now - ac_s ))
                    if [ $idle -ge $FOOTPRINT_TIMEOUT ]; then
                        find "/data/data/$pkg/cache" -type f -delete 2>/dev/null
                        find "/data/data/$pkg/code_cache" -type f -delete 2>/dev/null
                        log_c "FOOTPRINT: $pkg (${idle}s idle)"
                        ac_clr "$pkg"
                    fi
                fi
            fi
        done

        # Whitelist reapply every 10 min
        [ $(( tick % 10 )) -eq 0 ] && apply_whitelist_settings

        # Log rotation
        local sz; sz=$(wc -c < "$LOG" 2>/dev/null || echo 0)
        [ "$sz" -gt 1048576 ] && { tail -200 "$LOG" > "${LOG}.t"; mv "${LOG}.t" "$LOG"; }

        sleep $INTERVAL
    done
}

main &
echo $! > "$PID_F"
disown
