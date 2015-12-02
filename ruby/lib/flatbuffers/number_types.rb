module FlatBuffers
  module NumberTypes
      
    class NumFlags 
      @@attrs = [:bytewidth, :min_val, :max_val, :rb_type, :name, :packer_type]
      attr_accessor *@@attrs
      def initialize **opts
        @@attrs.each do |a|
          instance_variable_set "@#{a}", opts.fetch(a) {nil}
        end
      end
    end

    module ::Boolean; end
    FalseClass.prepend Boolean
    TrueClass. prepend Boolean

    class BoolFlags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   1,
          min_val:     false,
          max_val:     true,
          rb_type:     Boolean,
          name:        "bool",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Uint8Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   1,
          min_val:     0,
          max_val:     (2**8) - 1,
          rb_type:     Integer,
          name:        "uint8",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Uint16Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   2,
          min_val:     0,
          max_val:     (2**16) - 1,
          rb_type:     Integer,
          name:        "uint16",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Uint32Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   4,
          min_val:     0,
          max_val:     (2**32) - 1,
          rb_type:     Integer,
          name:        "uint32",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Uint64Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   8,
          min_val:     0,
          max_val:     (2**64) - 1,
          rb_type:     Integer,
          name:        "uint64",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Int8Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   1,
          min_val:     -(2**7),
          max_val:     (2**7) - 1,
          rb_type:     Integer,
          name:        "int8",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Int16Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   2,
          min_val:     -(2**15),
          max_val:     (2**15) - 1,
          rb_type:     Integer,
          name:        "int16",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Int32Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   4,
          min_val:     -(2**31),
          max_val:     (2**31) - 1,
          rb_type:     Integer,
          name:        "int32",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Int64Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   8,
          min_val:     -(2**63),
          max_val:     (2**63) - 1,
          rb_type:     Integer,
          name:        "int64",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Float32Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   4,
          min_val:     nil,
          max_val:     nil,
          rb_type:     Float,
          name:        "float32",
          packer_type: nil
        }.
        update opts)
      end
    end

    class Float64Flags < NumFlags
      def initialize **opts
        super( {
          bytewidth:   8,
          min_val:     nil,
          max_val:     nil,
          rb_type:     Float,
          name:        "float64",
          packer_type: nil
        }.
        update opts)
      end
    end

    class SOffsetTFlags < Int32Flags;  end
    class UOffsetTFlags < Uint32Flags; end
    class VOffsetTFlags < Uint16Flags; end

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
