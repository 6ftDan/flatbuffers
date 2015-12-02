require_relative "flatbuffers/number_types"

module FlatBuffers
  class Builder
    MAX_BUFFER_SIZE = 2**31
    
    def initialize initial_size
      #"""
      #Initializes a Builder of size `initial_size`.
      #The internal buffer is grown as needed.
      #"""

      unless (0..MAX_BUFFER_SIZE).include? initial_size
        msg = "flatbuffers: Cannot create Builder larger than 2 gigabytes."
        raise BuilderSizeError(msg)
      end

      @bytes = Array.new(initial_size, 0)
      @current_vtable = nil
      @head = UOffsetTFlags.rb_type(initial_size)
      @minalign = 1
      @object_end = nil
      @vtables = []
      @nested = false
      @finished = false
    end

    def bytes x = nil
      @bytes ||= x
      @bytes
    end

    def head x = nil
      @head ||= x
      @head
    end

    def prepend_bool bool
      @bytes.unshift bool ? 0b1 : 0b0
    end

    def prepend_int8 int8
      @bytes.unshift int8 & 0xff
    end

    def prepend_uint8 uint8
      @bytes.unshift uint8 & 0xff
    end

    def prepend_int16 int16
      @bytes.unshift *[int16].pack("sx").bytes
    end
    
    def prepend_uint16 uint16
      @bytes.unshift *[uint16].pack("v").bytes
    end

    def prepend_int32 int32
      @bytes.unshift *[int32].pack("V").bytes
    end

    def prepend_uint32 uint32
      @bytes.unshift *[uint32].pack("V").bytes
    end

    def prepend_uint64 uint64
      @bytes.unshift *[uint64].pack("Q").bytes
    end
    
    def prepend_int64 int64
      @bytes.unshift *[int64].pack("q").bytes
    end
  end  
end
