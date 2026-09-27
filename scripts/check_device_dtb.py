#!/usr/bin/env python3
"""Fail if Image.gz-dtb carries no DTB for the device being built.

The DTBs appended to Image.gz-dtb are raw, sitting right after the gzip
member, so decompress and walk the fdt blobs. A board whose own DTB is
missing falls back to whatever generic board matches first, which boots
with the wrong hardware and no way to tell from the outside.

Usage: check_device_dtb.py <image> <device>
"""
import struct
import sys
import zlib

FDT_MAGIC = b"\xd0\x0d\xfe\xed"


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
    image, device = sys.argv[1], sys.argv[2]
    # Device-tree model strings spell the board out, not the .dtb filename:
    # dipper -> "Xiaomi Technologies, Inc. Dipper new P0 v2". Case-insensitive.
    needle = device.encode().lower()
    total = 0
    for blob in dtbs(image):
        total += 1
        if needle in blob.lower():
            print(f"{device}: DTB #{total} carries this device "
                  f"({total} DTBs in image)")
            return 0
    print(f"::error::{image} has {total} DTBs, none for {device}. "
          f"Only generic sdm845 boards would match this build.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
