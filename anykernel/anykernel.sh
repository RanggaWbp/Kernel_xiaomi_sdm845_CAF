### AnyKernel3 Ramdisk Script
## osm0sis @ xda-developers
## Repacked for LawRun xiaomi sdm845 (CAF 4.9.337)
##
## Features: ReSukiSU v4.2.0-rc3 + SUSFS v2.3.0 + NoMount + BBG + Re:Kernel

### AnyKernel properties
# NOTE: only the key=value lines above this point are read as properties, and
# they are read lowercase by update-binary's file_getprop. The shell variables
# below are a *different* namespace read directly by tools/ak3-core.sh, which
# only ever looks at UPPERCASE names. A lowercase block=/is_slot_device= here
# is silently ignored: $BLOCK stays empty, setup_ak's "case $BLOCK" falls into
# the *) branch with an empty parttype, the by-name loops match nothing, and
# it dies with "Unable to determine  partition. Aborting..." (empty $BLOCK).
do.devicecheck=0
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
ui_print "  LawRun for Xiaomi SDM845 (CAF 4.9.337)"
ui_print "  ReSukiSU v4.2.0 + SUSFS v2.3.0 + NoMount + BBG + Re:Kernel"
## end properties

dump_boot
write_boot
## end boot sections
