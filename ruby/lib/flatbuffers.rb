require "flatbuffers/number_types"
require "flatbuffers/packer"
require "flatbuffers/encode"

module FlatBuffers
  class Builder
    MAX_BUFFER_SIZE = 2**31
    N = NumberTypes
    
    attr_accessor :minalign, :bytes, :head
    
    def initialize initial_size
      #"""
      #Initializes a Builder of size `initial_size`.
      #The internal buffer is grown as needed.
      #"""

      unless (0..MAX_BUFFER_SIZE).include? initial_size
        msg = "flatbuffers: Cannot create Builder larger than 2 gigabytes."
        raise BuilderSizeError(msg)
      end

      @bytes = Array.new initial_size, 0
      @current_vtable = nil
      @head = N::UOffsetTFlags.rb_type(initial_size)
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


    def start_vector elem_size, num_elems, alignment
      #"""
      #StartVector initializes bookkeeping for writing a new vector.
      #
      #A vector has the following format:
      #  <UOffsetT: number of elements in this vector>
      #  <T: data>+, where T is the type of elements of this vector.
      #"""

      assert_not_nested
      @nested = true
      prep N::Uint32Flags.new.bytewidth, elem_size * num_elems
      prep alignment, elem_size * num_elems  # In case alignment > int.
      offset
    end

    def end_vector vector_num_elems
      #"""EndVector writes data necessary to finish vector construction."""

      assert_nested
      @nested = false
      # we already made space for this, so write without PrependUint32
      place_UOffsetT vector_num_elems
      offset
    end


    def prep size, additional_bytes
      #"""
      #Prep prepares to write an element of `size` after `additional_bytes`
      #have been written, e.g. if you write a string, you need to align
      #such the int length field is aligned to SizeInt32, and the string
      #data follows it directly.
      #If all you need to do is align, `additional_bytes` will be 0.
      #"""

      # Track the biggest thing we've ever aligned to.
      if size > self.minalign
        self.minalign = size
      end

      # Find the amount of alignment needed such that `size` is properly
      # aligned after `additional_bytes`:
      align_size = (~(self.bytes.length - self.head + additional_bytes)) + 1
      align_size &= (size - 1)

      # Reallocate the buffer if needed:
      while self.head < align_size + size + additional_bytes
        old_buf_size = self.bytes.length
        self.grow_byte_buffer
        updated_head = self.head + self.bytes.length - old_buf_size
        self.head = N::UOffsetTFlags.rb_type(updated_head)
      end
      self.pad(align_size)
    end


    def grow_byte_buffer
      #"""Doubles the size of the byteslice, and copies the old data towards
      #   the end of the new buffer (since we build the buffer backwards)."""
      if self.bytes.length == MAX_BUFFER_SIZE
        msg = "flatbuffers: cannot grow buffer beyond 2 gigabytes"
        raise BuilderSizeError, msg
      end

      new_size = [self.bytes.length * 2, MAX_BUFFER_SIZE].min
      if new_size == 0
        new_size = 1
      end
      bytes2 = Array.new(new_size, 0b0)
      bytes2[new_size-self.bytes.length] = self.bytes
      self.bytes = bytes2
    end

    def pad n
      #"""Pad places zeros at the current offset."""
      n.times do
        self.place 0, N::Uint8Flags.new
      end
    end

    def place x, flags
      #"""
      #Place prepends a value specified by `flags` to the Builder,
      #without checking for available space.
      #"""

      x = N.enforce_number x, flags
      self.head = self.head - flags.bytewidth
      Encode.write flags.packer_type, self.bytes, self.head, x
    end

    def offset
      #"""Offset relative to the end of the buffer."""
      N::UOffsetTFlags.rb_type(self.bytes.length - self.head)
    end

    private
    class NestedError < StandardError; end
    def assert_not_nested
      raise NestedError, "Error; it's nested" if @nested
    end

    class NotNestedError < StandardError; end
    def assert_nested
      raise NotNestedError, "Error; it's not nested" unless @nested
    end

    class BuilderSizeError < StandardError; end
  end  
end
