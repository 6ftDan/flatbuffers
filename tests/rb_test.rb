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

  it "Uint64 numbers" do
        b.prepend_uint64 0x1122334455667788
        assert_builder_equals b, [0x88, 0x77, 0x66, 0x55,
                                  0x44, 0x33, 0x22, 0x11]
  end

  it "Int64 numbers" do
        b.prepend_int64 0x1122334455667788
        assert_builder_equals b, [0x88, 0x77, 0x66, 0x55,
                                  0x44, 0x33, 0x22, 0x11]
  end

  it "1xbyte vector" do
    assert_builder_equals b, []
    b.start_vector FlatBuffers::NumberTypes::Uint8Flags.new.bytewidth, 1, 1
    assert_builder_equals b, [0, 0, 0] # align to 4bytes
    b.prepend_byte 1
    assert_builder_equals b, [1, 0, 0, 0]
    b.end_vector 1
    assert_builder_equals b, [1, 0, 0, 0, 1, 0, 0, 0] # padding
  end
  #def test_2xbyte_vector(self):
  #def test_1xuint16_vector(self):
  #def test_2xuint16_vector(self):
  #def test_create_ascii_string(self):
  #def test_create_arbitrary_string(self):
  #def test_empty_vtable(self):
  #def test_vtable_with_one_true_bool(self):
  #def test_vtable_with_one_default_bool(self):
  #def test_vtable_with_one_int16(self):
  #def test_vtable_with_two_int16(self):
  #def test_vtable_with_int16_and_bool(self):
  #def test_vtable_with_empty_vector(self):
  #def test_vtable_with_empty_vector_of_byte_and_some_scalars(self):
  #def test_vtable_with_1_int16_and_2vector_of_int16(self):
  #def test_vtable_with_1_struct_of_1_int8__1_int16__1_int32(self):
  #def test_vtable_with_1_vector_of_2_struct_of_2_int8(self):
  #def test_table_with_some_elements(self):
  #def test__one_unfinished_table_and_one_finished_table(self):
  #def test_a_bunch_of_bools(self):
  #def test_three_bools(self):
  #def test_some_floats(self):
end
