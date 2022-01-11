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
