import unittest
import geomap/calc, tables

test "calc A1 + A2":
  var src = {'A': { 1'u16: @[0x10, 0x11, 0x12], 2'u16: @[0x20, 0x21, 0x22] }.toTable() }.toTable()
  var dst = newSeq[int](3)
  
  bsqCalc("A1 + A2", @[2], src, dst, "int", "int")
  check dst == @[48, 50, 52]