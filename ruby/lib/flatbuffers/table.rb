module FlatBuffers
  class Table
    #"""Table wraps a byte slice and provides read access to its data.
    #
    #The variable `Pos` indicates the root of the FlatBuffers object therein."""
    attr_accessor :bytes, :pos

    N = NumberTypes

    def initialize buf, pos
      N.enforce_number pos, N::UOffsetTFlags

      @bytes = buf
      @pos = pos
    end

    def offset vtable_offset
      #"""Offset provides access into the Table's vtable.
      #
      #Deprecated fields are ignored by checking the vtable's length."""

      vtable = @pos - get(N::SOffsetTFlags, @pos)
      vtable_end = get N::VOffsetTFlags, vtable
      if vtable_offset < vtable_end
        get N::VOffsetTFlags, vtable + vtable_offset
      else
        0
      end
    end

    def indirect off
      #"""Indirect retrieves the relative offset stored at `offset`."""
      N.enforce_number off, N::UOffsetTFlags
      off + Encode.get(N::UOffsetTFlags.packer_type, @bytes, off)
    end

    def string off
      #"""String gets a string from data stored inside the flatbuffer."""
      N.enforce_number off, N::UOffsetTFlags
      off += Encode.get(N::UOffsetTFlags.packer_type, @bytes, off)
      start = off + N::UOffsetTFlags.bytewidth
      length = Encode.get N::UOffsetTFlags.packer_type, @bytes, off
      @bytes[start..start+length].join
    end

    def vector_len off
      #"""VectorLen retrieves the length of the vector whose offset is stored
      #   at "off" in this object."""
      N.enforce_number off, N::UOffsetTFlags

      off += @pos
      off += Encode.get(N::UOffsetTFlags.packer_type, @bytes, off)
      ret = Encode.get N::UOffsetTFlags.packer_type, @bytes, off
      ret
    end

    def vector off
      #"""Vector retrieves the start of data of the vector whose offset is
      #   stored at "off" in this object."""
      N.enforce_number off, N::UOffsetTFlags

      off += @pos
      x = off + get(N::UOffsetTFlags, off)
      # data starts after metadata containing the vector length
      x += N::UOffsetTFlags.bytewidth
      x
    end

    def union t2, off
      #"""Union initializes any Table-derived type to point to the union at
      #   the given offset."""
      raise unless t2.is_a? Table
      N.enforce_number off, N::UOffsetTFlags

      off += @pos
      t2.pos = off + get(N::UOffsetTFlags, off)
      t2.bytes = @bytes
    end

    def get flags, off
      #"""
      #Get retrieves a value of the type specified by `flags`  at the
      #given offset.
      #"""
      N.enforce_number off, N::UOffsetTFlags
      flags.rb_type Encode.get(flags.packer_type, @bytes, off)
    end

    def get_slot slot, d, validator_flags
      N.enforce_number slot, N::VOffsetTFlags
      if validator_flags
        N.enforce_number d, validator_flags
      end
      off = offset slot
      if off == 0
        return d
      end
      get validator_flags, @pos + off
    end

    def get_voffsett_slot slot, d
      #"""
      #GetVOffsetTSlot retrieves the VOffsetT that the given vtable location
      #points to. If the vtable value is zero, the default value `d`
      #will be returned.
      #"""

      N.enforce_number slot, N::VOffsetTFlags
      N.enforce_number d,    N::VOffsetTFlags

      off = offset slot
      if off == 0
        return d
      end
      off
    end
  end
end
