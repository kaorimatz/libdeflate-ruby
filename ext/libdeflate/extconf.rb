require 'mkmf'

dir_config('libdeflate')

if enable_config('bundled-libdeflate', false) || !(find_header('libdeflate.h') && have_library('deflate'))
  $VPATH << '$(srcdir)/libdeflate/lib'
  $INCFLAGS << ' -I$(srcdir)/libdeflate -I$(srcdir)/libdeflate/common'

  $srcs = Dir.glob(File.join($srcdir, '*.c'))
  $srcs += Dir.glob(File.join($srcdir, 'libdeflate', 'lib', '*.c'))
  $srcs.sort!
end

create_makefile('libdeflate/libdeflate_ext')
