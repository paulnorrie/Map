## Transforming between raster and world coordinates.

import ../gdal/[gdal_alg] 
import common/[map, xformer]
import std/[options]


type Pos2D = tuple[x: float64, y: float64]


proc worldToPixel*(map: var Map, e: float64, n: float64): (int, int) =
  ## Transforms world coordinates in a map to the pixel coordinates for that 
  ## map. The world coordinates given in `e`,`n` must be provided in the
  ## coordinate reference system used in the map.
  ## 
  ## The return value is the (x,y) pixel coordinates for the raster in the map.
  ## It is possible for the pixel coordinates to be beyond the rasters
  ## boundary.  Negative values indicates they are to the left or above the
  ## upper-left corner of the raster. Values larger than the raster width
  ## or height indicate the position is further right or below the boundary of
  ## the raster.  Values outside the boundary of the image should not be 
  ## considered accurate, particularly if they are far from the boundary.
  ## 
  ## If the map does not have sufficient data to transform `e`,`n` to pixel
  ## coordinates, `ValueError` is raised.  This may
  ## happen because the map has no raster data or because it is a plain image
  ## missing geospatial data.
  ## 
  ## `e` x coordinate on the world (easting)
  ## `n` y coordinate on the world (northing)

  var pixel: tuple[x: int, y: int]
  
  if map.xformer().isNone():
    raise newException(ValueError, "Map has not geospatial transform")

  let xformer = map.xformer().get()

  case xformer.kind:
  of xfRPC: 
    var x: array[1, float64]
    var y: array[1, float64]
    var z: array[1, float64]
    var success: array[1, cint]
    discard GDALRPCTransform(xformer.rpc, 1, 1, 
                            x[0].addr, y[0].addr, z[0].addr, success[0].addr)
    pixel = (x[0].int, y[0].int)

  of xfGCP: 
    var x: array[1, float64]
    var y: array[1, float64]
    var z: array[1, float64]
    var success: array[1, cint]
    discard GDALGCPTransform(xformer.gcp, 1, 1, 
                            x[0].addr, y[0].addr, z[0].addr, success[0].addr)
    pixel = (x[0].int, y[0].int)
  
  of xfAffine:
    let ul: Pos2D = (xformer.affine[0], xformer.affine[3]) # upper left
    let pixWidth = xformer.affine[1]
    let rotate: Pos2D = (xformer.affine[2], xformer.affine[4]);
    let pixHeight = xformer.affine[5] # -ve if north is up

    let divisor: float64 = (rotate.x * rotate.y - pixWidth * pixHeight)
    let x = -(rotate.x * (ul.y - n) + pixHeight * e - ul.x * pixHeight) / divisor
    let y = (pixWidth * (ul.y - n) + rotate.y * e - ul.x * rotate.y) / divisor
    pixel = (x.int, y.int)

  else:
    pixel = (e.int, n.int)

  return pixel
