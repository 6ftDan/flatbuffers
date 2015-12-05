module FlatBuffers
  class Byte
    def initialize val
      @value = case val
      when Integer
        raise StandardError, "#{val} is too large for Byte" if val > 255
        val
      when String
        raise StandardError, "#{val} is too large for Byte" if val.length > 1
        val.unpack("C")
      else
        raise TypeError, "Wrong type for Byte"
      end
    end

    def self.[] obj
      obj.is_a?(Byte) ? obj : Byte.new(obj)
    end

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

    def insert position, *what
      @bytes.insert position, *what.map(&Byte.method(:[]))
    end

    def method_missing m, *a, &b
      @bytes.send m, *a, &b
    end
  end

end
