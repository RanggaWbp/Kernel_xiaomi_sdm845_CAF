/*
 * Cryptographic API.
 *
 * LZ4KDR zram compression backend for Linux 4.9.
 *
 * The upstream LZ4KDR patch (firelzrd/zram-ir, 0001-linux6.12.74-lz4kdr-1.3)
 * hooks zram through the 6.12 "backend_*" design: a struct zcomp_ops and a
 * backends[] table of pointers.  4.9 has none of that -- drivers/block/zram/
 * zcomp.c keeps a backends[] table of NAMES and resolves each one through
 * crypto_alloc_comp(), so a compressor becomes available to zram purely by
 * registering a crypto algorithm of that name.  This file is that
 * registration, and it is the reason LZ4KDR can be offered on 4.9 without
 * touching zram's own structure.
 *
 * The file follows crypto/lz4.c's structure exactly, which is the in-tree
 * precedent for "expose a lib/ compressor to the crypto API on 4.9": a ctx
 * holding the encoder's state buffer, both the old crypto_alg and the newer
 * scomp_alg registered so either call path works, and module_init registering
 * both together.
 */

#include <linux/init.h>
#include <linux/module.h>
#include <linux/crypto.h>
#include <linux/vmalloc.h>
#include <linux/lz4kdr.h>
#include <crypto/internal/scompress.h>

struct lz4kdr_ctx {
	void *state;
};

static void *lz4kdr_alloc_ctx(struct crypto_scomp *tfm)
{
	return kzalloc(lz4kdr_encode_state_bytes_min(), GFP_KERNEL);
}

static int lz4kdr_init(struct crypto_tfm *tfm)
{
	struct lz4kdr_ctx *ctx = crypto_tfm_ctx(tfm);

	ctx->state = lz4kdr_alloc_ctx(NULL);
	if (!ctx->state)
		return -ENOMEM;

	return 0;
}

static void lz4kdr_free_ctx(struct crypto_scomp *tfm, void *ctx)
{
	kfree(ctx);
}

static void lz4kdr_exit(struct crypto_tfm *tfm)
{
	struct lz4kdr_ctx *ctx = crypto_tfm_ctx(tfm);

	lz4kdr_free_ctx(NULL, ctx->state);
}

static int __lz4kdr_compress_crypto(const u8 *src, unsigned int slen,
				    u8 *dst, unsigned int *dlen, void *ctx)
{
	int ret = lz4kdr_encode(ctx, src, dst, slen, *dlen, 0);

	if (ret < 0)
		return -EINVAL;

	/*
	 * ret == 0 means the block did not compress.  This is NOT an error
	 * and must not be reported as one: zram_drv.c treats every non-zero
	 * return from zcomp_compress() as fatal and fails the write
	 * ("Compression failed! err=%d"), which would turn every
	 * incompressible page into an I/O error instead of a stored page.
	 *
	 * So copy the page through unchanged and hand back the uncompressed
	 * length.  zram_drv.c then does its own "comp_len >=
	 * huge_class_size -> comp_len = PAGE_SIZE", and PAGE_SIZE always
	 * satisfies that comparison, so zsmalloc stores the page raw.  The
	 * read path is unaffected: lz4kdr_decode() on a block it did not
	 * encode is never reached, because zram tracks same-page entries
	 * separately and serves them with zram_fill_page().
	 */
	if (ret == 0) {
		memcpy(dst, src, slen);
		*dlen = slen;
		return 0;
	}

	*dlen = ret;
	return 0;
}

static int lz4kdr_scompress(struct crypto_scomp *tfm, const u8 *src,
			    unsigned int slen, u8 *dst, unsigned int *dlen,
			    void *ctx)
{
	return __lz4kdr_compress_crypto(src, slen, dst, dlen, ctx);
}

static int lz4kdr_compress_crypto(struct crypto_tfm *tfm, const u8 *src,
				  unsigned int slen, u8 *dst,
				  unsigned int *dlen)
{
	struct lz4kdr_ctx *ctx = crypto_tfm_ctx(tfm);

	return __lz4kdr_compress_crypto(src, slen, dst, dlen, ctx->state);
}

static int __lz4kdr_decompress_crypto(const u8 *src, unsigned int slen,
				      u8 *dst, unsigned int *dlen, void *ctx)
{
	int ret = lz4kdr_decode(src, dst, slen, *dlen);

	if (ret < 0)
		return -EINVAL;

	return 0;
}

static int lz4kdr_sdecompress(struct crypto_scomp *tfm, const u8 *src,
			      unsigned int slen, u8 *dst, unsigned int *dlen,
			      void *ctx)
{
	return __lz4kdr_decompress_crypto(src, slen, dst, dlen, NULL);
}

static int lz4kdr_decompress_crypto(struct crypto_tfm *tfm, const u8 *src,
				    unsigned int slen, u8 *dst,
				    unsigned int *dlen)
{
	return __lz4kdr_decompress_crypto(src, slen, dst, dlen, NULL);
}

static struct crypto_alg alg_lz4kdr = {
	.cra_name		= "lz4kdr",
	.cra_flags		= CRYPTO_ALG_TYPE_COMPRESS,
	.cra_ctxsize		= sizeof(struct lz4kdr_ctx),
	.cra_module		= THIS_MODULE,
	.cra_list		= LIST_HEAD_INIT(alg_lz4kdr.cra_list),
	.cra_init		= lz4kdr_init,
	.cra_exit		= lz4kdr_exit,
	.cra_u			= { .compress = {
		.coa_compress	= lz4kdr_compress_crypto,
		.coa_decompress	= lz4kdr_decompress_crypto } }
};

static struct scomp_alg scomp = {
	.alloc_ctx		= lz4kdr_alloc_ctx,
	.free_ctx		= lz4kdr_free_ctx,
	.compress		= lz4kdr_scompress,
	.decompress		= lz4kdr_sdecompress,
	.base			= {
		.cra_name	= "lz4kdr",
		.cra_driver_name = "lz4kdr-scomp",
		.cra_module	 = THIS_MODULE,
	}
};

static int __init lz4kdr_mod_init(void)
{
	int ret;

	ret = crypto_register_alg(&alg_lz4kdr);
	if (ret)
		return ret;

	ret = crypto_register_scomp(&scomp);
	if (ret) {
		crypto_unregister_alg(&alg_lz4kdr);
		return ret;
	}

	return ret;
}

static void __exit lz4kdr_mod_fini(void)
{
	crypto_unregister_alg(&alg_lz4kdr);
	crypto_unregister_scomp(&scomp);
}

module_init(lz4kdr_mod_init);
module_exit(lz4kdr_mod_fini);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("LZ4KDR Compression Algorithm");
MODULE_ALIAS_CRYPTO("lz4kdr");
