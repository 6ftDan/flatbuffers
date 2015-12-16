module FlatBuffers

  Packer = Struct.new :fmt do
    def pack *values
      values.pack fmt
    end

    def pack_into buffer, offset, *values
      buffer[offset] = values.pack fmt 
    end

    def unpack string
      string.unpack fmt
    end

    def unpack_from buffer, offset = 0
      buffer.join.unpack(fmt)[offset]
    end
  end

  BooleanPacker = Packer.new "c*"

  Uint8Packer   = Packer.new "C*"
  Uint16Packer  = Packer.new "S*"
  Uint32Packer  = Packer.new "L*"
  Uint64Packer  = Packer.new "Q*"

  Int8Packer    = Packer.new "c*"
  Int16Packer   = Packer.new "s*"
  Int32Packer   = Packer.new "l*"
  Int64Packer   = Packer.new "q*"

  Float32Packer = Packer.new "F*"
  Float64Packer = Packer.new "D*"

  UoffsetPacker = Uint32Packer
  SoffsetPacker = Int32Packer
  VoffsetPacker = Uint16Packer
end
