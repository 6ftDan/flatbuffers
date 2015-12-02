$:.unshift '../ruby/lib'
require 'flatbuffers'
require 'minitest/autorun'

module Minitest::Assertions
  def assert_builder_equals(builder, want_chars_or_ints)
    integerize = ->x{ x.is_a?(String) ? x.ord : x }

    want_ints = Array(want_chars_or_ints.map(&integerize))
    want = want_ints #.pack("c*")
    got = builder.bytes(builder.head()) # use the buffer directly
    assert_equal(want, got)
  end
end

describe FlatBuffers do
  it "Is a module" do
    _(FlatBuffers.class).must_equal Module
  end
end
describe "TestByteLayout" do
  let(:b){ FlatBuffers::Builder.new(0) }
  it "test numbers" do
    assert_builder_equals b, []
    b.prepend_bool true
    assert_builder_equals b, [1]
    b.prepend_int8 -127
    assert_builder_equals b, [129, 1]
    b.prepend_uint8 255
    assert_builder_equals b, [255, 129, 1]
    b.prepend_int16 -32222
    assert_builder_equals b, [0x22, 0x82, 0, 255, 129, 1] # first pad
    b.prepend_uint16 0xFEEE
    ## no pad this time:
    assert_builder_equals b, [0xEE, 0xFE, 0x22, 0x82, 0, 255, 129, 1]
    b.prepend_int32 -53687092
    assert_builder_equals b, [204, 204, 204, 252, 0xEE, 0xFE,
                              0x22, 0x82, 0, 255, 129, 1]
    b.prepend_uint32 0x98765432
    assert_builder_equals b, [0x32, 0x54, 0x76, 0x98,
                              204, 204, 204, 252,
                              0xEE, 0xFE, 0x22, 0x82,
                              0, 255, 129, 1]
  end
end
