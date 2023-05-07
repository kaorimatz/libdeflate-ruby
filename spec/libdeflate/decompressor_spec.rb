require 'spec_helper'

RSpec.describe Libdeflate::Decompressor do
  let(:decompressor) { described_class.new }

  describe '#decompress' do
    context 'when str is invalid' do
      it 'raises BadDataError' do
        expect { decompressor.decompress('foo') }.to raise_error(Libdeflate::BadDataError)
      end
    end

    context 'when format is nil' do
      it 'decompresses the given string, assuming the deflate format' do
        expect(decompressor.decompress("\x01\x03\x00\xFC\xFFfoo")).to eq('foo')
      end
    end

    context 'when format is given' do
      it 'decompresses the given string, assuming the given format' do
        expect(decompressor.decompress("\x01\x03\x00\xFC\xFFfoo".b, Libdeflate::DEFLATE)).to eq('foo')
        expect(decompressor.decompress("x\x9C\x01\x03\x00\xFC\xFFfoo\x02\x82\x01E".b, Libdeflate::ZLIB)).to eq('foo')
        expect(decompressor.decompress("\x1F\x8B\b\x00\x00\x00\x00\x00\x00\xFF\x01\x03\x00\xFC\xFFfoo!es\x8C\x03\x00\x00\x00".b, Libdeflate::GZIP)).to eq('foo')
      end
    end

    context 'when invalid format is given' do
      it 'raises an error' do
        expect { decompressor.decompress("\x01\x03\x00\xFC\xFFfoo".b, -1) }.to raise_error(Libdeflate::Error)
      end
    end

    context 'when outbuf is an empty string' do
      let(:outbuf) { ''.b }

      it 'decompresses the given string and writes the result to outbuf' do
        expect(decompressor.decompress("\x01\x03\x00\xFC\xFFfoo".b, nil, outbuf)).to eq('foo')
        expect(outbuf).to eq('foo')
      end
    end

    context 'when outbuf is a non-empty string' do
      let(:outbuf) { 'bar'.b }

      it 'compresses the given string and writes the result to outbuf' do
        expect(decompressor.decompress("\x01\x03\x00\xFC\xFFfoo".b, nil, outbuf)).to eq('foo')
        expect(outbuf).to eq('foo')
      end
    end

    context 'when outbuf is frozen' do
      it 'raises a RuntimeError' do
        expect { decompressor.decompress("\x01\x03\x00\xFC\xFFfoo".b, nil, ''.freeze) }.to raise_error(RuntimeError)
      end
    end
  end
end
