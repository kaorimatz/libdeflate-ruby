#include "libdeflate_ext.h"

#define DEFAULT_COMPRESSION 6

#define FORMAT_DEFLATE 0
#define FORMAT_ZLIB 1
#define FORMAT_GZIP 2

VALUE rb_eLibdefalteError, rb_eBadDataError;

/*
 * call-seq:
 *    Libdeflate.adler32(str = nil, adler = nil) -> integer
 *
 * Updates an Adler-32 checksum with <i>str</i>. If <i>str</i> is omitted, it
 * returns the initial value of Adler-32 checksum. If <i>adler</i> is omitted,
 * it assumes that the initial value of Adler-32 checksum is given.
 *
 *    Libdeflate.adler32                                #=> 1
 *    Libdeflate.adler32('foo')                         #=> 42074437
 *    Libdeflate.adler32('oo', Libdeflate.adler32('f')) #=> 42074437
 */
static VALUE
rb_libdeflate_adler32(int argc, VALUE *argv, VALUE self)
{
    VALUE str, adler;
    unsigned long checksum;

    rb_scan_args(argc, argv, "02", &str, &adler);

    if (!NIL_P(adler)) {
        checksum = NUM2ULONG(adler);
    } else if (!NIL_P(str)) {
        checksum = libdeflate_adler32(0, NULL, 0);
    } else {
        checksum = 0;
    }

    if (NIL_P(str)) {
        checksum = libdeflate_adler32(checksum, NULL, 0);
    } else {
        StringValue(str);
        checksum = libdeflate_adler32(checksum, RSTRING_PTR(str), RSTRING_LEN(str));
    }

    return ULONG2NUM(checksum);
}

/*
 * call-seq:
 *    Libdeflate.crc32(str = nil, crc = nil) -> integer
 *
 * Updates a CRC-32 checksum with <i>str</i>. If <i>str</i> is omitted, it
 * returns the initial value of CRC-32 checksum. If <i>crc</i> is omitted, it
 * assumes that the initial value of CRC-32 checksum is given.
 *
 *    Libdeflate.crc32                              #=> 0
 *    Libdeflate.crc32('foo')                       #=> 2356372769
 *    Libdeflate.crc32('oo', Libdeflate.crc32('f')) #=> 2356372769
 */
static VALUE
rb_libdeflate_crc32(int argc, VALUE *argv, VALUE self)
{
    VALUE str, crc;
    unsigned long checksum;

    rb_scan_args(argc, argv, "02", &str, &crc);

    if (!NIL_P(crc)) {
        checksum = NUM2ULONG(crc);
    } else if (!NIL_P(str)) {
        checksum = libdeflate_crc32(0, NULL, 0);
    } else {
        checksum = 0;
    }

    if (NIL_P(str)) {
        checksum = libdeflate_crc32(checksum, NULL, 0);
    } else {
        StringValue(str);
        checksum = libdeflate_crc32(checksum, RSTRING_PTR(str), RSTRING_LEN(str));
    }

    return ULONG2NUM(checksum);
}

/*
 * Inputs at least this long are compressed without the GVL,
 * so other Ruby threads run meanwhile. Below it, releasing and reacquiring the
 * GVL costs more than the work.
 */
#define NOGVL_MIN_BYTES 16384

struct compressor {
    struct libdeflate_compressor *c;
    int level;
};

static void
compressor_free(void *ptr)
{
    struct compressor *compressor = ptr;

    libdeflate_free_compressor(compressor->c);
    xfree(compressor);
}

static size_t
compressor_memsize(const void *ptr)
{
    return sizeof(struct compressor);
}

static const rb_data_type_t compressor_data_type = {
    "compressor",
    { NULL, compressor_free, compressor_memsize, },
    0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE
rb_compressor_s_allocate(VALUE klass)
{
    struct compressor *compressor;

    return TypedData_Make_Struct(klass, struct compressor, &compressor_data_type, compressor);
}

/*
 * call-seq:
 *    initialize(level = DEFAULT_COMPRESSION) -> compressor
 *
 * Returns a new Libdeflate::Compressor object. <i>level</i> must be in range
 * from 1 to 12, and defaults to DEFAULT_COMPRESSION.
 *
 *    Libdeflate::Compressor.new #=> #<Libdeflate::Compressor:0x007fad31b672c8>
 */
static VALUE
rb_compressor_initialize(int argc, VALUE *argv, VALUE self)
{
    VALUE level;
    int compression_level;
    struct compressor *compressor = rb_check_typeddata(self, &compressor_data_type);
    struct libdeflate_compressor *c;

    rb_scan_args(argc, argv, "01", &level);

    compression_level = NIL_P(level) ? DEFAULT_COMPRESSION : NUM2INT(level);

    c = libdeflate_alloc_compressor(compression_level);
    if (c == NULL) {
        rb_raise(rb_eLibdefalteError, "libdeflate_alloc_compressor: compression_level=%d", compression_level);
    }

    if (compressor->c != NULL) {
        libdeflate_free_compressor(compressor->c);
    }
    compressor->c = c;
    compressor->level = compression_level;

    return self;
}

static inline struct compressor *
check_compressor(VALUE self)
{
    struct compressor *compressor = rb_check_typeddata(self, &compressor_data_type);

    if (compressor->c == NULL) {
        rb_raise(rb_eLibdefalteError, "uninitialized compressor");
    }

    return compressor;
}

struct compress_args {
    int level;
    size_t (*func)(struct libdeflate_compressor *, const void *, size_t, void *, size_t);
    const void *in;
    size_t in_nbytes;
    void *out;
    size_t out_nbytes_avail;
    size_t result;
};

/*
 * Runs without the GVL. The input is a frozen string and the output a string
 * no other thread has seen, so neither changes meanwhile. It compresses with a
 * libdeflate compressor of its own rather than locking the shared one: the
 * lock would stay held until this thread got the GVL back, and every other call
 * on the compressor would wait for that handoff. The shared one is only used
 * with the GVL held, which serializes those calls.
 */
static void *
compress_without_gvl(void *ptr)
{
    struct compress_args *args = ptr;
    struct libdeflate_compressor *c = libdeflate_alloc_compressor(args->level);

    if (c == NULL) {
        return NULL;
    }

    args->result = args->func(c, args->in, args->in_nbytes, args->out, args->out_nbytes_avail);
    libdeflate_free_compressor(c);

    return args;
}

/*
 * call-seq:
 *    compressor.compress(str, format = DEFLATE, outbuf = nil) -> string
 *
 * Compresses the given string into <i>format</i>. Valid values of <i>format</i>
 * are DEFLATE (default), ZLIB and GZIP. If <i>outbuf</i> is given, the
 * resulting compressed data will be written to it.
 *
 * Strings of 16 KiB or more are compressed without holding the GVL, so other
 * threads keep running, and threads sharing a compressor compress them in
 * parallel.
 *
 *    compressor.compress('foo')                   #=> "\x01\x03\x00\xFC\xFFfoo"
 *    compressor.compress('foo', Libdeflate::ZLIB) #=> "x\x9C\x01\x03\x00\xFC\xFFfoo\x02\x82\x01E"
 *
 *    outbuf = 'bar'
 *    compressor.compress('foo', nil, outbuf) #=> "\x01\x03\x00\xFC\xFFfoo"
 *    outbuf                                  #=> "\x01\x03\x00\xFC\xFFfoo"
 */
static VALUE
rb_compressor_compress(int argc, VALUE *argv, VALUE self)
{
    struct compressor *compressor = check_compressor(self);
    struct compress_args args;
    VALUE str, format, outbuf, in, out;
    size_t (*compress_bound_func)(struct libdeflate_compressor *, size_t);

    rb_scan_args(argc, argv, "12", &str, &format, &outbuf);

    StringValue(str);

    switch (NIL_P(format) ? FORMAT_DEFLATE : FIX2INT(format)) {
        case FORMAT_DEFLATE:
            args.func = &libdeflate_deflate_compress;
            compress_bound_func = &libdeflate_deflate_compress_bound;
            break;
        case FORMAT_ZLIB:
            args.func = &libdeflate_zlib_compress;
            compress_bound_func = &libdeflate_zlib_compress_bound;
            break;
        case FORMAT_GZIP:
            args.func = &libdeflate_gzip_compress;
            compress_bound_func = &libdeflate_gzip_compress_bound;
            break;
        default:
            rb_raise(rb_eLibdefalteError, "unknown compressed data format: %d", FIX2INT(format));
    }

    if (!NIL_P(outbuf)) {
        StringValue(outbuf);
        rb_str_modify(outbuf);
    }

    /* Shares the caller's buffer; a later write to str copies it instead. */
    in = rb_str_new_frozen(str);
    /* A bound-sized buffer cannot run out of space, so there is no retry. */
    out = rb_str_buf_new(compress_bound_func(compressor->c, RSTRING_LEN(in)));

    args.level = compressor->level;
    args.in = RSTRING_PTR(in);
    args.in_nbytes = RSTRING_LEN(in);
    args.out = RSTRING_PTR(out);
    args.out_nbytes_avail = rb_str_capacity(out);
    args.result = 0;

    if (args.in_nbytes < NOGVL_MIN_BYTES) {
        args.result = args.func(compressor->c, args.in, args.in_nbytes, args.out, args.out_nbytes_avail);
    } else if (rb_thread_call_without_gvl(compress_without_gvl, &args, RUBY_UBF_IO, NULL) == NULL) {
        rb_raise(rb_eLibdefalteError, "libdeflate_alloc_compressor: compression_level=%d", args.level);
    }
    RB_GC_GUARD(in);

    if (args.result == 0) {
        rb_raise(rb_eLibdefalteError, "failed to compress data");
    }

    rb_str_set_len(out, args.result);

    if (NIL_P(outbuf)) {
        return out;
    }

    rb_str_resize(outbuf, 0);
    rb_str_buf_append(outbuf, out);

    return outbuf;
}

static void
decompressor_free(void *ptr)
{
    libdeflate_free_decompressor((struct libdeflate_decompressor *)ptr);
}

static const rb_data_type_t decompressor_data_type = {
    "decompressor",
    { NULL, decompressor_free, NULL, },
    0, 0, RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE
rb_decompressor_s_allocate(VALUE klass)
{
    return TypedData_Wrap_Struct(klass, &decompressor_data_type, 0);
}

/*
 * call-seq:
 *    initialize -> decompressor
 *
 * Returns a new Libdeflate::Decompressor object.
 *
 *    Libdeflate::Decompressor.new #=> #<Libdeflate::Decompressor:0x007fde591a6500>
 */
static VALUE
rb_decompressor_initialize(VALUE self)
{
    struct libdeflate_decompressor *d = libdeflate_alloc_decompressor();
    if (d == NULL) {
        rb_raise(rb_eLibdefalteError, "libdeflate_alloc_decompressor");
    }

    DATA_PTR(self) = d;

    return self;
}

static inline struct libdeflate_decompressor *
check_decompressor(VALUE self)
{
    return rb_check_typeddata(self, &decompressor_data_type);
}

static long
next_power_of_two(long n)
{
    n--;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
#if LONG_MAX > UINT32_MAX
    n |= n >> 32;
#endif
    n++;
    return n;
}

/*
 * call-seq:
 *    decompressor.decompress(str, format = nil, outbuf = nil) -> string
 *
 * Decompresses the given string compressed in <i>format</i>. Valid values of
 * <i>format</i> are DEFLATE (default), ZLIB and GZIP. If <i>outbuf</i> is
 * given, the resulting uncompressed data will be written to it.
 *
 *    decompressor.decompress("\x01\x03\x00\xFC\xFFfoo")
 *    #=> "foo"
 *    decompressor.decompress("x\x9C\x01\x03\x00\xFC\xFFfoo\x02\x82\x01E", Libdeflate::ZLIB)
 *    #=> "foo"
 *
 *    outbuf = 'bar'
 *    decompressor.decompress("\x01\x03\x00\xFC\xFFfoo", nil, outbuf) #=> "foo"
 *    outbuf                                                          #=> "foo"
 */
static VALUE
rb_compressor_decompress(int argc, VALUE *argv, VALUE self)
{
    struct libdeflate_decompressor *d = check_decompressor(self);
    VALUE str, format, outbuf;
    enum libdeflate_result (*decompress_func)(struct libdeflate_decompressor *, const void *, size_t, void *, size_t, size_t *);
    size_t actual_out_nbytes_ret;
    enum libdeflate_result decompress_result;

    rb_scan_args(argc, argv, "12", &str, &format, &outbuf);

    StringValue(str);

    switch (NIL_P(format) ? FORMAT_DEFLATE : FIX2INT(format)) {
        case FORMAT_DEFLATE:
            decompress_func = &libdeflate_deflate_decompress;
            break;
        case FORMAT_ZLIB:
            decompress_func = &libdeflate_zlib_decompress;
            break;
        case FORMAT_GZIP:
            decompress_func = &libdeflate_gzip_decompress;
            break;
        default:
            rb_raise(rb_eLibdefalteError, "unknown compressed data format: %d", FIX2INT(format));
    }

    if (NIL_P(outbuf)) {
        outbuf = rb_str_buf_new(next_power_of_two(RSTRING_LEN(str)) << 4);
    } else {
        StringValue(outbuf);
        rb_str_modify(outbuf);
    }

    for (;;) {
        decompress_result = decompress_func(d,
                                            RSTRING_PTR(str),
                                            RSTRING_LEN(str),
                                            RSTRING_PTR(outbuf),
                                            rb_str_capacity(outbuf),
                                            &actual_out_nbytes_ret);

        if (decompress_result != LIBDEFLATE_INSUFFICIENT_SPACE) {
            break;
        }

        rb_str_modify_expand(outbuf, (rb_str_capacity(outbuf) << 1) - RSTRING_LEN(outbuf));
    }

    if (decompress_result == LIBDEFLATE_BAD_DATA) {
        rb_raise(rb_eBadDataError, "failed to decompress data");
    } else if (decompress_result != LIBDEFLATE_SUCCESS) {
        rb_raise(rb_eLibdefalteError, "failed to decompress data");
    }

    rb_str_set_len(outbuf, actual_out_nbytes_ret);

    return outbuf;
}

void
Init_libdeflate_ext(void)
{
    VALUE rb_mLibdeflate, rb_cCompressor, rb_cDecompressor;

    rb_mLibdeflate = rb_define_module("Libdeflate");
    rb_eLibdefalteError = rb_define_class_under(rb_mLibdeflate, "Error", rb_eStandardError);
    rb_eBadDataError = rb_define_class_under(rb_mLibdeflate, "BadDataError", rb_eLibdefalteError);

    /*
     * Default compression level which is a compromise between speed and compression ratio
     *
     * See Compressor#initialize.
     */
    rb_define_const(rb_mLibdeflate, "DEFAULT_COMPRESSION", INT2FIX(DEFAULT_COMPRESSION));

    /*
     * DEFLATE compressed data format
     *
     * See Compressor#compress and Decompressor#decompress.
     */
    rb_define_const(rb_mLibdeflate, "DEFLATE", INT2FIX(FORMAT_DEFLATE));

    /*
     * ZLIB compressed data format
     *
     * See Compressor#compress and Decompressor#decompress.
     */
    rb_define_const(rb_mLibdeflate, "ZLIB", INT2FIX(FORMAT_ZLIB));

    /*
     * GZIP compressed data format
     *
     * See Compressor#compress and Decompressor#decompress.
     */
    rb_define_const(rb_mLibdeflate, "GZIP", INT2FIX(FORMAT_GZIP));

    rb_define_module_function(rb_mLibdeflate, "adler32", rb_libdeflate_adler32, -1);
    rb_define_module_function(rb_mLibdeflate, "crc32", rb_libdeflate_crc32, -1);

    rb_cCompressor = rb_define_class_under(rb_mLibdeflate, "Compressor", rb_cObject);
    rb_define_alloc_func(rb_cCompressor, rb_compressor_s_allocate);
    rb_define_method(rb_cCompressor, "initialize", rb_compressor_initialize, -1);
    rb_define_method(rb_cCompressor, "compress", rb_compressor_compress, -1);

    rb_cDecompressor = rb_define_class_under(rb_mLibdeflate, "Decompressor", rb_cObject);
    rb_define_alloc_func(rb_cDecompressor, rb_decompressor_s_allocate);
    rb_define_method(rb_cDecompressor, "initialize", rb_decompressor_initialize, 0);
    rb_define_method(rb_cDecompressor, "decompress", rb_compressor_decompress, -1);
}
