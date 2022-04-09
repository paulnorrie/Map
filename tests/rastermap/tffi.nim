import geomap/rastermap/[ffi, common]
import unittest


test "copyToRaster dissallows mismatch of types":
  # float64 data but metadata says float32
  var data = @[float64 1.1, 2.2, 3.3, 4.4]
  let meta = initRasterMetadata(width = 2, height = 2, bandCount = 1, f32)
  expect ValueError:
    discard copyToRaster[float64](data.addr, meta, BIP)
  

test "copyToRaster copies data":
  var data = @[float64 1.1, 2.2, 3.3, 4.4]
  let meta = initRasterMetadata(width = 2, height = 2, bandCount = 1, f64)
  let raster = copyToRaster[float64](data[0].addr, meta, BIP)
  check raster.data == data

