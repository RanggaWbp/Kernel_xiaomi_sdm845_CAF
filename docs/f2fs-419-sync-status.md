# f2fs 4.19 sync — status branch `f2fs-419`

Sync `fs/f2fs` dari **f2fs-stable `linux-4.19.y`** (tip 2022-12-12) ke tree ini
(Linux 4.9.337, CAF msm-4.9, Xiaomi sdm845).

`master` torvalds **tidak mungkin** dipakai: f2fs 7.3-rc1 memakai 78 API `folio_*`
dan 434 referensi `struct folio`, sementara 4.9 tidak punya folio (baru ada 5.16).
Itu port ulang layer page-cache, bukan backport. 4.19.y adalah versi f2fs terbaru
yang masih folio-free **dan** iomap-free.

## Metode

3-way merge, bukan replace wholesale:

```
ours   = fs/f2fs tree ini (CAF msm-4.9 + patch lokal)
base   = f2fs-stable linux-4.9.y tip 2020-05-20   (merge-base alami)
theirs = f2fs-stable linux-4.19.y tip 2022-12-12
```

177 konflik di 18 file, semuanya selesai. Hasil: +16460 / −4576 baris, 36 file.

## Commit

```
9803ec87259a  WIP: sync fs/f2fs ke f2fs-stable linux-4.19.y (3-way merge)
b63d1ff72044  f2fs 4.19 sync: shim gelombang 1
```

Branch `f2fs-419` sudah ada di origin. **`BakaSU-SUSFS` tidak disentuh.**
Belum pernah dikompilasi.

## Perubahan di luar `fs/f2fs`

Dua file ini wajib, bukan opsional:

- **`include/uapi/linux/f2fs.h`** (baru, 99 baris). Tree 4.9 menaruh ioctl f2fs
  (`F2FS_IOC_*`, `F2FS_GOING_DOWN_*`) di dalam `fs/f2fs/f2fs.h:402+`; f2fs.h sudah
  diganti versi 4.19.y yang tidak lagi mendefinisikannya.
- **`include/linux/f2fs_fs.h`** (di-update, 58 baris beda). Menyediakan
  `enum f2fs_error` (`ERROR_CORRUPTED_XATTR`, `ERROR_INCONSISTENT_NODE_COUNT`, …),
  `MAX_F2FS_ERRORS`, `enum stop_cp_reason` (`STOP_CP_REASON_FAULT_INJECT`),
  `MAX_STOP_REASON`, dan field `s_encoding`/`s_encoding_flags`/`s_stop_reason`/
  `s_errors`. Semua aditif di area reserved → on-disk tetap kompatibel.

`include/trace/events/f2fs.h` juga diganti versi 4.19.y (16 event baru) dengan 5
penyesuaian API 4.9: `__REQ_IDLE`→`__REQ_NOIDLE`, buang `REQ_OP_ZONE_REPORT`/
`REQ_OP_ZONE_RESET`/`REQ_OP_WRITE_ZEROES`, `bio_dev(bio)`→`bio->bi_bdev->bd_dev`.
`bio_op()` tetap dipakai karena ADA di 4.9 (`include/linux/blk_types.h:109`).

## Yang sudah dipertahankan (fitur lokal)

rapid_gc, wakelock/wakeup_source, MSM DRM notifier, ioprio GC kthread,
ICE/PFK, `android_fs` tracepoint, cleancache, `umount_end`, dan tuning lokal
(`DEF_MIN_FSYNC_BLOCKS` 20, `DEF_RECLAIM_PREFREE_SEGMENTS` 3,
`DEF_MAX_RECLAIM_PREFREE_SEGMENTS` 1024, `DEF_GC_THREAD_URGENT_SLEEP_TIME` 50).

Di `fs/f2fs/f2fs.h`: field `rapid_gc`, `f2fs_may_encrypt_bio()`,
deklarasi `f2fs_gc_sbi_list_add/del`, `f2fs_init_rapid_gc`, `f2fs_destroy_rapid_gc`,
`bool test_dummy_encryption` (menggantikan `struct fscrypt_dummy_context dummy_enc_ctx`),
dan shim `fscrypt_set_test_dummy_encryption`/`fscrypt_show_test_dummy_encryption`.

`fs/f2fs/fscrypt_compat.h` (baru): A1 `fscrypt_encrypt_pagecache_blocks`,
A2 `fscrypt_finalize_bounce_page`, A3 `fscrypt_is_bounce_page`,
A4 `fscrypt_pagecache_page`, B2 `fscrypt_free_dummy_context`.
**JANGAN** menyentuh `fs/crypto/`, `include/linux/fscrypt.h`, `include/uapi/linux/fs.h` —
ext4 FBE dan `fs/crypto/fscrypt_ice.c` harus utuh.

Catatan A3: deteksinya **wajib** `page->mapping == NULL`. `fscrypt_control_page()`
di 4.9 melakukan deref `((struct fscrypt_ctx *)page_private(page))->w.control_page`
(`include/linux/fscrypt.h:116-119`), jadi memanggilnya pada halaman non-bounce
membaca pointer sampah. Pola resmi tree ini ada di `fs/f2fs/data.c` HEAD:399-402.

## Sisa kerja

### 1. Shim mekanis

```
zoned block    bdev_zone_sectors(5) bdev_is_zoned(4) bdev_zoned_model(3)
               blkdev_reset_zones(1) blkdev_report_zones(1)
               4.9 tidak punya zoned block device -> gate/stub
simbol         timespec64_trunc(3) -> timespec_trunc (iattr 4.9 = struct timespec)
               ktime_get_boottime_seconds(3) -> ktime_divns(ktime_get_boottime(), NSEC_PER_SEC)
               file_modified(1) -> file_remove_privs + file_update_time
               simple_fill_fsxattr(1) vfs_ioc_fssetxattr_check(1)
               fsverity_ioctl_read_metadata(1) -> hapus handler (uapi tak ada)
               dquot_initialize_needed(1) -> dquot_initialize
               bioset_init/exit(2) -> bioset_create/bioset_free
               bio_first_page_all(1) migrate_page_states(1)
               xa_lock_irqsave/xa_unlock_irqrestore(2) -> mapping->tree_lock
               DEFINE_SHOW_ATTRIBUTE(1) -> tambah makro
               proc_create_single_data(5, sysfs.c) -> proc_create_data + single_open
               pagevec_lookup_range(1, compress.c)
               generic_set_encrypted_ci_d_ops(1, namei.c:518) -> fscrypt_d_ops
               TestClearPageError(1) -> ClearPageError + test
dihapus        fscrypt_ioctl_* keyring (6) + FS_IOC_REMOVE_ENCRYPTION_KEY dkk
mati sendiri   utf8_* + sb_has_strict_encoding (CONFIG_UNICODE tak ada di tree)
               compress_ctx/decompress_pages (CONFIG_F2FS_FS_COMPRESSION=n)
```

CATATAN: `proc_create_single_data` **tidak** bisa diganti makro `F2FS_PROC_FILE_DEF` —
makro itu tidak ada di tree ini (hanya ada di `base49/.../sysfs.c:762`).
`symbol-shim.md` salah soal ini.

### 2. Signature callback fatal (tulis ulang, bukan rename)

```
inode_operations->getattr          4.9: (vfsmount*, dentry*, kstat*)   3 arg
                                   f2fs: (const struct path*, kstat*, u32, uint)  4 arg
vm_operations_struct->fault        4.9: (vma, vmf)   |  f2fs: (vmf)
vm_operations_struct->page_mkwrite 4.9: (vma, vmf)   |  f2fs: (vmf)
fsverity_operations->read_merkle_tree_page  4.9: (inode, index)  |  f2fs: (+num_ra_pages)
kstat  result_mask/attributes/attributes_mask/btime  tidak ada di 4.9 (10 site)
fscrypt_operations  .get_dummy_context -> .dummy_context (bool);
                    buang .has_stable_inodes dan .get_ino_and_lblk_bits
bio->bi_status -> bio->bi_error (11 site);  BLK_STS_IOERR -> -EIO;
blk_status_to_errno() -> int;  bio_set_dev(bio,bdev) -> bio->bi_bdev = bdev
```

### 3. Inkonsistensi lintas-file yang dilaporkan agen resolve

```
gc.c       model gc-mode bercampur: tree pakai satu GC_URGENT, 4.19 pakai
           GC_URGENT_HIGH/MID/LOW + gc_remaining_trials. Loop thread memaksa
           gc_mode = GC_NORMAL tiap iterasi -> menimpa yang diset sysfs.
           Juga f2fs_gc() 4-arg (4.9) vs 1-arg struct f2fs_gc_control* (4.19).
           Locking bercampur: gc_mutex vs gc_lock/f2fs_down_write.
           foreground/sync_mode jadi tak terpakai; kvfree vs kfree tak konsisten.
segment.c  sit_i->bitmap (4.19, kontigu) bercampur dengan cur_valid_map/
           ckpt_valid_map per-segmen (4.9) -> tiga map per segmen BOCOR karena
           destroy_sit_info versi 4.19 hanya kvfree(sit_i->bitmap).
namei.c    f2fs_rename sudah dinormalkan ke 4.19 (whiteout single-alloc).
sysfs.c    C7/C9 sengaja bukan THEIRS penuh supaya patch lokal #9
           (sembunyikan tunable yang tak jalan dengan rapid GC) tetap hidup.
gc.h       DEF_GC_THREAD_NOGC_SLEEP_TIME berubah 1800000 -> 300000 (ikut THEIRS,
           bukan tuning di daftar rulebook) -> perlu keputusan.
```

### 4. 38 patch lokal (`local-patches.md`)

```
22  rapid_gc   -> port, bukan cherry-pick (model gc-mode beda)
 5  ICE/PFK    -> tulis ulang jalur enkripsi bio data.c ke helper CAF
 5  android_fs tracepoint -> sisipkan ulang di data.c/inline.c/file.c
 5  lokal      -> 4 apply cleanly (segment.h x2, gc.h, Kconfig), 1 minor rewrite
                 (umount_end di super.c)
 1  cleancache -> minor rewrite di super.c
```

## Verifikasi

User melarang build lokal. Jadi verifikasi = CI:

```
gh workflow run build.yml --ref f2fs-419
gh run list --limit 5
gh run watch <run-id> --exit-status
```

`build.yml` hanya auto-trigger pada push ke `master`, jadi ke `f2fs-419` harus
`workflow_dispatch`. Jangan push ke `BakaSU-SUSFS` sebelum CI hijau.

## Referensi

Semua di `/home/ranggawbp/.hermes/cache/scratch/f2fs-backport/`:

```
SHIM-WORKLIST.md   daftar kerja berurutan dengan file:line
symbol-shim.md     simbol eksternal non-fscrypt + penggantinya
fscrypt-shim.md    shim fscrypt v2 -> v1 (563 baris, termasuk 3 risiko utama)
struct-drift.md    field struct, tabel ops, include yang beda
local-patches.md   inventaris 38 patch lokal + rencana re-apply
trace-kconfig.md   trace, Kconfig, Makefile, defconfig
RESOLVE-RULES.md   aturan resolusi konflik 3-way yang dipakai
```

---

## STATUS AKHIR (setelah paket A-I)

Semua butir di bagian "Sisa kerja" di atas sudah dikerjakan. Bagian itu disimpan
sebagai catatan riwayat; keadaan sebenarnya ada di bawah.

### Yang dikerjakan setelah merge

```
f2fs.h      prototype f2fs_getattr dikembalikan ke 3-arg; GC_URGENT dibuang dari
            enum gc_mode; stub zoned (bdev_is_zoned/bdev_zone_sectors/bdev_zoned_model
            + BLK_ZONED_*) di bawah #ifndef CONFIG_BLK_DEV_ZONED; helper
            f2fs_bio_first_bvec_all/f2fs_bio_first_page_all;
            DEF_MAX_DISCARD_URGENT_ISSUE_TIME; DEFINE_SHOW_ATTRIBUTE;
            f2fs_boottime_seconds(); f2fs_may_encrypt_bio()
file.c      buang 6 ioctl keyring fscrypt + fsverity metadata + GETFSLABEL/SETFSLABEL;
            helper f2fs_file_modified/f2fs_simple_fill_fsxattr/f2fs_ioc_fssetxattr_check;
            signature getattr 3-arg, vm_ops->fault/page_mkwrite +vma;
            field kstat result_mask/attributes/attributes_mask/btime dibuang;
            file_write_and_wait_range -> filemap_write_and_wait_range
verity.c    read_merkle_tree_page 2-arg; helper readahead mati dihapus
data.c      __bio_alloc 2 call site 7-arg -> 2-arg; bioset_create/free;
            bio->bi_error; bio->bi_bdev; spin_lock(&mapping->tree_lock);
            migrate_page_states -> migrate_page_copy; bio_entry_slab;
            ICE/PFK diverifikasi sudah 4-arg (fscrypt_mergeable_bio dkk)
inode.c     dquot_initialize_needed -> dquot_initialize
namei.c     generic_set_encrypted_ci_d_ops -> f2fs_set_encrypted_d_ops (fscrypt_d_ops)
gc.c/gc.h   model GC diseragamkan ke 4.19 (f2fs_gc(sbi, &gc_control), gc_lock,
            f2fs_down_write); rapid GC tetap hidup dipetakan ke GC_URGENT_HIGH;
            DEF_GC_THREAD_NOGC_SLEEP_TIME dikembalikan ke 1800000
segment.c/h model SIT diseragamkan ke 4.19 (bitmap kontigu) -> kebocoran peta
            per-segmen hilang; sit_i->bitmap + invalid_segmap ditambahkan
sysfs.c     proc_create_single_data -> proc_create_data + makro F2FS_PROC_FILE_DEF
super.c     fscrypt_operations ke bentuk 4.9 (.dummy_context, buang 3 anggota 4.19);
            fscrypt_drop_inode dihapus dari f2fs_drop_inode
hash.c dll  include linux/unicode.h dan linux/sched/signal.h dihapus (tidak ada di 4.9)
```

### Fitur lokal terverifikasi masih ada

```
android_fs tracepoint   28 referensi di data.c, file.c, inline.c
rapid_gc                f2fs_start/stop/init/destroy_rapid_gc, rapid_gc_fb_work,
                        rapid_gc_set_wakelock, TRIGGER_RAPID_GC, msm_drm_notifier_callback
cleancache              super.c:4452
umount_end              super.c:1536 + .umount_end di f2fs_sops:3013
ioprio GC kthread       gc.c:238 (+ checkpoint.c, sysfs.c)
tuning                  DEF_RECLAIM_PREFREE_SEGMENTS 3, DEF_MAX_RECLAIM_PREFREE_SEGMENTS 1024,
                        DEF_MIN_FSYNC_BLOCKS 20, DEF_GC_THREAD_URGENT_SLEEP_TIME 50,
                        DEF_GC_THREAD_NOGC_SLEEP_TIME 1800000
fake kernel version     fs/f2fs/Kconfig:159/170/174
```

### Yang masih TIDAK bisa dipastikan

Tidak pernah dikompilasi. Pemeriksaan statis sudah bersih: 0 penanda konflik,
kurung seimbang di semua file, dan tidak ada simbol eksternal yang dipakai tapi
tidak terdefinisi (sisa temuan scanner semuanya false positive: fungsi yang
di-generate makro PAGE_PRIVATE_*_FUNC, fungsi static di file yang sama, atau
kode yang mati karena CONFIG_UNICODE / CONFIG_F2FS_FS_COMPRESSION /
CONFIG_BLK_DEV_ZONED tidak ada di tree ini).

Kelas error yang hanya muncul saat kompilasi dan perlu diwaspadai di CI:
- `-Wunused-function` / `-Wunused-variable` pada sisa kode 4.9 yang jadi mati
- ketidakcocokan tipe argumen di tempat yang tidak tercakup scanner simbol
- `-Werror` pada `include/linux/f2fs_fs.h` yang berubah (cek pemakai di luar fs/f2fs)
