### AnyKernel3 Ramdisk Script
## osm0sis @ xda-developers
## Repacked for LawRun xiaomi sdm845 (CAF 4.9.337)
##
## Features: ReSukiSU v4.2.0-rc3 + SUSFS v2.3.0 + NoMount + BBG + Re:Kernel

### AnyKernel properties
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

# Non-A/B devices: no _a/_b slot suffix, so AK3 must not try to detect one.
is_slot_device=0;
block=/dev/block/bootdevice/by-name/boot;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh

## begin properties
ui_print "  LawRun for Xiaomi SDM845 (CAF 4.9.337)"
ui_print "  ReSukiSU v4.2.0 + SUSFS v2.3.0 + NoMount + BBG + Re:Kernel"
## end properties

dump_boot
write_boot
## end boot sections
