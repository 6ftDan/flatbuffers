module FlatBuffers

  # VtableMetadataFields is the count of metadata fields in each vtable.
  VtableMetadataFields = 2

  class Builder
    MAX_BUFFER_SIZE = 2**31
    N = NumberTypes
    
    attr_accessor :minalign, :bytes, :head, :current_vtable, :object_end,
                  :nested, :vtables, :finished
    
    def initialize initial_size
      #"""
      #Initializes a Builder of size `initial_size`.
      #The internal buffer is grown as needed.
      #"""

      unless (0..MAX_BUFFER_SIZE).include? initial_size
        msg = "flatbuffers: Cannot create Builder larger than 2 gigabytes."
        raise BuilderSizeError, msg
      end

      @bytes = ByteArray.new initial_size, 0b0
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
      self.current_vtable = ByteArray.new numfields, 0b0 
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
        vt2_start = @bytes.length - vt2_offset
        vt2_len = Encode.get(VoffsetPacker, @bytes, vt2_start)

        metadata = VtableMetadataFields * N::VOffsetTFlags.bytewidth
        vt2_end = vt2_start + vt2_len
        vt2 = @bytes[vt2_start+metadata..vt2_end]

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
            off = object_offset - self.current_vtable[i]
          end
          self.prepend_voffsett off
          i -= 1
        end

        # The two metadata fields are written last.

        # First, store the object bytesize:
        object_size = N::UOffsetTFlags.rb_type(object_offset - self.object_end)
        self.prepend_voffsett N::VOffsetTFlags.rb_type(object_size)

        # Second, store the vtable bytesize:
        vbytes = self.current_vtable.length + VtableMetadataFields
        vbytes *= N::VOffsetTFlags.bytewidth
        self.prepend_voffsett N::VOffsetTFlags.rb_type(vbytes)

        # Next, write the offset to the new vtable in the
        # already-allocated SOffsetT at the beginning of this object:
        object_start = N::SOffsetTFlags.rb_type(@bytes.length - object_offset)
        Encode.write SoffsetPacker, @bytes, object_start,
                     N::SOffsetTFlags.rb_type(self.offset - object_offset)

        # Finally, store this vtable in memory for future
        # deduplication:
        self.vtables.push self.offset
      else
        # Found a duplicate vtable.

        object_start = N::SOffsetTFlags.rb_type(@bytes.length - object_offset)
        @head = N::UOffsetTFlags.rb_type(object_start)

        # Write the offset to the found vtable in the
        # already-allocated SOffsetT at the beginning of this object:
        Encode.write SoffsetPacker, @bytes, @head,
                     N::SOffsetTFlags.rb_type(existing_vtable - object_offset)
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

    def create_string s
      #"""CreateString writes a null-terminated byte string as a vector."""

      assert_not_nested
      self.nested = true

      if s.is_a? String
        x = s.encode
      elsif s.is_a? Integer # binary(Python 3.0+) and str(Python 2.0+)
        x = s
      else
        raise TypeError, "non-string passed to create_string"
      end

      self.prep N::UOffsetTFlags.bytewidth, (x.length+1)*N::Uint8Flags.bytewidth
      self.place 0, N::Uint8Flags

      l = N::UOffsetTFlags.rb_type(s.length)

      @head = N::UOffsetTFlags.rb_type(@head - l)
      @bytes[@head...@head+l] = x

      self.end_vector(x.length)
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
      align_size = (~(@bytes.length - @head + additional_bytes)) + 1
      align_size &= (size - 1)

      # Reallocate the buffer if needed:
      while @head < align_size + size + additional_bytes
        old_buf_size = @bytes.length
        self.grow_byte_buffer
        updated_head = @head + @bytes.length - old_buf_size
        @head = N::UOffsetTFlags.rb_type(updated_head)
      end
      self.pad(align_size)
    end


    def grow_byte_buffer
      #"""Doubles the size of the byteslice, and copies the old data towards
      #   the end of the new buffer (since we build the buffer backwards)."""
      if @bytes.length == MAX_BUFFER_SIZE
        msg = "flatbuffers: cannot grow buffer beyond 2 gigabytes"
        raise BuilderSizeError, msg
      end

      new_size = [@bytes.length * 2, MAX_BUFFER_SIZE].min
      if new_size == 0
        new_size = 1
      end
      bytes2 = ByteArray.new new_size, 0b0
      bytes2.insert new_size-@bytes.length, *@bytes
      @bytes = bytes2
    end

    def pad n
      #"""Pad places zeros at the current offset."""
      n.times do
        self.place 0, N::Uint8Flags
      end
    end

    def slot slotnum
      #"""
      #Slot sets the vtable key `voffset` to the current location in the
      #buffer.
      #
      #"""
      assert_nested
      self.current_vtable[slotnum] = self.offset
    end

    def finish root_table
      #"""Finish finalizes a buffer, pointing to the given `rootTable`."""
      N.enforce_number root_table, N::UOffsetTFlags
      self.prep self.minalign, N::UOffsetTFlags.bytewidth
      self.prepend_uoffsett_relative root_table
      self.finished = true
      @head
    end

    def prepender flags, off
      self.prep flags.bytewidth, 0
      self.place off, flags
    end

    def prepend_slot flags, o, x, d
      N.enforce_number x, flags
      N.enforce_number d, flags
      if x != d
        self.prepender flags, x
        self.slot o
      end
    end

    def prepend_bool_slot    *args; prepend_slot N::BoolFlags,    *args; end
    def prepend_byte_slot    *args; prepend_slot N::Uint8Flags,   *args; end
    def prepend_uint8_slot   *args; prepend_slot N::Uint8Flags,   *args; end
    def prepend_uint16_slot  *args; prepend_slot N::Uint16Flags,  *args; end
    def prepend_uint32_slot  *args; prepend_slot N::Uint32Flags,  *args; end
    def prepend_uint64_slot  *args; prepend_slot N::Uint64Flags,  *args; end
    def prepend_int8_slot    *args; prepend_slot N::Int8Flags,    *args; end
    def prepend_int16_slot   *args; prepend_slot N::Int16Flags,   *args; end
    def prepend_int32_slot   *args; prepend_slot N::Int32Flags,   *args; end
    def prepend_int64_slot   *args; prepend_slot N::Int64Flags,   *args; end
    def prepend_float32_slot *args; prepend_slot N::Float32Flags, *args; end
    def prepend_float64_slot *args; prepend_slot N::Float64Flags, *args; end

    def prepend_uoffsett_relative_slot o, x, d
      #"""
      #PrependUOffsetTRelativeSlot prepends an UOffsetT onto the object at
      #vtable slot `o`. If value `x` equals default `d`, then the slot will
      #be set to zero and no other data will be written.
      #"""

      if x != d
        self.prepend_uoffsett_relative x
        self.slot o
      end
    end

    def prepend_struct_slot v, x, d
      #"""
      #PrependStructSlot prepends a struct onto the object at vtable slot `o`.
      #Structs are stored inline, so nothing additional is being added.
      #In generated code, `d` is always 0.
      #"""

      N.enforce_number d, N::UOffsetTFlags
      if x != d
        assert_struct_is_inline x
        self.slot v
      end
    end

    def prepend_bool      x; prepender N::BoolFlags,     x; end
    def prepend_byte      x; prepender N::Uint8Flags,    x; end
    def prepend_uint8     x; prepender N::Uint8Flags,    x; end
    def prepend_uint16    x; prepender N::Uint16Flags,   x; end
    def prepend_uint32    x; prepender N::Uint32Flags,   x; end
    def prepend_uint64    x; prepender N::Uint64Flags,   x; end
    def prepend_int8      x; prepender N::Int8Flags,     x; end
    def prepend_int16     x; prepender N::Int16Flags,    x; end
    def prepend_int32     x; prepender N::Int32Flags,    x; end
    def prepend_int64     x; prepender N::Int64Flags,    x; end
    def prepend_float32   x; prepender N::Float32Flags,  x; end
    def prepend_float64   x; prepender N::Float64Flags,  x; end
    def prepend_voffsett  x; prepender N::VOffsetTFlags, x; end

    def place x, flags
      #"""
      #Place prepends a value specified by `flags` to the Builder,
      #without checking for available space.
      #"""

      x = N.enforce_number x, flags
      @head -= flags.bytewidth
      Encode.write flags.packer_type, @bytes, @head, x
    end

    def place_voffsett x
      #"""
      #PlaceVOffsetT prepends a VOffsetT to the Builder, without checking for
      #space.
      #"""
      N.enforce_number x, N::VOffsetTFlags
      @head -= N::VOffsetTFlags.bytewidth
      Encode.write VoffsetPacker, @bytes, @head, x
    end

    def place_soffsett x
      #"""
      #PlaceSOffsetT prepends a SOffsetT to the Builder, without checking for
      #space.
      #"""
      N.enforce_number x, N::SOffsetTFlags
      @head -= N::SOffsetTFlags.bytewidth
      Encode.write SoffsetPacker, @bytes, @head, x
    end

    def place_uoffsett x
      #"""
      #PlaceUOffsetT prepends a UOffsetT to the Builder, without checking for
      #space.
      #"""
      N.enforce_number x, N::UOffsetTFlags
      @head -= N::UOffsetTFlags.bytewidth
      Encode.write UoffsetPacker, @bytes, @head, x
    end

    def offset
      #"""Offset relative to the end of the buffer."""
      N::UOffsetTFlags.rb_type(@bytes.length - @head)
    end

    private
    def assert_not_nested
      raise IsNestedError, "Error; it's nested" if @nested
    end

    def assert_nested
      raise IsNotNestedError, "Error; it's not nested" unless @nested
    end

    def assert_struct_is_inline obj
      #"""
      #Structs are always stored inline, so need to be created right
      #where they are used. You'll get this error if you created it
      #elsewhere.
      #"""

      N.enforce_number obj, N::UOffsetTFlags
      if obj != self.offset
        msg = ("flatbuffers: Tried to write a Struct at an Offset that \
               is different from the current Offset of the Builder.")
        raise StructIsNotInlineError, msg
      end
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
