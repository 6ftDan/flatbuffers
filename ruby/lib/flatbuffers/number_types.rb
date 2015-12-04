module FlatBuffers
  module NumberTypes
      
    NumFlags = Struct.new :bytewidth,
      :min_val, :max_val, :rb_type,
      :name, :packer_type do

      def rb_type(value = nil)
        return @rb_type unless value
        n = dup
        n.instance_exec {@value = value}
        n
      end
            
      def coerce other
        [other, @value]
      end

      include Comparable
      def <=> other;        @value <=> other      end
      def + other  ;        @value +   other      end
      def - other  ;        @value -   other      end
      def * other  ;        @value *   other      end
      def / other  ;        @value /   other      end
    end

    module ::Boolean; end
    class ::FalseClass
      prepend Boolean
      def to_i; 0b0 end
    end
    class ::TrueClass
      prepend Boolean
      def to_i; 0b1 end
    end

    BoolFlags = NumFlags.new(
      *{
        bytewidth:   1,
        min_val:     false,
        max_val:     true,
        rb_type:     Boolean,
        name:        "bool",
        packer_type: BooleanPacker
      }.values
    )

    Uint8Flags = NumFlags.new(
      *{
        bytewidth:   1,
        min_val:     0,
        max_val:     (2**8) - 1,
        rb_type:     Integer,
        name:        "uint8",
        packer_type: Uint8Packer 
      }.values
    )

    Uint16Flags = NumFlags.new(
      *{
        bytewidth:   2,
        min_val:     0,
        max_val:     (2**16) - 1,
        rb_type:     Integer,
        name:        "uint16",
        packer_type: Uint16Packer
      }.values
    )

    Uint32Flags = NumFlags.new(
      *{
        bytewidth:   4,
        min_val:     0,
        max_val:     (2**32) - 1,
        rb_type:     Integer,
        name:        "uint32",
        packer_type: Uint32Packer
      }.values
    )

    Uint64Flags = NumFlags.new(
      *{
        bytewidth:   8,
        min_val:     0,
        max_val:     (2**64) - 1,
        rb_type:     Integer,
        name:        "uint64",
        packer_type: Uint64Packer
      }.values
    )

    Int8Flags = NumFlags.new(
      *{
        bytewidth:   1,
        min_val:     -(2**7),
        max_val:     (2**7) - 1,
        rb_type:     Integer,
        name:        "int8",
        packer_type: Int8Packer
      }.values
    )
    
    Int16Flags = NumFlags.new(
      *{
        bytewidth:   2,
        min_val:     -(2**15),
        max_val:     (2**15) - 1,
        rb_type:     Integer,
        name:        "int16",
        packer_type: Int16Packer
      }.values
    )
      
    Int32Flags = NumFlags.new(
      *{
        bytewidth:   4,
        min_val:     -(2**31),
        max_val:     (2**31) - 1,
        rb_type:     Integer,
        name:        "int32",
        packer_type: Int32Packer
      }.values
    )

    Int64Flags = NumFlags.new(
      *{
        bytewidth:   8,
        min_val:     -(2**63),
        max_val:     (2**63) - 1,
        rb_type:     Integer,
        name:        "int64",
        packer_type: Int64Packer
      }.values
    )

    Float32Flags = NumFlags.new(
      *{
        bytewidth:   4,
        min_val:     nil,
        max_val:     nil,
        rb_type:     Float,
        name:        "float32",
        packer_type: Float32Packer
      }.values
    )
    
    Float64Flags = NumFlags.new(
      *{
        bytewidth:   8,
        min_val:     nil,
        max_val:     nil,
        rb_type:     Float,
        name:        "float64",
        packer_type: Float64Packer
      }.values
    )
    
    SOffsetTFlags = Int32Flags
    UOffsetTFlags = Uint32Flags
    VOffsetTFlags = Uint16Flags

    def self.valid_number? n, flags
      min = flags.min_val
      max = flags.max_val

      if min.nil? && max.nil?
        true
      else
       includes? min, max, n
      end
    end
 
    def self.enforce_number n, flags
      min = flags.min_val
      max = flags.max_val

      return nil if min.nil? && max.nil?

      unless includes? min, max, n
        raise TypeError, "bad number #{n} for type #{flags.name}"
      end
      n   
    end

    def self.float32_to_uint32 n
      packed = [n].pack "<1f"
      converted, *_ = packed.unpack "<1L"
      converted
    end

    def self.uint32_to_float32 n
      packed = [n].pack "<1L"
      unpacked, *_ = packed.unpack "<1f"
      unpacked
    end

    def self.float64_to_uint64 n
      packed = [n].pack "<1d"
      converted, *_ = packed.unpack "<1Q"
      converted
    end

    def self.uint64_to_float64 n
      packed = [n].pack "<1Q"
      unpacked, *_ = packed.unpack "<1d"
      unpacked
    end

    class << self
      def includes? min, max, n
        (min.to_i..max.to_i).include? n
      end
      private :includes?
    end

  end
end
