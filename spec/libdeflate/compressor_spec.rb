require 'spec_helper'

RSpec.describe Libdeflate::Compressor do
  let(:compressor) { described_class.new }

  describe '#initialize' do
    context 'when level is out of range' do
      it 'raises an error' do
        expect { described_class.new(-2) }.to raise_error(Libdeflate::Error)
        expect { described_class.new(13) }.to raise_error(Libdeflate::Error)
      end
    end
  end

  describe '#compress' do
    context 'when format is nil' do
      it 'compresses the given string into deflate format' do
        expect(compressor.compress('foo')).to eq("\x01\x03\x00\xFC\xFFfoo".b)
      end
    end

    context 'when format is given' do
      it 'compresses the given string into the given format' do
        expect(compressor.compress('foo', Libdeflate::DEFLATE)).to eq("\x01\x03\x00\xFC\xFFfoo".b)
        expect(compressor.compress('foo', Libdeflate::ZLIB)).to eq("x\x9C\x01\x03\x00\xFC\xFFfoo\x02\x82\x01E".b)
        expect(compressor.compress('foo', Libdeflate::GZIP)).to eq("\x1F\x8B\b\x00\x00\x00\x00\x00\x00\xFF\x01\x03\x00\xFC\xFFfoo!es\x8C\x03\x00\x00\x00".b)
      end
    end

    context 'when invalid format is given' do
      it 'raises an error' do
        expect { compressor.compress('foo', -1) }.to raise_error(Libdeflate::Error)
      end
    end

    context 'when outbuf is an empty string' do
      let(:outbuf) { ''.b }

      it 'compresses the given string and writes the result to outbuf' do
        expect(compressor.compress('foo', nil, outbuf)).to eq("\x01\x03\x00\xFC\xFFfoo".b)
        expect(outbuf).to eq("\x01\x03\x00\xFC\xFFfoo".b)
      end
    end

    context 'when outbuf is a non-empty string' do
      let(:outbuf) { 'bar'.b }

      it 'compresses the given string and writes the result to outbuf' do
        expect(compressor.compress('foo', nil, outbuf)).to eq("\x01\x03\x00\xFC\xFFfoo".b)
        expect(outbuf).to eq("\x01\x03\x00\xFC\xFFfoo".b)
      end
    end

    context 'when the input is large' do
      let(:input) { Array.new(20_000) { |i| "<div class=\"r#{i % 97}\">result #{i}</div>" }.join.b }

      it 'round-trips through zlib in every format' do
        require 'zlib'

        expect(Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(compressor.compress(input))).to eq(input)
        expect(Zlib::Inflate.inflate(compressor.compress(input, Libdeflate::ZLIB))).to eq(input)
        expect(Zlib.gunzip(compressor.compress(input, Libdeflate::GZIP))).to eq(input)
      end

      it 'writes the result to a short outbuf' do
        outbuf = 'bar'.b

        expect(compressor.compress(input, Libdeflate::GZIP, outbuf)).to equal(outbuf)
        expect(Zlib.gunzip(outbuf)).to eq(input)
      end

      it 'leaves the input string unfrozen and unchanged' do
        copy = input.dup
        compressor.compress(input)

        expect(input).not_to be_frozen
        expect(input).to eq(copy)
      end

      it 'lets other threads run while it compresses' do
        big = input * 64
        ticks = []
        stop = false
        ticker = Thread.new { ticks << Process.clock_gettime(Process::CLOCK_MONOTONIC) until stop }
        Thread.pass while ticks.empty?

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        compressor.compress(big, Libdeflate::GZIP)
        finished_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        stop = true
        ticker.join

        during = ticks.select { |t| t > started_at && t < finished_at }
        longest_gap = ([started_at] + during + [finished_at]).each_cons(2).map { |a, b| b - a }.max

        expect(longest_gap).to be < (finished_at - started_at) / 2
      end

      it 'compresses correctly when threads share one compressor' do
        inputs = Array.new(16) { |i| input + i.to_s }
        outputs = inputs.map { |s| Thread.new { Array.new(5) { compressor.compress(s, Libdeflate::GZIP) } } }.map(&:value)

        outputs.each_with_index do |results, i|
          results.each { |gz| expect(Zlib.gunzip(gz)).to eq(inputs[i]) }
        end
      end

      it 'keeps threads sharing a compressor as fast as threads with their own while other threads hold the GVL' do
        big = input * 2
        stop = false
        busy = Array.new(2) { Thread.new { nil until stop } }
        begin
          compressors = Array.new(16) { |i| i.even? ? compressor : described_class.new }
          walls = compressors.map do |c|
            Thread.new do
              started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              c.compress(big)
              Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
            end
          end.map(&:value)
        ensure
          stop = true
          busy.each(&:join)
        end
        shared, own = walls.each_slice(2).to_a.transpose.map(&:sort)
        ms = ->(times) { times.map { |t| (t * 1000).round } }

        # own[6] leaves out the slowest thread with its own compressor: on Ruby 2.7 one can miss a GVL handoff.
        expect(shared[4]).to be < own[6] * 2, "shared: #{ms.call(shared)} ms, own: #{ms.call(own)} ms"
      end

      it 'compresses at the level the compressor was created with' do
        expect(described_class.new(1).compress(input).bytesize).to be > described_class.new(12).compress(input).bytesize
      end
    end

    context 'when the compressor is not initialized' do
      it 'raises an error' do
        expect { described_class.allocate.compress('foo') }.to raise_error(Libdeflate::Error)
      end
    end

    context 'when outbuf is frozen' do
      it 'raises a RuntimeError' do
        expect { compressor.compress('foo', nil, ''.freeze) }.to raise_error(RuntimeError)
      end
    end
  end
end
