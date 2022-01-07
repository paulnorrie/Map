import unittest, tables, math
import geomap.static_memcalc


template notCompiles*(e: untyped): untyped =
  # can't compile `check not compiles:` so we use this template to write
  # ```check:
  #      notCompiles:
  #```    
  not compiles(e)



test "evaluate basic arithmetic : A + B":
  let vectors = {"A": @[0, 1, 2], "B": @[0, 1, 2]}.toTable()
  var dst = newSeqUninitialized[int](3)
  evaluateScalar("A + B", vectors, dst)

  let expected = @[0, 2, 4]
  check dst == expected



test "evaluate converting ints to floats: (A + B) / 2":
  let vectors = {"A": @[0, 1, 2], "B": @[1, 2, 3]}.toTable()
  var dst = newSeqUninitialized[float64](3)
  evaluateScalar("(A + B) / 2", vectors, dst)

  let expected = @[0.5, 1.5, 2.5]
  check dst == expected



test "evaluate converting floats to ints: A":
  let vectors = {"A": @[0.5, 1.6, 2.1]}.toTable()
  var dst = newSeqUninitialized[int](3)
  evaluateScalar("A", vectors, dst)

  let expected = @[0, 1, 2]
  check dst == expected


test "evaluate converting to unsigned wraps: A":
  let vectors = {"A": @[int8 0, -1, -2]}.toTable()
  var dst = newSeqUninitialized[uint8](3)
  evaluateScalar("A", vectors, dst)

  let expected = @[uint8 0, 255, 254]
  check dst == expected


test "evaluate with widening integer data types":
  let vectors = {"A": @[int8 0, -1, -2]}.toTable()
  var dst = newSeqUninitialized[int](3)
  evaluateScalar("A", vectors, dst)

  let expected = @[int 0, -1, -2]
  check dst == expected


test "evaluate with narrowing float data types":
  let vectors = {"A": @[float64 0, -1, -2]}.toTable()
  var dst = newSeqUninitialized[float32](3)
  evaluateScalar("A", vectors, dst)

  let expected = @[float32 0, -1, -2]
  check dst == expected


test "raises IndexDefect if dst or vector values different lengths":
  expect IndexDefect:
    let vectors = {"A": @[0], "B": @[0, 1]}.toTable()
    var dst = newSeqUninitialized[int](3)
    evaluateScalar("A + B", vectors, dst)
  

test "raises KeyError if missing vector for variable":
  expect KeyError:
    let vectors = {"A": @[0]}.toTable()
    var dst = newSeqUninitialized[int](1)
    evaluateScalar("Z", vectors, dst)



test "evaluate thresholding: A * (A > 64 and A < 195).int":
  let vectors = {"A": @[0, 127, 255]}.toTable()
  var dst = newSeqUninitialized[int](3)
  evaluateScalar("A * (A > 64 and A < 195).int", vectors, dst)
  
  let expected = @[0, 127, 0]
  check dst == expected



test "evaluate system procs: max(A, B)":
  let vectors = {"A": @[0, 127, 255], "B": @[255, 127, 127]}.toTable()
  var dst = newSeqUninitialized[int](3)
  evaluateScalar("max(A, B)", vectors, dst)
  
  let expected = @[255, 127, 255]
  check dst == expected


test "evaluate math procs: brightening with log10(A)":
  let vectors = {"A": @[0, 127, 255]}.toTable()
  var dst = newSeqUninitialized[float64](3)
  evaluateScalar("log10(float(A))", vectors, dst)
  
  let expected = @[float64 -Inf, 2.103803720955957, 2.406540180433955]
  check dst == expected

#test "evaluate with destination offset"

