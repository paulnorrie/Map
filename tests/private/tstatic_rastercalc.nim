import geomap/[geomap, raster, static_rastercalc]
import unittest, tables

#test "calc on single 3 band image":
#  let map = geomap.open("tests/testdata/geoRGB.tiff")
#  let dst = calc("2 * A2 - (A1 + A3)", {'A':map}.newTable(), u8)
#  check dst.
#test "readBlock only reads image bounds if block size larger":
#  let map = geomap.open("tests/testdata/geoRGB.tiff")
#  let blockInfo = BlockInfo(xBlockCount: 1, yBlockCount: 1, xPixels: 1, yPixels: 1)
#  let band = readBlock[byte](0,0, blockInfo, map, 1)
#  check band.len == 34 * 28 # and not 100 * 100 as per block size


#test "calc on Maps with different blocks sizes":
#  check 1 == 2

#test "calc on Maps with non-aligned block sizes":
#  check 1 == 2

#test "calc on Rasters with BIP interleaving":
#  let width = 2
#  let height = 2
#  let numBands = 3
#  
#  # A and B are rasters with 3 bands of values:
#  #          x = 0 ,    x = 1
#  # y = 0 | (0,1,2), (3,  4,  5)
#  # y = 1 | (6,7,8), (9, 10, 11)
#  let A = initRaster(width, height, numBands, BIP, i8)
#  for y in 0 ..< height:
#    for x in 0 ..< width:
#      let startOff = (y * width + x) * numBands
#      let stopOff = startOff + numBands - 1
#      A.data[startOff .. stopOff] = startOff#

#  let B = A # copy, not ref#

#  let rasters = {'A': A, 'B': B}.newTable()
#  let raster = calc("A2 + B3", rasters, i8)