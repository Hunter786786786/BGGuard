#!/system/bin/sh
D="/data/adb/bgguard"
mkdir -p $D/logs $D/bg_tracker $D/active_tracker
rm -f $D/bg_tracker/* $D/active_tracker/* $D/service.pid

# bgmon ও bgconfig সরাসরি /data/local/tmp এ রাখি — mount সমস্যা নেই
cp /data/adb/modules/bgguard/system/bin/bgmon /data/local/tmp/bgmon 2>/dev/null
cp /data/adb/modules/bgguard/system/bin/bgconfig /data/local/tmp/bgconfig 2>/dev/null
chmod 755 /data/local/tmp/bgmon /data/local/tmp/bgconfig 2>/dev/null

echo "$(date '+%Y-%m-%d %H:%M:%S') BGGuard v2.0 boot" >> $D/logs/bgguard.log
