// RUN: %empty-directory(%t)
// RUN: %target-build-swift -parse-stdlib %s -module-name main -o %t/a.out
// RUN: %target-run %t/a.out
// REQUIRES: executable_test

import Swift
import StdlibUnittest

let DemangleToMetadataTests = TestSuite("DemangleToMetadata")


DemangleToMetadataTests.test("malformed mangled names") {
  expectNil(_typeByMangledName("blah"))
}

DemangleToMetadataTests.test("tuple types") {
  expectEqual(type(of: ()), _typeByMangledName("yt")!)
  expectEqual(type(of: ((), ())), _typeByMangledName("yt_ytt")!)
  expectEqual(type(of: ((), b: ())), _typeByMangledName("yt_yt1bt")!)
  expectEqual(type(of: (a: (), ())), _typeByMangledName("yt1a_ytt")!)
  expectEqual(type(of: (a: (), b: ())), _typeByMangledName("yt1a_yt1bt")!)

  // Initial creation of metadata via demangling a type name.
  expectNotNil(_typeByMangledName("yt1a_yt3bcdt"))
}

func f0() { }
var f0_thin: @convention(thin) () -> Void = f0
var f0_c: @convention(c) () -> Void = f0

#if _runtime(_ObjC)
var f0_block: @convention(block) () -> Void = f0
#endif

func f0_throws() throws { }

func f1(x: ()) { }
func f2(x: (), y: ()) { }

func f1_variadic(x: ()...) { }
func f1_inout(x: inout ()) { }
func f1_shared(x: __shared AnyObject) { }
func f1_owned(x: __owned AnyObject) { }

func f2_variadic_inout(x: ()..., y: inout ()) { }

DemangleToMetadataTests.test("function types") {
  // Conventions
  expectEqual(type(of: f0), _typeByMangledName("yyc")!)
  expectEqual(type(of: f0_thin), _typeByMangledName("yyXf")!)
  expectEqual(type(of: f0_c), _typeByMangledName("yyXC")!)
#if _runtime(_ObjC)
  expectEqual(type(of: f0_block), _typeByMangledName("yyXB")!)
#endif

  // Throwing functions
  expectEqual(type(of: f0_throws), _typeByMangledName("yyKc")!)

  // More parameters.
  expectEqual(type(of: f1), _typeByMangledName("yyyt_tc")!)
  expectEqual(type(of: f2), _typeByMangledName("yyyt_yttc")!)

  // Variadic parameters.
  expectEqual(type(of: f1_variadic), _typeByMangledName("yyytd_tc")!)

  // Inout parameters.
  expectEqual(type(of: f1_inout), _typeByMangledName("yyytzc")!)

  // Ownership parameters.
  expectEqual(type(of: f1_shared), _typeByMangledName("yyyXlhc")!)
  expectEqual(type(of: f1_owned), _typeByMangledName("yyyXlc")!)

  // Mix-and-match.
  expectEqual(type(of: f2_variadic_inout), _typeByMangledName("yyytd_ytztc")!)

  // A function type that hasn't been built before.
  expectEqual("(Int, Float, Double, String, Character, UInt, Bool) -> ()",
    String(describing: _typeByMangledName("yySi_SfSdSSs9CharacterVSuSbtc")!))
}

DemangleToMetadataTests.test("metatype types") {
  expectEqual(type(of: type(of: ())), _typeByMangledName("ytm")!)
  expectEqual(type(of: type(of: f0)), _typeByMangledName("yycm")!)
}

func f2_any_anyobject(_: Any, _: AnyObject) { }

class C { }

protocol P1 { }
protocol P2 { }
protocol P3 { }

func f1_composition(_: P1 & P2) { }
func f1_composition_anyobject(_: AnyObject & P1) { }
func f1_composition_superclass(_: C & P1 & P2) { }

DemangleToMetadataTests.test("existential types") {
  // Any, AnyObject
  expectEqual(type(of: f2_any_anyobject), _typeByMangledName("yyyp_yXltc")!)

  // References to protocols.
  expectEqual(type(of: f1_composition), _typeByMangledName("yy4main2P1_4main2P2pc")!)

  // Reference to protocol with AnyObject.
  expectEqual(type(of: f1_composition_anyobject), _typeByMangledName("yy4main2P1_Xlc")!)

  // References to superclass.
  expectEqual(type(of: f1_composition_superclass), _typeByMangledName("yy4main2P1_4main2P2AA1CCXcc")!)

  // Demangle an existential type that hasn't been seen before.
  expectEqual("P1 & P2 & P3", String(describing: _typeByMangledName("4main2P1_4main2P24main2P3p")!))
}

DemangleToMetadataTests.test("existential metatype types") {
  // Any
  expectEqual(type(of: Any.self), _typeByMangledName("ypm")!)

  // AnyObject
  expectEqual(type(of: AnyObject.self), _typeByMangledName("yXlm")!)

  // References to metatype of protocols.
  expectEqual(type(of: (P1 & P2).self), _typeByMangledName("4main2P1_4main2P2pm")!)

  // References to metatype involving protocols and superclass.
  expectEqual(type(of: (C & P1 & P2).self), _typeByMangledName("4main2P1_4main2P2AA1CCXcm")!)
}

struct S {
  struct Nested { }
}

enum E { case e }

DemangleToMetadataTests.test("nominal types") {
  // Simple Struct
  expectEqual(type(of: S()), _typeByMangledName("4main1SV")!)

  // Simple Enum
  expectEqual(type(of: E.e), _typeByMangledName("4main1EO")!)

  // Simple Class
  expectEqual(type(of: C()), _typeByMangledName("4main1CC")!)

  // Swift standard library types
  expectEqual(type(of: Int()), _typeByMangledName("Si")!)
  expectEqual(type(of: Int16()), _typeByMangledName("s5Int16V")!)

  // Nested struct
  expectEqual(type(of: S.Nested()), _typeByMangledName("4main1SV6NestedV")!)

  // Class referenced by "ModuleName.ClassName" syntax.
  expectEqual(type(of: C()), _typeByMangledName("main.C")!)
}

protocol P4 {
  associatedtype Assoc1
  associatedtype Assoc2
}

extension S: P4 {
  typealias Assoc1 = Int
  typealias Assoc2 = String
}

DemangleToMetadataTests.test("substitutions") {
  // Type parameter substitutions.
  expectEqual(type(of: (1, 3.14159, "Hello")),
    _typeByMangledName("yyx_q_qd__t",
      substitutions: [[Int.self, Double.self], [String.self]])!)

  // Associated type substitutions
  expectEqual(type(of: (S(), 1, "Hello")),
    _typeByMangledName("x_6Assoc14main2P4PQz6Assoc24main2P4PQzt", substitutions: [[S.self]])!)
}

enum EG<T, U> { case a }

class CG3<T, U, V> { }

DemangleToMetadataTests.test("simple generic specializations") {
  expectEqual([Int].self, _typeByMangledName("SaySiG")!)
  expectEqual(EG<Int, String>.self, _typeByMangledName("4main2EGOySiSSG")!)
  expectEqual(CG3<Int, Double, String>.self, _typeByMangledName("4main3CG3CySiSdSSG")!)
}

extension EG {
  struct NestedSG<V> { }
}

extension C {
  enum Nested<T, U> {
    case a

    struct Innermore {
      struct Innermost<V> { }
    }
  }
}

class CG2<T, U> {
  class Inner<V> {
    struct Innermost<W1, W2, W3, W4> { }
  }
}

DemangleToMetadataTests.test("nested generic specializations") {
  expectEqual(EG<Int, String>.NestedSG<Double>.self,
    _typeByMangledName("4main2EGO8NestedSGVySiSS_SdG")!)
  expectEqual(C.Nested<Int, String>.Innermore.Innermost<Double>.self,
    _typeByMangledName("4main1CC6NestedO9InnermoreV9InnermostVy_SiSS__SdG")!)
  expectEqual(CG2<Int, String>.Inner<Double>.self,
    _typeByMangledName("4main3CG2C5InnerCySiSS_SdG")!)
  expectEqual(
    CG2<Int, String>.Inner<Double>.Innermost<Int8, Int16, Int32, Int64>.self,
    _typeByMangledName("4main3CG2C5InnerC9InnermostVySiSS_Sd_s4Int8Vs5Int16Vs5Int32Vs5Int64VG")!)
}

DemangleToMetadataTests.test("demangle built-in types") {
  expectEqual(Builtin.Int8.self,     _typeByMangledName("Bi8_")!)
  expectEqual(Builtin.Int16.self,    _typeByMangledName("Bi16_")!)
  expectEqual(Builtin.Int32.self,    _typeByMangledName("Bi32_")!)
  expectEqual(Builtin.Int64.self,    _typeByMangledName("Bi64_")!)
  expectEqual(Builtin.Int128.self,   _typeByMangledName("Bi128_")!)
  expectEqual(Builtin.Int256.self,   _typeByMangledName("Bi256_")!)
  expectEqual(Builtin.Int512.self,   _typeByMangledName("Bi512_")!)

  expectEqual(Builtin.NativeObject.self, _typeByMangledName("Bo")!)
  expectEqual(Builtin.BridgeObject.self, _typeByMangledName("Bb")!)
  expectEqual(Builtin.UnsafeValueBuffer.self, _typeByMangledName("BB")!)
}

runAllTests()
