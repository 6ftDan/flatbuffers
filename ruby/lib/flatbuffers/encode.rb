module FlatBuffers
  module Encode
    def self.get packer_type, buf, head
      #""" Get decodes a value at buf[head:] using `packer_type`. """
      packer_type.unpack_from(memoryview_type(buf), head)[0]
    end

    def self.write packer_type, buf, head, n
      #""" Write encodes `n` at buf[head:] using `packer_type`. """
      packer_type.pack_into buf, head, n
    end
  end
end
