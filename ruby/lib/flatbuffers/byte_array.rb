module FlatBuffers
  class Byte
    def initialize val
      @value = case val
      when Integer
        raise StandardError, "#{val} is too large for Byte" if val > 255
        val
      when String
        raise StandardError, "#{val} is too large for Byte" if val.length > 1
        val.unpack("C").first
      else
        raise TypeError, "Wrong type #{val.class} for Byte"
      end
    end

    def self.[] obj
      obj.is_a?(Byte) ? obj : Byte.new(obj)
    end

    def inspect;     @value                end
    def to_i;        @value                end
    def to_s;        [@value].pack("C")    end
    def to_str;      to_s                  end
    def == o;        o.to_i == @value      end
    def coerce o;    [o.to_i, @value]      end
    def + o;         @value + o.to_i       end
    def - o;         @value - o.to_i       end
    def * o;         @value * o.to_i       end
    def / o;         @value / o.to_i       end
  end

  class ByteArray 
    attr_reader :bytes
    def initialize size = 0, obj = 0
      @bytes = []
      size.times do @bytes << Byte[obj] end
    end
     
    def self.[] array = []
      return array if array.is_a? ByteArray
      b = new
      b.insert 0, *array
      b
    end

    def [] slice
      ByteArray[@bytes[slice]]
    end

    def []= slice, *input
      input = input.map(&method(:to_bytes)).flatten
      case slice
      when Range
        @bytes[slice] = *input 
      when Integer
        @bytes.insert slice, *input
      end unless input.empty?
    end

    def length
      @bytes.length
    end

    def inspect
      "ByteArray#{@bytes}"
    end

    def insert position, *what
      what = what.map(&method(:to_bytes)).flatten
      @bytes.insert position, *what unless what.empty?
    end

    def == other
      return false if other.length != @bytes.length
      ByteArray[other].zip(@bytes).all?{|a,b| a == b}
    end
    
    def coerce other
      [ByteArray[other], self]
    end

    def to_ary
      @bytes
    end

    def to_a
      @bytes
    end

    def method_missing m, *a, &b
      #puts "Method #{m} called with", *a
      @bytes.send m, *a, &b
    end

    private
    # to_bytes always returns Array of Bytes
    def to_bytes input
      b = case input
      when String
        input.unpack("C*")
      when Integer
        raise ByteOutOfRangeError, "Integer #{input} is to large to be a Byte" unless input < 256
        [input]
      when Byte
        [input]
      when Array
        input
      when NilClass
        []
      else
        raise TypeError, "Unexpected type #{input.class} for ByteArray#to_bytes"
      end
      b.map(&Byte.method(:[]))
    end
  end
  class ByteOutOfRangeError < StandardError
  end
end
