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
# Flash UI layout rules -- keep these, they are what makes the screen
# readable on a 48-64 column monospaced recovery console:
#   * ONE separator character ('-') and ONE width (56 columns) for every
#     rule line. Nothing is centred by hand, nothing is wrapped: if a line
#     would exceed the width the text is shortened instead.
#   * every content line is indented by exactly one space, so the left edge
#     of all text lines up.
#   * the feature list is one line per feature, "NAME <pad> STATUS", with the
#     status column always starting at column 15 (index 14).
#   * ASCII only, and no '=' at column 0 below this point, so nothing here
#     can be mistaken for a property.
#
# Status words:
#   active   on by default in this build, nothing to switch
#   active*  kernel default, but /vendor init can override it at boot
#            (see the footnote printed under the feature list)
# ====================================================================
# The variant line is deliberate: the NSE / SE / DYNAMIC zips differ only in
# the fstab node of the appended DTB, so a user reporting a bootloop can name
# the variant instead of guessing from the filename. __VARIANT__ is
# substituted by CI.
# ro.product.device is printed rather than hardcoded so the screen always
# shows what the running ROM actually reports -- that is the value you need
# when a new device has to be added to device.name1-6 above.
# Layout rules, applied to every line below:
#   - one separator character, one width (56), used for all four rules
#   - every content line starts with exactly one space
#   - in the feature list the name is padded to 12 columns, so the status
#     always begins at column 15 regardless of how long the name is
#   - one footnote marker (*) and it is used for exactly two rows
#   - no line exceeds 56 columns, so nothing wraps on a phone screen
#   - every line states a fact; nothing is a half-instruction
ui_print "--------------------------------------------------------"
ui_print " BakaSU Kernel 4.9.337 (CAF) Xiaomi SDM845"
# Author and build date. __BUILD_DATE__ is substituted by
# .github/workflows/build.yml (same mechanism as __VARIANT__) with the
# date the image was actually built, so the banner identifies the build
# and not the moment the zip happened to be flashed. On a hand-built
# zip the placeholder survives and shows literally -- obvious, not
# silent. Keep this line short: the date is d.m.yyyy, no spaces.
ui_print " by RanggaWbp __BUILD_DATE__"
ui_print " Device $(getprop ro.product.device)"
ui_print " Variant __VARIANT__"
ui_print "--------------------------------------------------------"
ui_print " BORE         active"
ui_print " POC Selector active"
ui_print " MGLRU        active"
ui_print " BBRv3        active"
ui_print " LZ4          active"
ui_print " Reflex       active *"
ui_print " ADIOS        active *"
ui_print "--------------------------------------------------------"
# The two starred rows are kernel defaults (CONFIG_CPU_FREQ_DEFAULT_GOV_REFLEX,
# CONFIG_DEFAULT_ADIOS) but /vendor/etc/init/hw/init.qcom.power.rc rewrites
# scaling_governor to schedutil on cpu0/cpu4, and
# /vendor/etc/init/hw/init.qcom.rc rewrites sda/sdf to cfq, at every boot.
# On a stock vendor image the runtime value is therefore not guaranteed.
ui_print " * kernel default; vendor init may override"
ui_print " tcp_congestion_control: bbr3"
ui_print "--------------------------------------------------------"
## end properties

dump_boot
write_boot
## end boot sections
