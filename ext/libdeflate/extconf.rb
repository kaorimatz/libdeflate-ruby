require 'mkmf'

dir_config('libdeflate')

if arg_config('--use-system-libraries', !!ENV['LIBDEFLATE_USE_SYSTEM_LIBRARIES'])
  abort 'libdeflate.h not found' unless find_header('libdeflate.h')
  abort 'libdeflate not found' unless find_library('deflate', 'libdeflate_alloc_compressor')
  $srcs = ['libdeflate_ext.c']
else
  # The vendored libdeflate (see libdeflate/VERSION) compiles with the extension
  # itself: no cmake, no download at install time. Each ld_*.c includes one
  # library source so object names stay unique (arm/ and x86/ both have
  # cpu_features.c).
  $INCFLAGS << ' -I$(srcdir)/libdeflate'
  $srcs = ['libdeflate_ext.c'] + Dir.glob(File.join(__dir__, 'ld_*.c')).map { |f| File.basename(f) }.sort
end

create_makefile('libdeflate/libdeflate_ext')
