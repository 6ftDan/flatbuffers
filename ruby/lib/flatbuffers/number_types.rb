module FlatBuffers
  class UOffsetTFlags
    def initialize(type)
      @type = type
    end
    def self.rb_type(type)
      new(type)
    end
  end
end
