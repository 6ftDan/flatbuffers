require "flatbuffers/packer"
require "flatbuffers/encode"
require "flatbuffers/number_types"

module FlatBuffers

  # VtableMetadataFields is the count of metadata fields in each vtable.
  VtableMetadataFields = 2

  class Builder
    MAX_BUFFER_SIZE = 2**31
    N = NumberTypes
    
    attr_accessor :minalign, :bytes, :head, :current_vtable, :object_end,
                  :nested
    
    def initialize initial_size
      #"""
      #Initializes a Builder of size `initial_size`.
      #The internal buffer is grown as needed.
      #"""

      unless (0..MAX_BUFFER_SIZE).include? initial_size
        msg = "flatbuffers: Cannot create Builder larger than 2 gigabytes."
        raise BuilderSizeError(msg)
      end

      @bytes = Array.new initial_size, 0b0
      @current_vtable = nil
      @head = N::UOffsetTFlags.rb_type(initial_size)
      @minalign = 1
      @object_end = nil
      @vtables = []
      @nested = false
      @finished = false
    end

    def start_object numfields
      #"""StartObject initializes bookkeeping for writing a new object."""

      assert_not_nested

      # use 32-bit offsets so that arithmetic doesn't overflow.
      self.current_vtable = Array.new numfields, 0 
      self.object_end = self.offset
      self.minalign = 1
      self.nested = true
    end


    def write_vtable
      #"""
      #WriteVtable serializes the vtable for the current object, if needed.

      #Before writing out the vtable, this checks pre-existing vtables for
      #equality to this one. If an equal vtable is found, point the object to
      #the existing vtable and return.

      #Because vtable values are sensitive to alignment of object data, not
      #all logically-equal vtables will be deduplicated.

      #A vtable has the following format:
      #  <VOffsetT: size of the vtable in bytes, including this value>
      #  <VOffsetT: size of the object in bytes, including the vtable offset>
      #  <VOffsetT: offset for a field> * N, where N is the number of fields
      #             in the schema for this type. Includes deprecated fields.
      #Thus, a vtable is made of 2 + N elements, each VOffsetT bytes wide.

      #An object has the following format:
      #  <SOffsetT: offset to this object's vtable (may be negative)>
      #  <byte: data>+
      #"""

      # Prepend a zero scalar to the object. Later in this function we'll
      # write an offset here that points to the object's vtable:
      self.prepend_soffsett_relative 0

      object_offset = self.offset
      existing_vtable = nil 

      # Search backwards through existing vtables, because similar vtables
      # are likely to have been recently appended. See
      # BenchmarkVtableDeduplication for a case in which this heuristic
      # saves about 30% of the time used in writing objects with duplicate
      # tables.

      i = self.vtables.length - 1
      while i >= 0
        # Find the other vtable, which is associated with `i`:
        vt2_offset = self.vtables[i]
        vt2_start = self.bytes.length - vt2_offset
        vt2_len = encode.get(packer.voffset, self.bytes, vt2_start)

        metadata = VtableMetadataFields * N::VOffsetTFlags.bytewidth
        vt2_end = vt2_start + vt2_len
        vt2 = self.bytes[vt2_start+metadata..vt2_end]

        # Compare the other vtable to the one under consideration.
        # If they are equal, store the offset and break:
        if vtable_equal(self.current_vtable, object_offset, vt2)
          existing_vtable = vt2_offset
          break
        end
        i -= 1
      end
      if existing_vtable.nil?
        # Did not find a vtable, so write this one to the buffer.

        # Write out the current vtable in reverse , because
        # serialization occurs in last-first order:
        i = self.current_vtable.length - 1
        while i >= 0
            off = 0
            if self.current_vtable[i] != 0
                # Forward reference to field;
                # use 32bit number to ensure no overflow:
                off = objectOffset - self.current_vtable[i]
            end
            self.prepend_voffsett off
            i -= 1
        end

        # The two metadata fields are written last.

        # First, store the object bytesize:
        object_size = N::UOffsetTFlags.rb_type object_offset - self.object_end
        self.prepend_voffsett N::VOffsetTFlags.rb_type object_size

        # Second, store the vtable bytesize:
        vbytes = self.current_vtable.length + VtableMetadataFields
        vbytes *= N::VOffsetTFlags.bytewidth
        self.prepend_voffsett N::VOffsetTFlags.rb_type vbytes

        # Next, write the offset to the new vtable in the
        # already-allocated SOffsetT at the beginning of this object:
        object_start = N::SOffsetTFlags.rb_type self.bytes.length - object_offset
        encode.write packer.soffset, self.bytes, object_start,
                     N::SOffsetTFlags.rb_type( self.offset - object_offset )

        # Finally, store this vtable in memory for future
        # deduplication:
        self.vtables.append self.offset
      else
        # Found a duplicate vtable.

        object_start = N::SOffsetTFlags.rb_type(self.bytes.length - object_offset)
        self.head = N::UOffsetTFlags.rb_type(object_start)

        # Write the offset to the found vtable in the
        # already-allocated SOffsetT at the beginning of this object:
        encode.write packer.soffset, self.bytes, self.head,
                     N::SOffsetTFlags.rb_type( existing_vtable - object_offset )
      end
      self.current_vtable = nil
      object_offset
    end


    def end_object
      #"""EndObject writes data necessary to finish object construction."""
      assert_nested
      self.nested = false
      write_vtable
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

    def prepend_soffsett_relative off
      #"""
      #PrependSOffsetTRelative prepends an SOffsetT, relative to where it
      #will be written.
      #"""

      # Ensure alignment is already done:
      self.prep N::SOffsetTFlags.bytewidth, 0
      if not off <= self.offset
        msg = "flatbuffers: Offset arithmetic error."
        raise OffsetArithmeticError, msg
      end
      off2 = self.offset - off + N::SOffsetTFlags.bytewidth
      self.place_soffsett off2
    end

    def prepend_uoffsett_relative off
      #"""
      #PrependUOffsetTRelative prepends an UOffsetT, relative to where it
      #will be written.
      #"""

      # Ensure alignment is already done:
      self.prep N::UOffsetTFlags.bytewidth, 0
      if not off <= self.offset
        msg = "flatbuffers: Offset arithmetic error."
        raise OffsetArithmeticError, msg
      end
      off2 = self.offset - off + N::UOffsetTFlags.bytewidth
      self.place_uoffsett off2
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
      self.nested = true
      prep N::Uint32Flags.bytewidth, elem_size * num_elems
      prep alignment, elem_size * num_elems  # In case alignment > int.
      offset
    end

    def end_vector vector_num_elems
      #"""EndVector writes data necessary to finish vector construction."""

      assert_nested
      self.nested = false
      # we already made space for this, so write without PrependUint32
      place_uoffsett vector_num_elems
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
      bytes2 = Array.new new_size, 0b0
      bytes2[new_size-self.bytes.length] = self.bytes
      self.bytes = bytes2
    end

    def pad n
      #"""Pad places zeros at the current offset."""
      n.times do
        self.place 0, N::Uint8Flags
      end
    end

    def place x, flags
      #"""
      #Place prepends a value specified by `flags` to the Builder,
      #without checking for available space.
      #"""

      x = N.enforce_number x, flags
      self.head -= flags.bytewidth
      Encode.write flags.packer_type, self.bytes, self.head, x
    end

    def offset
      #"""Offset relative to the end of the buffer."""
      N::UOffsetTFlags.rb_type(self.bytes.length - self.head)
    end

    private
    def assert_not_nested
      raise IsNestedError, "Error; it's nested" if @nested
    end

    def assert_nested
      raise IsNotNestedError, "Error; it's not nested" unless @nested
    end

    class OffsetArithmeticError < RuntimeError
    #"""
    #Error caused by an Offset arithmetic error. Probably caused by bad
    #writing of fields. This is considered an unreachable situation in
    #normal circumstances.
    #"""
    end

    class IsNotNestedError < RuntimeError
    #"""
    #Error caused by using a Builder to write Object data when not inside
    #an Object.
    #"""
    end


    class IsNestedError < RuntimeError
    #"""
    #Error caused by using a Builder to begin an Object when an Object is
    #already being built.
    #"""
    end


    class StructIsNotInlineError < RuntimeError
    #"""
    #Error caused by using a Builder to write a Struct at a location that
    #is not the current Offset.
    #"""
    end


    class BuilderSizeError < RuntimeError
    #"""
    #Error caused by causing a Builder to exceed the hardcoded limit of 2
    #gigabytes.
    #"""
    end

    class BuilderNotFinishedError < RuntimeError
    #"""
    #Error caused by not calling `Finish` before calling `Output`.
    #"""
    end

  end  
end
