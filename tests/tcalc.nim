import unittest, tables
import geomap/geomap, geomap/calc, geomap/raster, geomap/private/anyitems 
import testutils


test "Static calc: vector expression raises compile error: A + 1":
  check: 
    notCompiles:
      let map = geomap.open("testdata/geoRGB.tiff")
      discard calc[byte]("A + 1", map)

test "Static calc: missing a map in expression raises exception":
  expect ValueError:
    let mapA = geomap.open("testdata/geoRGB.tiff")
    let mapZ = geomap.open("testdata/geoRGB.tiff")
    discard calc[byte]("B1 + C1", {'A': mapA, 'Z': mapZ}.newTable())


test "calc on single map":
  let mapA = geomap.open("testdata/twoXtwo.tiff")
  let raster = mapA.calc[:byte]("A1 + A1")
  let expected = @[byte 182, 218, 186, 202]
  check raster.data == expected

test "calc on single map expanding data type":
  let map = geomap.open("testdata/twoXtwo.tiff")
  let raster = calc[int16]("2 * B2 - (B1 + B3)", {'B': map}.newTable())
  let expected = @[int16 182, 218, 186, 202]
  check raster.data == expected
  


