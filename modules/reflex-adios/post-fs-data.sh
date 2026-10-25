#!/system/bin/sh
# post-fs-data: runs before /sys/block is fully populated.
# Only make sure our state directory exists; the real work happens in service.sh
# (late_start), by which time all block devices and cpufreq policies exist.

MODDIR=${0%/*}

mkdir -p "$MODDIR" 2>/dev/null
chmod 0755 "$MODDIR" 2>/dev/null
chown 0:0 "$MODDIR" 2>/dev/null

exit 0
