require 'benchmark/ips'
require 'libdeflate'
require 'zlib'

Benchmark.ips do |x|
  str = File.read(File.expand_path('./alice29.txt', __dir__))

  (1..12).each do |level|
    compressor = Libdeflate::Compressor.new(level)
    x.report(format("libdeflate (format = zlib, level = %2d)", level)) do
      compressor.compress(str, Libdeflate::ZLIB)
    end
  end

  (0..9).each do |level|
    x.report(format("zlib       (format = zlib, level = %2d)", level)) do
      Zlib.deflate(str, level)
    end
  end

  x.compare!
end
