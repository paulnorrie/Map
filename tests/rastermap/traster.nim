import std/[unittest, strutils, nre, tempfiles]
import geomap/rastermap
import geomap/gdal/gdal, ../testutils



test "raster beyond bounds raises IOError":
  let map = rastermap.open("tests/rastermap/testdata/geoRGB.tiff")
      
  expect IOError:
    # x, y out of bounds
    discard map.raster[:int32](BIP, x = 200, y = 200, width = 1, height = 1, [])
  
  expect IOError:
    # x, y in bounds but x+width, y+height are not
    discard map.raster[:int32](BIP, x = 1, y = 1, width = 100, height = 100, [])


test "raster with BIP interleaving":
  let map = rastermap.open("tests/rastermap/testdata/twoXtwo.tiff")
  let raster = map.raster[:byte](BIP)
  check raster.meta.height == 2
  check raster.meta.width == 2
  check raster.interleave == BIP
  check raster.meta.bandCount == 3
  check raster.meta.bandDataType == u8
  let expectedData = @[byte 91, 94, 102, 109, 105, 119, 93, 86, 97, 101, 98, 109]
  #                  x,y = |     0,0    |     0, 1     |    1,0    |     1, 1   |
  check raster.data == expectedData
  


test "raster with BSQ interleaving":
  let map = rastermap.open("tests/rastermap/testdata/twoXtwo.tiff")
  let raster = map.raster[:byte](BSQ)
  check raster.meta.height == 2
  check raster.meta.width == 2
  check raster.interleave == BSQ
  check raster.meta.bandCount == 3
  check raster.meta.bandDataType == u8
  let expectedData = @[byte 91, 109, 93, 101, 94, 105, 86, 98, 102, 119, 97, 109]
  #                 band = |      red        |      green     |      blue       |       
  check raster.data == expectedData


test "raster with bounds returns only that section (BSQ)":
  let map = rastermap.open("tests/rastermap/testdata/geoRGB.tiff")
  let raster = map.raster[:byte](BSQ, x = 0, y = 0, width = 2, height = 2)
  check raster.meta.height == 2
  check raster.meta.width == 2
  check raster.meta.bandCount == 3
  check raster.meta.bandDataType == u8
  check raster.data.len == 2 * 2 * 3
  check raster.interleave == BSQ
  # raster only reads first scanline if width given < image width
  let expectedData = @[byte 144, 136, 123, 134, 150, 135, 136, 143, 166, 151, 152, 158]
  #                 band = |        red        |      green        |        blue      |
  check raster.data == expectedData

test "raster with bounds returns only that section (BIP)":
  let map = rastermap.open("tests/rastermap/testdata/geoRGB.tiff")
  let raster = map.raster[:byte](BIP, x = 1, y = 2, width = 2, height = 2)
  check raster.meta.height == 2
  check raster.meta.width == 2
  check raster.meta.bandCount == 3
  check raster.meta.bandDataType == u8
  check raster.data.len == 2 * 2 * 3
  check raster.interleave == BIP
  let expectedData = @[byte 116, 123, 131, 91, 94, 102, 91, 90, 98, 93, 86, 97]
  check raster.data == expectedData

test "cannot change dimensions or metadata of raster data":
  let map = rastermap.open("tests/rastermap/testdata/twoXtwo.tiff")
  let raster = map.raster[:byte]()
  
  check:
    notCompiles:
      raster.data = newSeq[byte](1024)

  check:
    notCompiles:
      raster.meta.width = 1000
  
  check:
    notCompiles:
      raster.meta = initRasterMetadata(width = 100, 
                                       height = 100, 
                                       bandCount = 1, 
                                       interleave = BSQ, 
                                       dataType = f64)
  
test "raster converting floating point raster to int32 image":
  let map = rastermap.open("tests/rastermap/testdata/Chloraphyll.tiff")
  var raster = map.raster[:int32](BIP, x = 100, y = 100, width = 2, height = 2)
  let expectedData = @[int32 0, 9, 1, 2] 
  check raster.data == expectedData

  
test "raster with a larger integer data type than the image has":
  let map = rastermap.open("tests/rastermap/testdata/twoXtwo.tiff")
  var raster = map.raster[:int32](BIP)
  let expectedData = @[int32 91, 94, 102, 109, 105, 119, 93, 86, 97, 101, 98, 109]
  check raster.data == expectedData

test "raster with a smaller integer data type than the image has":
  # TODO
  check false

test "new map writes srs and georeference from source map":
  let map1 = rastermap.open("tests/rastermap/testdata/twoXtwo.tiff")
  let expSrs = map1.srs
  let expXform = map1.xformer
  let tmpPath = genTempPath("tmp", "geomap.tiff")
  let map2 = rastermap.open(tmpPath, map1.profile)
  let actualSrs = map2.srs
  let actualXform = map2.xformer

  check actualSrs == expSrs
  check actualXform == expXform
  

test "rasters are equal if same dimensions, datatype, interleave, and contents":
  # different width
  var r1 = initRaster[byte](3, 1, 1, BIP)
  var r2 = initRaster[byte](4, 1, 1, BIP)
  check r1 != r2

  # different height
  r1 = initRaster[byte](3, 1, 1, BIP)
  r2 = initRaster[byte](3, 2, 1, BIP)
  check r1 != r2

  # different number of bands
  r1 = initRaster[byte](3, 1, 1, BIP)
  r2 = initRaster[byte](3, 1, 2, BIP)
  check r1 != r2

  # different interleave
  r1 = initRaster[byte](3, 1, 1, BIP)
  r2 = initRaster[byte](3, 1, 1, BSQ)
  check r1 != r2

  # different type
  check:
    notCompiles:
      var meta1 = initRasterMetadata(1, 1, 1, i32)
      var meta2 = initRasterMetadata(1, 1, 1, u8)
      var r3 = initRaster(@[int32 1], meta1, BIP)
      var r4 = initRaster(@[byte 1], meta2, BIP)
      check r3 != r4

  # same
  var meta1 = initRasterMetadata(2, 2, 1, u8)
  let data1 = @[byte 1, 2, 3, 4]
  r1 = initRaster(data1, meta1, BIP)
  r2 = initRaster(data1, meta1, BIP)
  check r1 == r2