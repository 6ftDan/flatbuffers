// automatically generated, do not modify

namespace MyGame.Example
{

using FlatBuffers;

public sealed class Vec3 : Struct {
  public Vec3 __init(int _i, ByteBuffer _bb) { bb_pos = _i; bb = _bb; return this; }

  public float X { get { return bb.GetFloat(bb_pos + 0); } }
  public void MutateX(float x) { bb.PutFloat(bb_pos + 0, x); }
  public float Y { get { return bb.GetFloat(bb_pos + 4); } }
  public void MutateY(float y) { bb.PutFloat(bb_pos + 4, y); }
  public float Z { get { return bb.GetFloat(bb_pos + 8); } }
  public void MutateZ(float z) { bb.PutFloat(bb_pos + 8, z); }
  public double Test1 { get { return bb.GetDouble(bb_pos + 16); } }
  public void MutateTest1(double test1) { bb.PutDouble(bb_pos + 16, test1); }
  public Color Test2 { get { return (Color)bb.GetSbyte(bb_pos + 24); } }
  public void MutateTest2(Color test2) { bb.PutSbyte(bb_pos + 24, (sbyte)test2); }
  public Test Test3 { get { return GetTest3(new Test()); } }
  public Test GetTest3(Test obj) { return obj.__init(bb_pos + 26, bb); }

  public static Offset<Vec3> CreateVec3(FlatBufferBuilder builder, float X, float Y, float Z, double Test1, Color Test2, short test3_A, sbyte test3_B) {
    builder.Prep(16, 32);
    builder.Pad(2);
    builder.Prep(2, 4);
    builder.Pad(1);
    builder.PutSbyte(test3_B);
    builder.PutShort(test3_A);
    builder.Pad(1);
    builder.PutSbyte((sbyte)Test2);
    builder.PutDouble(Test1);
    builder.Pad(4);
    builder.PutFloat(Z);
    builder.PutFloat(Y);
    builder.PutFloat(X);
    return new Offset<Vec3>(builder.Offset);
  }
};


}
