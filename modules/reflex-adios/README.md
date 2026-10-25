# reflex-adios

A KernelSU/Magisk module that re-asserts this kernel's built-in defaults —
`reflex` CPU governor and `adios` I/O scheduler — after vendor/system init
overwrites them at boot.

## Why it exists

The kernel is configured to default to reflex (`CONFIG_CPU_FREQ_DEFAULT_GOV_REFLEX`)
and adios, and it does boot that way:

```
[    0.405838] reflex: cpufreq_default_governor(): CONFIG_CPU_FREQ_DEFAULT_GOV_REFLEX is the Kconfig default
[    0.406216] reflex: governor started on policy cpu 0
[    0.406550] reflex: governor started on policy cpu 4
```

Then userspace clobbers both settings:

- `/vendor/etc/init/hw/init.qcom.power.rc` line 147 and 154 write
  `schedutil` to `cpu0` and `cpu4` `scaling_governor`, so reflex is dropped
  even though the kernel loaded it.
- `/vendor/etc/init/hw/init.qcom.rc` line 58 and 63 write `cfq` to
  `/sys/block/sda/queue/scheduler` and `/sys/block/sdf/queue/scheduler`,
  so adios stays on sdb/sdc/sdd/sde but is lost on sda/sdf.
- `/system/etc/init/qassa-iosched.rc` reacts to `sys.io.scheduler` /
  `persist.sys.io.scheduler`; on this device `getprop sys.io.scheduler`
  returns empty, so it does nothing useful.

`/vendor` is dm-verity protected, so editing those rc files in place is not
an option. This module takes the other route: run late (after all `on boot`
and `on property:` triggers have fired) and write the kernel defaults back.

## What it does

At `late_start` (Magisk/KSU `service.sh`):

1. For every `/sys/devices/system/cpu/cpufreq/policy*`, writes `reflex` to
   `scaling_governor` — but only if `reflex` is listed in that policy's
   `scaling_available_governors`.
2. For every `/sys/block/sd*`, writes `adios` to `queue/scheduler` — but only
   if `adios` is in that device's scheduler list.
3. Sets `sys.io.scheduler` and `persist.sys.io.scheduler` to `adios` so
   `qassa-iosched.rc` propagates adios rather than an empty value.

It is idempotent, never hardcodes `policy0`/`policy4` or `sda`/`sdf`, skips
anything that isn't present yet, and never aborts on a single failed write.
All actions are logged to logcat with the tag `reflex-adios`.

## Build

The module is a plain directory of files — there is nothing to compile.
Zip it with the files at the archive root:

```sh
cd modules/reflex-adios
zip -r ../reflex-adios.zip .
```

`module.prop` must sit at the root of the zip, which the command above gives
you since it zips the contents of the directory rather than the directory
itself. Flash the resulting zip from KernelSU or Magisk.

## Verify after flashing

```sh
adb shell su -c 'for p in /sys/devices/system/cpu/cpufreq/policy*; do echo "$p: $(cat $p/scaling_governor)"; done'
adb shell su -c 'for d in /sys/block/sd*; do echo "$d: $(cat $d/queue/scheduler)"; done'
adb shell su -c 'getprop sys.io.scheduler'
adb shell logcat -d -s reflex-adios
```

Expected: every policy reports `reflex`, every `sd*` reports `[adios]`, and
`sys.io.scheduler` returns `adios`.

## Disable

Uninstall the module in KernelSU/Magisk. Nothing in the kernel depends on it;
the built-in reflex and adios code is unconditional and was already active
before vendor init overrode it.
