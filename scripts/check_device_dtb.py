#!/usr/bin/env python3
"""Validate the DTBs packed into Image.gz-dtb for one build variant.

Two things are checked, both of which have silently broken boot before:

1. The device's own DTB is present. The DTBs appended to Image.gz-dtb are
   raw, sitting right after the gzip member, so decompress and walk the fdt
   blobs. A board whose own DTB is missing falls back to whatever generic
   board matches first, which boots with the wrong hardware and no way to
   tell from the outside.

2. The fstab node matches the variant being built. fs_mgr's first-stage init
   reads the fstab from the boot DTB first (/firmware/android/fstab,
   compatible "android,fstab") and only falls back to the rom's own
   fstab.<hw> from the ramdisk when that node is absent. So the node pins the
   partition layout:

     nse      fstab present, no system_ext entry (rom has no /system_ext)
     se       fstab present, system_ext entry present (/by-name/cust)
     dynamic  no fstab node at all (rom's own fstab declares super/logical)

   Wrong node for the rom = the kernel mounts a partition that does not exist
   (or mounts a static one where super is required) = bootloop.

Usage: check_device_dtb.py <image> <device> [variant]
"""
import struct
import sys
import zlib

FDT_MAGIC = b"\xd0\x0d\xfe\xed"
# Only ever emitted by the `compatible = "android,fstab"` / `"android,system_ext"`
# properties, so a plain byte search over the blob is an exact detector.
DT_FSTAB = b"android,fstab"
DT_SYSTEM_EXT = b"android,system_ext"

VARIANTS = {
    "nse": (True, False),
    "se": (True, True),
    "dynamic": (False, False),
}


def dtbs(image):
    with open(image, "rb") as f:
        blob = f.read()
    dec = zlib.decompressobj(31)
    dec.decompress(blob, 64 * 1024 * 1024)
    raw = dec.unused_data or blob
    i = 0
    while i + 40 <= len(raw) and raw[i:i + 4] == FDT_MAGIC:
        size = struct.unpack_from(">I", raw, i + 4)[0]
        if size < 40 or i + size > len(raw):
            break
        yield raw[i:i + size]
        i += size


def main():
    if len(sys.argv) < 3:
        print((__doc__ or "").strip(), file=sys.stderr)
        return 2
    image, device = sys.argv[1], sys.argv[2]
    variant = sys.argv[3] if len(sys.argv) > 3 else "dynamic"
    if variant not in VARIANTS:
        print(f"::error::unknown variant '{variant}' "
              f"(expected one of {', '.join(sorted(VARIANTS))})", file=sys.stderr)
        return 2
    want_fstab, want_system_ext = VARIANTS[variant]

    # Device-tree model strings spell the board out, not the .dtb filename:
    # dipper -> "Xiaomi Technologies, Inc. Dipper new P0 v2". Case-insensitive.
    needle = device.encode().lower()
    blobs = list(dtbs(image))
    mine = [blob for blob in blobs if needle in blob.lower()]

    if not mine:
        print(f"::error::{image} has {len(blobs)} DTBs, none for {device}. "
              f"Only generic sdm845 boards would match this build.", file=sys.stderr)
        return 1

    bad = []
    for i, blob in enumerate(mine):
        got = (DT_FSTAB in blob, DT_SYSTEM_EXT in blob)
        if got != (want_fstab, want_system_ext):
            bad.append((i + 1, got))

    if bad:
        for n, (got_fstab, got_system_ext) in bad:
            print(f"::error::{image}: {device} DTB #{n} has fstab={got_fstab} "
                  f"system_ext={got_system_ext}, expected fstab={want_fstab} "
                  f"system_ext={want_system_ext} for variant '{variant}'.",
                  file=sys.stderr)
        print(f"::error::variant mismatch: the dt fragment for this build was "
              f"not applied (dt-variants/{variant}.dtsi) or the dtbs are stale.",
              file=sys.stderr)
        return 1

    print(f"{device} [{variant}]: {len(mine)} DTB(s) for this device, "
          f"fstab={'yes' if want_fstab else 'no'}, "
          f"system_ext={'yes' if want_system_ext else 'no'} -> OK "
          f"({len(blobs)} DTBs in image)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
