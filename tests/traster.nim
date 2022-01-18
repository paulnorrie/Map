import std/[unittest]
import geomap/geomap, geomap/raster

test "readRaster beyond bounds raises IOError":
  let map = geomap.open("testdata/geoRGB.tiff")
      
  expect IOError:
    # x, y out of bounds
    discard map.readRaster(BIP, x = 200, y = 200, width = 1, height = 1, [])
  
  expect IOError:
    # x, y in bounds but x+width, y+height are not
    discard map.readRaster(BIP, x = 1, y = 1, width = 100, height = 100, [])


test "readRaster with BIP interleaving":
  let map = geomap.open("testdata/twoXtwo.tiff")
  let raster = map.readRaster(BIP)
  check raster.meta.height == 2
  check raster.meta.width == 2
  check raster.interleave == BIP
  check raster.meta.bandCount == 3
  check raster.meta.bandDataType == u8
  let expectedData = @[byte 91, 94, 102, 109, 105, 119, 93, 86, 97, 101, 98, 109]
  #                  x,y = |     0,0    |     0, 1     |    1,0    |     1, 1   |
  check raster.data == expectedData



test "readRaster with BSQ interleaving":
  let map = geomap.open("testdata/twoXtwo.tiff")
  let raster = map.readRaster(BSQ)
  check raster.meta.height == 2
  check raster.meta.width == 2
  check raster.interleave == BSQ
  check raster.meta.bandCount == 3
  check raster.meta.bandDataType == u8
  let expectedData = @[byte 91, 109, 93, 101, 94, 105, 86, 98, 102, 119, 97, 109]
  #                 band = |      red        |      green     |      blue       |       
  check raster.data == expectedData


test "readRaster with bounds returns only that section (BSQ)":
  let map = geomap.open("testdata/geoRGB.tiff")
  let raster = map.readRaster(BSQ, x = 0, y = 0, width = 2, height = 2)
  check raster.meta.height == 2
  check raster.meta.width == 2
  check raster.meta.bandCount == 3
  check raster.meta.bandDataType == u8
  check raster.data.len == 2 * 2 * 3
  check raster.interleave == BSQ
  # readRaster only reads first scanline if width given < image width
  let expectedData = @[byte 144, 136, 123, 134, 150, 135, 136, 143, 166, 151, 152, 158]
  #                 band = |        red        |      green        |        blue      |
  check raster.data == expectedData

test "readRaster with bounds returns only that section (BIP)":
  let map = geomap.open("testdata/geoRGB.tiff")
  let raster = map.readRaster(BIP, x = 1, y = 2, width = 2, height = 2)
  check raster.meta.height == 2
  check raster.meta.width == 2
  check raster.meta.bandCount == 3
  check raster.meta.bandDataType == u8
  check raster.data.len == 2 * 2 * 3
  check raster.interleave == BIP
  let expectedData = @[byte 116, 123, 131, 91, 94, 102, 91, 90, 98, 93, 86, 97]
  check raster.data == expectedData

#test "bandValue with BIP image":
#  let map = geomap.open("testdata/geoRGB.tiff")
#  let raster = map.readRaster(BIP, x = 0, y = 0, width = 10, height = 2)
#  let actual = bandValue[uint8](raster, 1, 1, 1)
#  echo raster.data
#  check actual == 91
  


