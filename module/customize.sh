#!/sbin/sh
# BGGuard module customize — runs during flash

ui_print " "
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ui_print "  BGGuard v2.0 + App"
ui_print "  Red Magic 11 Pro | Android 16"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── Create data dirs ──
mkdir -p /data/adb/bgguard/logs
mkdir -p /data/adb/bgguard/bg_tracker
mkdir -p /data/adb/bgguard/active_tracker

# ── Default whitelist (only if not exists) ──
if [ ! -f /data/adb/bgguard/whitelist.conf ]; then
    ui_print "- Default whitelist তৈরি হচ্ছে..."
    cat > /data/adb/bgguard/whitelist.conf << 'WEOF'
# BGGuard Whitelist
# এই apps কখনো background kill হবে না
#
net.jahez.fleets
io.suqi8.saned
hamba.allah.swu
com.google.android.apps.maps
com.termux
WEOF
fi

# ── Install bundled APK ──
APK="$MODPATH/BGGuard.apk"
if [ -f "$APK" ]; then
    ui_print "- BGGuard app ইন্সটল হচ্ছে..."
    # Try pm install (works during late stage)
    if pm install -r "$APK" >/dev/null 2>&1; then
        ui_print "  ✅ App ইন্সটল সফল!"
    else
        # Fallback: copy to a known location, install on boot
        ui_print "  ⏳ App boot এর সময় ইন্সটল হবে"
        cp "$APK" /data/adb/bgguard/BGGuard.apk
        touch /data/adb/bgguard/.install_pending
    fi
    # Remove APK from module to save space (already installed/copied)
    rm -f "$APK"
else
    ui_print "  ⚠️  APK পাওয়া যায়নি (workflow ঠিকমতো build হয়েছে?)"
fi

# ── Set permissions ──
set_perm "$MODPATH/service.sh" root root 0755
set_perm "$MODPATH/post-fs-data.sh" root root 0755
set_perm "$MODPATH/system/bin/bgmon" root root 0755
set_perm "$MODPATH/system/bin/bgconfig" root root 0755
chmod -R 755 /data/adb/bgguard

ui_print " "
ui_print "- ইন্সটল সম্পন্ন!"
ui_print "- Reboot করুন, তারপর BGGuard app খুলুন"
ui_print "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
