require 'mkmf'

dir_config('libdeflate')

unless arg_config('--use-system-libraries', !!ENV['LIBDEFLATE_USE_SYSTEM_LIBRARIES'])
  require 'mini_portile2'
  recipe = MiniPortileCMake.new('libdeflate', '1.18')
  recipe.files << {
    url: 'https://github.com/ebiggers/libdeflate/archive/refs/tags/v1.18.tar.gz',
    sha256: '225d982bcaf553221c76726358d2ea139bb34913180b20823c782cede060affd',
  }
  recipe.configure_options << %w[
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
    -DLIBDEFLATE_BUILD_GZIP=OFF
    -DLIBDEFLATE_BUILD_SHARED_LIB=OFF
  ]
  recipe.cook
  abort 'libdeflate.h not found' unless find_header('libdeflate.h', "#{recipe.path}/include")
  abort 'libdeflate not found' unless find_library('deflate', 'libdeflate_alloc_compressor', "#{recipe.path}/lib")
else
  abort 'libdeflate.h not found' unless find_header('libdeflate.h')
  abort 'libdeflate not found' unless find_library('deflate', 'libdeflate_alloc_compressor')
end

create_makefile('libdeflate/libdeflate_ext')
