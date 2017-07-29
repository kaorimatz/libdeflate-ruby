require 'benchmark/ips'
require 'libdeflate'
require 'zlib'

Benchmark.ips do |x|
  uncompressed_str = File.read(File.expand_path('./alice29.txt', __dir__))

  (1..12).each do |level|
    compressor = Libdeflate::Compressor.new(level)
    str = compressor.compress(uncompressed_str, Libdeflate::ZLIB)
    decompressor = Libdeflate::Decompressor.new
    x.report(format("libdeflate (format = zlib, level = %2d)", level)) do
      decompressor.decompress(str, Libdeflate::ZLIB)
    end
  end

  (0..9).each do |level|
    str = Zlib.deflate(uncompressed_str, level)
    x.report(format("zlib       (format = zlib, level = %2d)", level)) do
      Zlib.inflate(str)
    end
  end

  x.compare!
end
