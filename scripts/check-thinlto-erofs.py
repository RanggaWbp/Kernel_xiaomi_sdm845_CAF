#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0
"""Reject kernel artifacts without built-in EROFS and real ThinLTO inputs."""
import os
from pathlib import Path
import re
import subprocess
import sys


def check(out):
    config = (out / '.config').read_text().splitlines()
    for symbol in ('EROFS_FS', 'EROFS_FS_XATTR', 'EROFS_FS_POSIX_ACL',
                   'EROFS_FS_SECURITY', 'EROFS_FS_ZIP', 'LZ4_DECOMPRESS',
                   'LTO_CLANG', 'LTO_CLANG_THIN', 'THIN_ARCHIVES'):
        if 'CONFIG_' + symbol + '=y' not in config:
            raise ValueError('missing CONFIG_' + symbol + '=y')
    if 'CONFIG_LTO_CLANG_FULL=y' in config:
        raise ValueError('Full LTO selected instead of ThinLTO')

    obj = out / 'fs/erofs/zdata.o'
    command = (obj.parent / ('.' + obj.name + '.cmd')).read_text()
    if '-flto=thin' not in command:
        raise ValueError('zdata.o was not compiled with -flto=thin')
    dis = subprocess.check_output(
        [os.environ.get('LLVM_DIS', 'llvm-dis'), str(obj), '-o', '-'],
        text=True)
    if re.search(r'!"ThinLTO", i32 0\}', dis):
        raise ValueError('zdata.o explicitly disables ThinLTO')
    if not re.search(r'^\^\d+ = module:', dis, re.MULTILINE):
        raise ValueError('zdata.o lacks a ThinLTO module summary')

    with (out / 'vmlinux').open('rb') as kernel:
        header = kernel.read(20)
    if (header[:6] != b'\x7fELF\x02\x01'
            or header[16:18] not in (b'\x02\x00', b'\x03\x00')
            or header[18:20] != b'\xb7\x00'):
        raise ValueError('vmlinux is not an AArch64 ELF64 executable')
    symbols = subprocess.check_output(
        [os.environ.get('NM', 'llvm-nm'), '--defined-only',
         str(out / 'vmlinux')], text=True)
    if not re.search(r'\berofs_fs_type(?:\.\S+)?$', symbols, re.MULTILINE):
        raise ValueError('EROFS filesystem registration missing from vmlinux')
    if list((out / 'fs/erofs').rglob('*.ko')):
        raise ValueError('EROFS must be built in, not packaged as a module')
    print('PASS: EROFS built in; ThinLTO flag, summary and AArch64 vmlinux verified')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit('usage: check-thinlto-erofs.py OUTPUT_DIRECTORY')
    try:
        check(Path(sys.argv[1]))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit('FAIL: ' + str(error))
