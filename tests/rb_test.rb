$:.unshift '../ruby/lib'
require 'flatbuffers'
require 'minitest/autorun'
require 'minitest/byebug' if ENV["DEBUG"]

module Minitest::Assertions
  def assert_builder_equals builder, want_chars_or_ints
    integerize = ->x{ x.is_a?(String) ? x.ord : x }

    want_ints = FlatBuffers::ByteArray[ want_chars_or_ints.map &integerize ]
    want = want_ints #.pack("c*")
    got = builder.bytes[builder.head..-1] # use the buffer directly
    assert_equal want, got
  end
end

describe FlatBuffers do
  it "Is a module" do
    _(FlatBuffers.class).must_equal Module
  end
end


describe "TestWireFormat" do
  def check_read_buffer buf, offset
    #''' CheckReadBuffer checks that the given buffer is evaluated correctly
    #    as the example Monster. '''

    monster = MyGame::Example::Monster::Monster::GetRootAsMonster.new buf, offset

    assert monster.Hp() == 80
    assert monster.Mana() == 150
    assert monster.Name() == FlatBuffers::ByteArray['MyMonster']

    # initialize a Vec3 from Pos()
    vec = monster.Pos()
    refute vec.nil?

    # verify the properties of the Vec3
    assert vec.X() == 1.0
    assert vec.Y() == 2.0
    assert vec.Z() == 3.0
    assert vec.Test1() == 3.0
    assert vec.Test2() == 2

    # initialize a Test from Test3(...)
    t = MyGame::Example::Test::Test.new()
    t = vec.Test3(t)
    refute t.nil?

    # verify the properties of the Test
    assert t.A() == 5
    assert t.B() == 6

    # verify that the enum code matches the enum declaration:
    union_type = MyGame::Example::Any::Any
    assert monster.TestType() == union_type.Monster

    # initialize a Table from a union field Test(...)
    table2 = monster.Test()
    assert table2.is_a? FlatBuffers::Table

    # initialize a Monster from the Table from the union
    monster2 = MyGame::Example::Monster::Monster.new()
    monster2.Init table2.Bytes, table2.Pos

    assert monster2.Name() == FlatBuffers::ByteArray["Fred"]

    # iterate through the first monster's inventory:
    assert monster.InventoryLength() == 5

    invsum = 0
    monster.InventoryLength().times do |i|
      v = monster.Inventory(i)
      invsum += v.to_i
    end
    assert invsum == 10

    assert monster.Test4Length() == 2

    # create a 'Test' object and populate it:
    test0 = monster.Test4(0)
    assert test0.is_a? MyGame::Example::Test::Test

    test1 = monster.Test4(1)
    assert test1.is_a? MyGame::Example::Test::Test

    # the position of test0 and test1 are swapped in monsterdata_java_wire
    # and monsterdata_test_wire, so ignore ordering
    v0 = test0.A()
    v1 = test0.B()
    v2 = test1.A()
    v3 = test1.B()
    sumtest12 = v0.to_i + v1.to_i + v2.to_i + v3.to_i

    assert sumtest12 == 100

    assert monster.TestarrayofstringLength() == 2
    assert monster.Testarrayofstring(0) == FlatBuffers::ByteArray["test1"]
    assert monster.Testarrayofstring(1) == FlatBuffers::ByteArray["test2"]

    assert monster.Enemy().nil?

    assert monster.TestarrayoftablesLength() == 0
    assert monster.TestnestedflatbufferLength() == 0
    assert monster.Testempty().nil? 
  end


  it "test wire format" do
    skip
    # Verify that using the generated Ruby code builds a buffer without
    # returning errors, and is interpreted correctly:
    gen_buf, gen_off = make_monster_from_generated_code()
    check_read_buffer gen_buf, gen_off

    # Verify that the canonical flatbuffer file is readable by the
    # generated Python code. Note that context managers are not part of
    # Python 2.5, so we use the simpler open/close methods here:
    f = open 'monsterdata_test.mon', 'rb'
    canonical_wire_data = f.read
    f.close
    check_read_buffer FlatBuffers::ByteArray[canonical_wire_data], 0

    # Write the generated buffer out to a file:
    f = open 'monsterdata_ruby_wire.mon', 'wb'
    f.write gen_buf[gen_off..-1]
    f.close
  end
end



describe "TestByteLayout" do

  let(:b){ FlatBuffers::Builder.new 0 }

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
    b.start_vector FlatBuffers::NumberTypes::Uint8Flags.bytewidth, 1, 1
    assert_builder_equals b, [0, 0, 0] # align to 4bytes
    b.prepend_byte 1
    assert_builder_equals b, [1, 0, 0, 0]
    b.end_vector 1
    assert_builder_equals b, [1, 0, 0, 0, 1, 0, 0, 0] # padding
  end

  it "2xbyte vector" do
    b.start_vector FlatBuffers::NumberTypes::Uint8Flags.bytewidth, 2, 1
    assert_builder_equals b, [0, 0] # align to 4bytes
    b.prepend_byte 1
    assert_builder_equals b, [1, 0, 0]
    b.prepend_byte 2
    assert_builder_equals b, [2, 1, 0, 0]
    b.end_vector 2
    assert_builder_equals b, [2, 0, 0, 0, 2, 1, 0, 0] # padding
  end

  it "1xuint16 vector" do
    b.start_vector FlatBuffers::NumberTypes::Uint16Flags.bytewidth, 1, 1
    assert_builder_equals b, [0, 0] # align to 4bytes
    b.prepend_uint16 1
    assert_builder_equals b, [1, 0, 0, 0]
    b.end_vector 1
    assert_builder_equals b, [1, 0, 0, 0, 1, 0, 0, 0] # padding
  end

  it "2xuint16 vector" do
    b.start_vector FlatBuffers::NumberTypes::Uint16Flags.bytewidth, 2, 1
    assert_builder_equals b, [] # align to 4bytes
    b.prepend_uint16 0xABCD
    assert_builder_equals b, [0xCD, 0xAB]
    b.prepend_uint16 0xDCBA
    assert_builder_equals b, [0xBA, 0xDC, 0xCD, 0xAB]
    b.end_vector 2
    assert_builder_equals b, [2, 0, 0, 0, 0xBA, 0xDC, 0xCD, 0xAB]
  end

  it "create ascii string" do
    b.create_string "foo".encode Encoding::US_ASCII
    # 0-terminated, no pad:
    assert_builder_equals b, [3, 0, 0, 0, 'f', 'o', 'o', 0]
    b.create_string "moop".encode Encoding::US_ASCII
    # 0-terminated, 3-byte pad:
    assert_builder_equals b, [4, 0, 0, 0, 'm', 'o', 'o', 'p',
                                 0, 0, 0, 0,
                                 3, 0, 0, 0, 'f', 'o', 'o', 0]
  end

  it "create arbitrary string" do
    s = "\x01\x02\x03".encode Encoding::UTF_8
    b.create_string s
    # 0-terminated, no pad:
    assert_builder_equals b, [3, 0, 0, 0, 1, 2, 3, 0]
    s2 = "\x04\x05\x06\x07".encode Encoding::UTF_8
    b.create_string s2
    # 0-terminated, 3-byte pad:
    assert_builder_equals b, [4, 0, 0, 0, 4, 5, 6, 7, 0, 0, 0, 0,
                              3, 0, 0, 0, 1, 2, 3, 0]
  end

  it "empty vtable" do
    b.start_object 0
    assert_builder_equals b, []
    b.end_object 
    assert_builder_equals b, [4, 0, 4, 0, 4, 0, 0, 0]
  end

  it "vtable with one true bool" do
    assert_builder_equals b, []
    b.start_object 1
    assert_builder_equals b, []
    b.prepend_bool_slot 0, true, false
    b.end_object 
    assert_builder_equals b, [
        6, 0,  # vtable bytes
        8, 0,  # length of object including vtable offset
        7, 0,  # start of bool value
        6, 0, 0, 0,  # offset for start of vtable (int32)
        0, 0, 0,  # padded to 4 bytes
        1,  # bool value
    ]
  end

  it "vtable with one default bool" do
    assert_builder_equals b, []
    b.start_object 1
    assert_builder_equals b, []
    b.prepend_bool_slot 0, false, false
    b.end_object 
    assert_builder_equals b, [
        6, 0,  # vtable bytes
        4, 0,  # end of object from here
        0, 0,  # entry 1 is zero
        6, 0, 0, 0,  # offset for start of vtable (int32)
    ]
  end

  it "vtable with one int16" do
    b.start_object 1
    b.prepend_int16_slot 0, 0x789A, 0
    b.end_object 
    assert_builder_equals b, [
        6, 0,  # vtable bytes
        8, 0,  # end of object from here
        6, 0,  # offset to value
        6, 0, 0, 0,  # offset for start of vtable (int32)
        0, 0,  # padding to 4 bytes
        0x9A, 0x78,
    ]
  end

  it "vtable with two int16" do
    b.start_object 2
    b.prepend_int16_slot 0, 0x3456, 0
    b.prepend_int16_slot 1, 0x789A, 0
    b.end_object 
    assert_builder_equals b, [
        8, 0,  # vtable bytes
        8, 0,  # end of object from here
        6, 0,  # offset to value 0
        4, 0,  # offset to value 1
        8, 0, 0, 0,  # offset for start of vtable (int32)
        0x9A, 0x78,  # value 1
        0x56, 0x34,  # value 0
    ]
  end

  it "vtable with int16 and bool" do
    b.start_object 2
    b.prepend_int16_slot 0, 0x3456, 0
    b.prepend_bool_slot 1, true, false
    b.end_object 
    assert_builder_equals b, [
        8, 0,  # vtable bytes
        8, 0,  # end of object from here
        6, 0,  # offset to value 0
        5, 0,  # offset to value 1
        8, 0, 0, 0,  # offset for start of vtable (int32)
        0,          # padding
        1,          # value 1
        0x56, 0x34,  # value 0
    ]
  end

  it "vtable with empty vector" do
    b.start_vector FlatBuffers::NumberTypes::Uint8Flags.bytewidth, 0, 1
    vecend = b.end_vector 0
    b.start_object 1
    b.prepend_uoffsett_relative_slot 0, vecend, 0
    b.end_object 
    assert_builder_equals b, [
        6, 0,  # vtable bytes
        8, 0,
        4, 0,  # offset to vector offset
        6, 0, 0, 0,  # offset for start of vtable (int32)
        4, 0, 0, 0,
        0, 0, 0, 0,  # length of vector (not in struct)
    ]
  end

  it "vtable with empty vector of byte and some scalars" do
    b.start_vector FlatBuffers::NumberTypes::Uint8Flags.bytewidth, 0, 1
    vecend = b.end_vector 0
    b.start_object 2
    b.prepend_int16_slot 0, 55, 0
    b.prepend_uoffsett_relative_slot 1, vecend, 0
    b.end_object 
    assert_builder_equals b, [
        8, 0,  # vtable bytes
        12, 0,
        10, 0,  # offset to value 0
        4, 0,  # offset to vector offset
        8, 0, 0, 0,  # vtable loc
        8, 0, 0, 0,  # value 1
        0, 0, 55, 0,  # value 0

        0, 0, 0, 0,  # length of vector (not in struct)
    ]
  end

  it "vtable with 1 int16 and 2vector of int16" do
    b.start_vector FlatBuffers::NumberTypes::Int16Flags.bytewidth, 2, 1
    b.prepend_int16 0x1234
    b.prepend_int16 0x5678
    vecend = b.end_vector 2
    b.start_object 2
    b.prepend_uoffsett_relative_slot 1, vecend, 0
    b.prepend_int16_slot 0, 55, 0
    b.end_object 
    assert_builder_equals b, [
        8, 0,  # vtable bytes
        12, 0,  # length of object
        6, 0,  # start of value 0 from end of vtable
        8, 0,  # start of value 1 from end of buffer
        8, 0, 0, 0,  # offset for start of vtable (int32)
        0, 0,  # padding
        55, 0,  # value 0
        4, 0, 0, 0,  # vector position from here
        2, 0, 0, 0,  # length of vector (uint32)
        0x78, 0x56,  # vector value 1
        0x34, 0x12,  # vector value 0
    ]
  end

  it "vtable with 1 struct of 1 int8  1 int16  1 int32" do
    b.start_object 1
    b.prep 4+4+4, 0
    b.prepend_int8 55
    b.pad 3
    b.prepend_int16 0x1234
    b.pad 2
    b.prepend_int32 0x12345678
    struct_start = b.offset
    b.prepend_struct_slot 0, struct_start, 0
    b.end_object 
    assert_builder_equals b, [
        6, 0,  # vtable bytes
        16, 0,  # end of object from here
        4, 0,  # start of struct from here
        6, 0, 0, 0,  # offset for start of vtable (int32)
        0x78, 0x56, 0x34, 0x12,  # value 2
        0, 0,  # padding
        0x34, 0x12,  # value 1
        0, 0, 0,  # padding
        55,  # value 0
    ]
  end

  it "vtable with 1 vector of 2 struct of 2 int8" do
    b.start_vector FlatBuffers::NumberTypes::Int8Flags.bytewidth*2, 2, 1
    b.prepend_int8 33
    b.prepend_int8 44
    b.prepend_int8 55
    b.prepend_int8 66
    vecend = b.end_vector 2
    b.start_object 1
    b.prepend_uoffsett_relative_slot 0, vecend, 0
    b.end_object 
    assert_builder_equals b, [
        6, 0,  # vtable bytes
        8, 0,
        4, 0,  # offset of vector offset
        6, 0, 0, 0,  # offset for start of vtable (int32)
        4, 0, 0, 0,  # vector start offset

        2, 0, 0, 0,  # vector length
        66,  # vector value 1,1
        55,  # vector value 1,0
        44,  # vector value 0,1
        33,  # vector value 0,0
    ]
  end

  it "table with some elements" do
    b.start_object 2
    b.prepend_int8_slot 0, 33, 0
    b.prepend_int16_slot 1, 66, 0
    off = b.end_object 
    b.finish off

    assert_builder_equals b, [
        12, 0, 0, 0,  # root of table: points to vtable offset

        8, 0,  # vtable bytes
        8, 0,  # end of object from here
        7, 0,  # start of value 0
        4, 0,  # start of value 1

        8, 0, 0, 0,  # offset for start of vtable (int32)

        66, 0,  # value 1
        0,  # padding
        33,  # value 0
    ]
  end

  it "one unfinished table and one finished table" do
    b.start_object 2
    b.prepend_int8_slot 0, 33, 0
    b.prepend_int8_slot 1, 44, 0
    off = b.end_object 
    b.finish off

    b.start_object 3
    b.prepend_int8_slot 0, 55, 0
    b.prepend_int8_slot 1, 66, 0
    b.prepend_int8_slot 2, 77, 0
    off = b.end_object 
    b.finish off

    assert_builder_equals b, [
        16, 0, 0, 0,  # root of table: points to object
        0, 0,  # padding

        10, 0,  # vtable bytes
        8, 0,  # size of object
        7, 0,  # start of value 0
        6, 0,  # start of value 1
        5, 0,  # start of value 2
        10, 0, 0, 0,  # offset for start of vtable (int32)
        0,  # padding
        77,  # value 2
        66,  # value 1
        55,  # value 0

        12, 0, 0, 0,  # root of table: points to object

        8, 0,  # vtable bytes
        8, 0,  # size of object
        7, 0,  # start of value 0
        6, 0,  # start of value 1
        8, 0, 0, 0,  # offset for start of vtable (int32)
        0, 0,  # padding
        44,  # value 1
        33,  # value 0
    ]
  end

  it "a bunch of bools" do
    b.start_object 8
    b.prepend_bool_slot 0, true, false
    b.prepend_bool_slot 1, true, false
    b.prepend_bool_slot 2, true, false
    b.prepend_bool_slot 3, true, false
    b.prepend_bool_slot 4, true, false
    b.prepend_bool_slot 5, true, false
    b.prepend_bool_slot 6, true, false
    b.prepend_bool_slot 7, true, false
    off = b.end_object 
    b.finish off

    assert_builder_equals b, [
        24, 0, 0, 0,  # root of table: points to vtable offset

        20, 0,  # vtable bytes
        12, 0,  # size of object
        11, 0,  # start of value 0
        10, 0,  # start of value 1
        9, 0,  # start of value 2
        8, 0,  # start of value 3
        7, 0,  # start of value 4
        6, 0,  # start of value 5
        5, 0,  # start of value 6
        4, 0,  # start of value 7
        20, 0, 0, 0,  # vtable offset

        1,  # value 7
        1,  # value 6
        1,  # value 5
        1,  # value 4
        1,  # value 3
        1,  # value 2
        1,  # value 1
        1,  # value 0
    ]
  end

  it "three bools" do
    b.start_object 3
    b.prepend_bool_slot 0, true, false
    b.prepend_bool_slot 1, true, false
    b.prepend_bool_slot 2, true, false
    off = b.end_object 
    b.finish off

    assert_builder_equals b, [
        16, 0, 0, 0,  # root of table: points to vtable offset

        0, 0,  # padding

        10, 0,  # vtable bytes
        8, 0,  # size of object
        7, 0,  # start of value 0
        6, 0,  # start of value 1
        5, 0,  # start of value 2
        10, 0, 0, 0,  # vtable offset from here

        0,  # padding
        1,  # value 2
        1,  # value 1
        1,  # value 0
    ]
  end

  it "some floats" do
    b.start_object 1
    b.prepend_float32_slot 0, 1.0, 0.0
    b.end_object 

    assert_builder_equals b, [
        6, 0,  # vtable bytes
        8, 0,  # size of object
        4, 0,  # start of value 0
        6, 0, 0, 0,  # vtable offset

        0, 0, 128, 63,  # value 0
    ]
  end
end

describe "TestVtableDeduplication verifies that vtables are deduplicated." do
  it "test vtabler deduplication" do
    b = FlatBuffers::Builder.new 0

    b.start_object 4
    b.prepend_byte_slot 0, 0, 0
    b.prepend_byte_slot 1, 11, 0
    b.prepend_byte_slot 2, 22, 0
    b.prepend_int16_slot 3, 33, 0
    obj0 = b.end_object

    b.start_object 4
    b.prepend_byte_slot 0, 0, 0
    b.prepend_byte_slot 1, 44, 0
    b.prepend_byte_slot 2, 55, 0
    b.prepend_int16_slot 3, 66, 0
    obj1 = b.end_object

    b.start_object 4
    b.prepend_byte_slot 0, 0, 0
    b.prepend_byte_slot 1, 77, 0
    b.prepend_byte_slot 2, 88, 0
    b.prepend_int16_slot 3, 99, 0
    obj2 = b.end_object

    got = b.bytes[b.head..-1]

    want = FlatBuffers::ByteArray[ [
        240, 255, 255, 255,  # == -12. offset to dedupped vtable.
        99, 0,
        88,
        77,
        248, 255, 255, 255,  # == -8. offset to dedupped vtable.
        66, 0,
        55,
        44,
        12, 0,
        8, 0,
        0, 0,
        7, 0,
        6, 0,
        4, 0,
        12, 0, 0, 0,
        33, 0,
        22,
        11,
    ] ]

    assert_equal [want.length, want], [got.length, got]

    table0 = FlatBuffers::Table.new b.bytes, b.bytes.length - obj0
    table1 = FlatBuffers::Table.new b.bytes, b.bytes.length - obj1
    table2 = FlatBuffers::Table.new b.bytes, b.bytes.length - obj2

    def _check_table tab, voffsett_value, b, c, d
      # vtable size
      got = tab.get_voffsett_slot 0, 0
      assert_equal 12, got, 'case 0, 0'

      # object size
      got = tab.get_voffsett_slot 2, 0
      assert_equal 8, got, 'case 2, 0'

      # default value
      got = tab.get_voffsett_slot 4, 0
      assert_equal voffsett_value, got, 'case 4, 0'

      got = tab.get_slot 6, 0, N::Uint8Flags
      assert_equal b, got, 'case 6, 0'

      val = tab.get_slot 8, 0, N::Uint8Flags
      assert_equal c, val, 'failed 8, 0'

      got = tab.get_slot 10, 0, N::Uint8Flags
      assert_equal d, got, 'failed 10, 0'
    end

    _check_table table0, 0, 11, 22, 33
    _check_table table1, 0, 44, 55, 66
    _check_table table2, 0, 77, 88, 99
  end
end

describe "TestExceptions" do
  let(:b) { FlatBuffers::Builder.new 0 }

  it "test object is nested error" do
    b.start_object 0
    _(proc {b.start_object 0}).
      must_raise FlatBuffers::Builder::IsNestedError
  end

  it "test object is not nested error" do
    _(proc {b.end_object}).
      must_raise FlatBuffers::Builder::IsNotNestedError
  end

  it "test struct is not inline error" do
    b.start_object 0
    _(proc {b.prepend_struct_slot 0, 1, 0}).
      must_raise FlatBuffers::Builder::StructIsNotInlineError
  end

  it "test unreachable error" do
    _(proc { b.prepend_uoffsett_relative 1 }).
      must_raise FlatBuffers::Builder::OffsetArithmeticError
  end

  it "test create string is nested error" do
    b.start_object 0
    s = 'test1'
    _(proc {b.create_string s}).
      must_raise FlatBuffers::Builder::IsNestedError
  end

  it "test finished bytes error" do
    _(proc {b.output}).
      must_raise FlatBuffers::Builder::BuilderNotFinishedError
  end
end
