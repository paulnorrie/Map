import unittest, tables
import geomap/geomap, geomap/calc, geomap/raster, geomap/private/anyitems 
import testutils


#test "Static calc: vector expression raises compile error: A + 1":
#  check: 
#    notCompiles:
#      let map = geomap.open("testdata/geoRGB.tiff")
#      discard calc("A + 1", map, u8)
#
#test "Static calc: missing a map in expression raises exception":
#  expect ValueError:
#    let mapA = geomap.open("testdata/geoRGB.tiff")
#    let mapZ = geomap.open("testdata/geoRGB.tiff")
#    discard calc("B1 + C1", {'A': mapA, 'Z': mapZ}.newTable(), u8)


test "Static calc: Reference same variable multiple times: A1 + A2 div A1":
  let mapA = geomap.open("testdata/twoXtwo.tiff")
  let raster = mapA.calc("A1 + A1", u8)
  let expected = @[byte 182, 218, 186, 202]
  check raster.data == expected
  


