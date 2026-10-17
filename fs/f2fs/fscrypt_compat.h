/* SPDX-License-Identifier: GPL-2.0 */
/*
 * fscrypt compatibility shim: f2fs 4.19.y (fscrypt v2 pagecache-blocks API)
 * -> fs/crypto milik tree ini (API 4.9 + ICE/PFK CAF).
 *
 * ATURAN: file ini HANYA boleh bergantung pada include/linux/fscrypt.h dan
 * header kernel lain. TIDAK boleh memakai makro dari f2fs.h (F2FS_SB,
 * F2FS_OPTION, struct f2fs_sb_info) karena header ini di-include di bagian
 * atas f2fs.h, sebelum makro-makro itu ada.
 *
 * Shim yang butuh f2fs.h (fscrypt_set_test_dummy_encryption,
 * fscrypt_show_test_dummy_encryption) didefinisikan di BAGIAN BAWAH f2fs.h,
 * bukan di sini.
 *
 * JANGAN menyentuh fs/crypto/, include/linux/fscrypt.h, atau
 * include/uapi/linux/fs.h - ext4 FBE dan fs/crypto/fscrypt_ice.c harus utuh.
 */
#ifndef _F2FS_FSCRYPT_COMPAT_H
#define _F2FS_FSCRYPT_COMPAT_H

#ifdef CONFIG_FS_ENCRYPTION

/*
 * A1. 4.19.y: fscrypt_encrypt_pagecache_blocks(page, len, offs, gfp)
 *     4.9   : fscrypt_encrypt_page(inode, page, len, offs, lblk_num, gfp)
 *
 * lblk_num = page->index pada 4.9 (satu page per panggilan; 4.19.y juga
 * memanggilnya per page lewat f2fs_encrypt_one_page()).
 */
static inline struct page *fscrypt_encrypt_pagecache_blocks(struct page *page,
					unsigned int len, unsigned int offs,
					gfp_t gfp_flags)
{
	return fscrypt_encrypt_page(page->mapping->host, page, len, offs,
					(u64)page->index, gfp_flags);
}

/*
 * A2. 4.19.y: fscrypt_finalize_bounce_page(struct page **pagep)
 *     4.9   : fscrypt_pullback_bio_page(struct page **, bool)
 *
 * Param bool = true berarti pemanggil memegang referensi halaman; itu yang
 * dilakukan 4.19.y setelah halaman bounce dipakai.
 */
#define fscrypt_finalize_bounce_page(pagep)	\
	fscrypt_pullback_bio_page((pagep), true)

/*
 * A3. 4.19.y: fscrypt_is_bounce_page(page) - halaman bounce punya mapping NULL.
 * Di 4.9 JANGAN pakai fscrypt_control_page() untuk mendeteksi: fungsi itu
 * melakukan deref `((struct fscrypt_ctx *)page_private(page))->w.control_page`
 * (include/linux/fscrypt.h:116-119), sehingga pada halaman non-bounce ia
 * membaca pointer sampah. Pola resmi tree ini (fs/f2fs/data.c HEAD:399-402)
 * adalah memeriksa `->mapping` lebih dulu, baru memanggil control_page.
 */
static inline bool fscrypt_is_bounce_page(struct page *page)
{
	return page->mapping == NULL;
}

/*
 * A4. 4.19.y: fscrypt_pagecache_page(page) - halaman pagecache di balik
 * halaman bounce. Di 4.9 itu fscrypt_control_page().
 */
#define fscrypt_pagecache_page(page)	fscrypt_control_page(page)

/*
 * B2. 4.19.y menyimpan konteks dummy encryption di struct fscrypt_dummy_context
 * dan membebaskannya. 4.9 tidak punya konteks tersimpan - hanya bool
 * test_dummy_encryption - jadi pembebasannya tidak beroperasi.
 */
#define fscrypt_free_dummy_context(ctx)	do { } while (0)

#endif /* CONFIG_FS_ENCRYPTION */

#endif /* _F2FS_FSCRYPT_COMPAT_H */
