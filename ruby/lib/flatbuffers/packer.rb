module FlatBuffers
  Packer = Struct.new :fmt do
    def pack *values

    end

    def pack_into buffer, offset, *values

    end

    def unpack string

    end

    def unpack_from buffer, offset = 0

    end

    def calcsize

    end
  end

  BooleanPacker = Packer.new "<b"

  Uint8Packer   = Packer.new "<B"
  Uint16Packer  = Packer.new "<H"
  Uint32Packer  = Packer.new "<I"
  Uint64Packer  = Packer.new "<Q"

  Int8Packer    = Packer.new "<b"
  Int16Packer   = Packer.new "<h"
  Int32Packer   = Packer.new "<i"
  Int64Packer   = Packer.new "<q"

  Float32Packer = Packer.new "<f"
  Float64Packer = Packer.new "<d"

  UoffsetPacker = Uint32Packer
  SoffsetPacker = Int32Packer
  VoffsetPacker = Uint16Packer
end
