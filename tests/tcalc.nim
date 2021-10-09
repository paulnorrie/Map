import unittest, random
import geomap/calc, tables

test "calc can reference same variable multiple times: A1 + A2 / A1":
  var src = {'A': { 1'u16: @[0x10, 0x11, 0x12], 2'u16: @[0x20, 0x21, 0x22] }.toTable() }.toTable()
  var dst = newSeq[int](3)
  
  calc("A1 + A2 div A1", @[2], src, dst, "int", "int")
  check dst == @[18, 18, 19]



when isMainModule:
  # performance of calculation on 1980 x 1080 pixel images
  const countPixels = 1980 * 1080

  # random data for bands A1 and B1
  var a1 = newSeq[byte](countPixels)
  var b1 = newSeq[byte](countPixels)
  for pixel in 0..(countPixels-1):
    let val = byte(rand(0..255))  
    a1[pixel] = val
    b1[pixel] = val

  var src = {'A': {1'u16: a1, 2'u16: b1}.toTable() }.toTable()
  var dst = newSeq[int](countPixels)
  #calc("A1 - B1 / A1 + B1", @[1,1], src, dst, "byte", "byte")