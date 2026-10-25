### AnyKernel3 Ramdisk Script
## osm0sis @ xda-developers
## Kernel xiaomi sdm845 (CAF 4.9.337) by RanggaWbp
##
## Features: BakaSU + SUSFS + NoMount + BBG + DroidSpaces + ReKernel + NTSYNC + BORE + ADIOS + MGLRU + LZ4 + BBRv3 + POC Selector + Reflex
### AnyKernel properties
# NOTE: only the key=value lines above this point are read as properties, and
# they are read lowercase by update-binary's file_getprop. The shell variables
# below are a *different* namespace read directly by tools/ak3-core.sh, which
# only ever looks at UPPERCASE names. A lowercase block=/is_slot_device= here
# is silently ignored: $BLOCK stays empty, setup_ak's "case $BLOCK" falls into
# the *) branch with an empty parttype, the by-name loops match nothing, and
# it dies with "Unable to determine  partition. Aborting..." (empty $BLOCK).
# 
# 1 (not 0) so update-binary's do_devicecheck() actually runs: it compares
# device.name1-6 against ro.product.device / ro.build.product /
# ro.product.vendor.device / ro.vendor.product.device and prints the matched
# codename. With 0 it returned on line 1 and the codename was never shown.
# NOTE: enabling this also means an unlisted device now ABORTS instead of
# flashing blindly. If a new device 404s here, add its codename below.
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=beryllium
device.name2=dipper
device.name3=equuleus
device.name4=perseus
device.name5=polaris
device.name6=ursa
# kernel.string is the install title TWRP shows (read by update-binary's
# file_getprop from this file, so it must stay lowercase at column 0 and
# cannot contain a '=' sign).
kernel.string=BakaSU for Xiaomi SDM845 by RanggaWbp
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=

# boot shell variables (UPPERCASE -- these are what ak3-core.sh consumes)
# All six targets (dipper, beryllium, equuleus, perseus, polaris, ursa) are
# SDM845 non-A/B: there is no _a/_b slot suffix, so AK3 must not look for one.
IS_SLOT_DEVICE=0;
# BLOCK=boot, NOT `auto` and NOT an explicit /dev path.
#   * An explicit /dev/* path only gets `[ -e "$BLOCK" ]` in ak3-core.sh's
#     case, so a path that does not exist verbatim aborts outright.
#   * `auto` is worse than it looks: ak3-core.sh maps auto to
#     parttype="$plistinit $plistboot" (init_boot and ramdisk FIRST). If the
#     flashed ROM has an init_boot partition -- which any Android 12+ GPI
#     layout does -- auto resolves to init_boot and the kernel gets written to
#     the WRONG partition while still reporting success.
#   * `boot` maps to plistboot only, so it can never pick init_boot/ramdisk,
#     and it still walks every by-name location this device might use
#     (/dev/block/by-name, /dev/block/bootdevice/by-name,
#     /dev/block/platform/*/by-name, /dev/block/platform/*/*/by-name, /dev).
#   * IS_SLOT_DEVICE=0 keeps $SLOT empty, so it probes the bare "boot" name
#     with no _a/_b suffix -- correct for these non-A/B devices.
BLOCK=boot;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

. tools/ak3-core.sh

## begin properties
# ====================================================================
# Flash UI. Plain ASCII on purpose: only characters a minimal recovery
# shell can print are used here, and every ui_print line below is kept
# under 72 columns so nothing wraps on a phone screen.
#
# NOTE: no line below starts with a lowercase key=value. The property
# parser above only reads the first six lines of this file, but a stray
# lowercase key=value line is silently ignored at best and confusing at
# worst -- keep the '=' characters inside quoted strings only.
#
# Status words, used consistently throughout:
#   ACTIVE    = on by default, nothing to switch
#   BUILT-IN  = compiled in, not selected by default
#   OPTIONAL  = available, but only if the user switches to it
# ====================================================================
ui_print "===================================================="
ui_print " BakaSU Kernel for Xiaomi SDM845 (CAF 4.9.337)"
ui_print " by RanggaWbp"
# The only difference between the NSE / SE / DYNAMIC zips is the fstab
# node in the appended DTB, so print it here: a user who reports a
# bootloop can say which variant was flashed without guessing from the
# filename.
ui_print " Variant: __VARIANT__"
ui_print "   NSE     no /system_ext"
ui_print "   SE      /system_ext on cust"
ui_print "   DYNAMIC super / logical"
# Print the codename here as well. do_devicecheck() above already reports
# a match, but it only prints on success and prints nothing on the
# no-check path; this always shows what ro.product.device actually
# reports, which is what you want when a new device has to be added to
# device.name1-6 above.
ui_print " Device : $(getprop ro.product.device 2>/dev/null)"
ui_print "----------------------------------------------------"
# --- CPU scheduler -------------------------------------------------
# BORE is a core-criterion rewrite (sched/fair.c), always compiled in.
ui_print " CPU SCHEDULER"
ui_print " BORE (burst-aware wakeup preemption)"
ui_print "   ACTIVE by default, nothing to switch"
# POC Selector is capacity-class gated on big.LITTLE: the upstream
# selector refuses to run on asymmetric CPU capacity, the backport
# intersects the candidate mask with the target's capacity class so it
# is safe here. /sys/kernel/poc_selector/status/ is created by
# sched_poc_status_init(); the tunables are /proc/sys/kernel/sched_poc_*.
ui_print " POC Selector v2.6.3 (pick_idle_cpu replacement)"
ui_print "   ACTIVE by default, capacity-class gated"
ui_print "   status /sys/kernel/poc_selector/status/"
ui_print "   tune   /proc/sys/kernel/sched_poc_*"
ui_print "   off    echo 0 > /proc/sys/kernel/sched_poc_selector"
# --- CPU frequency -------------------------------------------------
# CONFIG_CPU_FREQ_DEFAULT_GOV_REFLEX=y in every defconfig, so reflex is
# cpufreq_default_governor(); the tunables live in
# /sys/devices/system/cpu/cpufreq/policy*/reflex/. Qualcomm's powerHAL
# rewrites scaling_governor at runtime, so it may show schedutil later.
ui_print " CPU FREQUENCY"
ui_print " Reflex v0.4.0 cpufreq governor"
ui_print "   ACTIVE by default (was schedutil)"
ui_print "   verify /sys/devices/system/cpu/cpufreq/policy0/"
ui_print "     scaling_governor -> reflex"
ui_print "     reflex/version   -> 0.4.0"
ui_print "   powerHAL can switch governor at runtime;"
ui_print "   switch back:"
ui_print "     echo reflex > /sys/devices/system/cpu/cpufreq/"
ui_print "     policy0/scaling_governor"
# --- I/O ------------------------------------------------------------
# ADIOS is built in (=y) but is NOT the queue default; 4.9 has no
# CONFIG_DEFAULT_IOSCHED, so mq-deadline stays the default unless the
# user selects it per device.
ui_print " I/O SCHEDULER"
ui_print " MGLRU multi-gen LRU"
ui_print "   ACTIVE (/sys/kernel/mm/lru_gen/enabled)"
ui_print " ADIOS"
ui_print "   BUILT-IN, not the queue default, select it with:"
ui_print "     echo adios > /sys/block/sd*/queue/scheduler"
ui_print "   OPTIONAL: mq-deadline (default), noop, cfq, bfq"
# --- Network / compression -----------------------------------------
ui_print " NETWORK"
ui_print " BBRv3 TCP congestion control"
ui_print "   ACTIVE by default (bbr v1 also present)"
ui_print " LZ4 zram compressor"
ui_print "   ACTIVE by default (comp_algorithm: lz4 lzo ...)"
# --- Root and the rest ---------------------------------------------
ui_print " ROOT / SECURITY"
ui_print " BakaSU + SUSFS + NoMount + BBG"
ui_print " + DroidSpaces + ReKernel + NTSYNC"
ui_print " NTSYNC /dev/ntsync (Wine / emulator sync)"
# --- Footer hints ---------------------------------------------------
ui_print "----------------------------------------------------"
ui_print " CHECK  sysctl net.ipv4.tcp_congestion_control"
ui_print "        expect bbr3"
ui_print " REVERT echo cubic > /proc/sys/net/ipv4/"
ui_print "        tcp_congestion_control"
ui_print "===================================================="
## end properties

dump_boot
write_boot
## end boot sections
