import unittest, tables
import geomap/rastermap, geomap/rastermap/calc
import ../testutils
import std/monotimes, strformat
import arraymancer

let map = rastermap.open("tests/rastermap/testdata/twoXtwo.tiff")
let raster2x2: Tensor[byte] = map.read[:byte]()



test "calc: invalid expression raises compile error: A + 1":
  check: 
    notCompiles:
      let map = rastermap.open("testdata/geoRGB.tiff")
      let raster = map.read[:byte]()
      var dst: Tensor[byte]
      raster.calc(dst, A + 1)



test "calc: expanding types":
  var dst: Tensor[int16]
  raster2x2.calc3(dst, 2*y - (x+z))
  let expected = @[int16 -5, -18, -18, -14].toTensor().reshape(2, 2, 1)
  check dst == expected
  


test "calc: conditional function":
  var dst: Tensor[int]
  raster2x2.calc1(dst):
    if x <= 100:
      0
    else:
      1
  let expected = @[int 0, 1, 0, 1,].toTensor().reshape(2, 2, 1)
  check dst == expected



test "calc: in-place":
  var raster: Tensor[byte] = map.read[:byte]()
  raster.calcInPlace3(byte((x.int32 + y.int32 + z.int32) div 3))
  let expected = @[byte 95, 111, 92, 102].toTensor().reshape(2, 2, 1)
  let band1 = raster[_, _, 0]
  check band1 == expected
