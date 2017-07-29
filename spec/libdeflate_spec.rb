require 'spec_helper'

RSpec.describe Libdeflate do
  describe '.adler32' do
    context 'when str is nil' do
      it 'returns the initial value of Adler-32 checksum' do
        expect(Libdeflate.adler32).to eq(1)
        expect(Libdeflate.adler32(nil, 42)).to eq(1)
        expect(Libdeflate.adler32(nil, -42)).to eq(1)
      end
    end

    context 'when adler is nil' do
      it 'calculates Adler-32 checksum for the given string and the initial value of Adler-32 checksum' do
        expect(Libdeflate.adler32('')).to eq(1)
        expect(Libdeflate.adler32('foo')).to eq(42_074_437)
      end
    end

    context 'when both str and adler are not nil' do
      it 'calculates Adler-32 checksum for the given string and Adler-32 checksum' do
        expect(Libdeflate.adler32('', 42)).to eq(42)
        expect(Libdeflate.adler32('foo', 42)).to eq(50_135_406)
      end
    end
  end

  describe '.crc32' do
    context 'when str is nil' do
      it 'returns the initial value of CRC-32 checksum' do
        expect(Libdeflate.crc32).to eq(0)
        expect(Libdeflate.crc32(nil, 42)).to eq(0)
        expect(Libdeflate.crc32(nil, -42)).to eq(0)
      end
    end

    context 'when adler is nil' do
      it 'calculates CRC-32 checksum for the given string and the initial value of CRC-32 checksum' do
        expect(Libdeflate.crc32('')).to eq(0)
        expect(Libdeflate.crc32('foo')).to eq(2_356_372_769)
      end
    end

    context 'when both str and adler are not nil' do
      it 'calculates CRC-32 checksum for the given string and CRC-32 checksum' do
        expect(Libdeflate.crc32('', 42)).to eq(42)
        expect(Libdeflate.crc32('foo', 42)).to eq(3_114_903_063)
      end
    end
  end
end
