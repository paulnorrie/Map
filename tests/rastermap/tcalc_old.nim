import unittest, tables
import geomap/rastermap, geomap/rastermap/calc
import ../testutils
import std/monotimes, strformat

#var map = geomap.open("/Users/nozza/vinegap2/testimages/drone/bright.jpeg")
#discard map.calc[:int16]("2 * B2 - (B1 + B3)")

test "Static calc: vector expression raises compile error: A + 1":
  check: 
    notCompiles:
      let map = rastermap.open("testdata/geoRGB.tiff")
      discard calc[byte]("A + 1", map)

test "calc on single unsigned BIP raster with signed data type":
  # e.g. this is incorrect: (255.byte + 1.byte).int16 = 1
  #      this is correct:    255.int16 + 1.int16 = 256
  let map = rastermap.open("tests/rastermap/testdata/twoXtwo.tiff")
  let raster = map.raster[:byte](BIP)
  let r = raster.calc[:byte, int16]("2 * B2 - (B1 + B3)")
  let expected = @[int16 -5, -18, -18, -14]
  check r.data == expected
  
test "calc on single unsiqned BSQ raster with signed data type":
  # e.g. this is incorrect: (255.byte + 1.byte).int16 = 1
  #      this is correct:    255.int16 + 1.int16 = 256
  let map = rastermap.open("tests/rastermap/testdata/twoXtwo.tiff")
  let raster = map.raster[:byte](BSQ)
  let r = raster.calc[:byte, int16]("2 * B2 - (B1 + B3)")
  let expected = @[int16 -5, -18, -18, -14]
  check r.data == expected


