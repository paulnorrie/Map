import std/[unittest]
import geomap/geomap, geomap/raster

test "readRaster beyond bounds raises IOError":
  expect IOError:
      let map = geomap.open("testdata/geoRGB.tiff")
      let raster = map.readRaster(BIP, x = 200, y = 200, width = 1, height = 1, [])
      check raster.data.len == 0