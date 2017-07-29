require 'spec_helper'

RSpec.describe Libdeflate::Compressor do
  let(:compressor) { described_class.new }

  describe '#initialize' do
    context 'when level is out of range' do
      it 'raises an error' do
        expect { described_class.new(0) }.to raise_error(Libdeflate::Error)
        expect { described_class.new(13) }.to raise_error(Libdeflate::Error)
      end
    end
  end

  describe '#compress' do
    context 'when str is not tainted' do
      it 'compresses the given string and doesn\'t taints the result' do
        expect(compressor.compress('foo')).not_to be_tainted
      end
    end

    context 'when str is tainted' do
      it 'compresses the given string and taints the result' do
        expect(compressor.compress('foo'.taint)).to be_tainted
      end
    end

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

    context 'when outbuf is frozen' do
      it 'raises a RuntimeError' do
        expect { compressor.compress('foo', nil, ''.freeze) }.to raise_error(RuntimeError)
      end
    end
  end
end
