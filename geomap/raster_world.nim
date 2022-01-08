## Transforming between raster and world coordinates.

import map, gdal/[gdal, cpl, gdal_alg]

type Pos2D = tuple[x: float64, y: float64]


proc getGeoTransform(map: Map, coefficients: var array[6, float64]): bool =
  ## Does a map have a affine transformation to transform pixel
  ## to world coordinates.  The coefficients for the affine
  ## transformation will be returned in `coefficients` when
  ## this procedure returns.  If `false` is returned, then
  ## the map does not have specified affine transform
  ## coefficients but the default 1:1 coefficients will be
  ## provided in `coefficients`
  let xformErr: int = GDALGetGeoTransform(map.hDs, coefficients[0].addr)
  return xformErr != CE_Failure



proc getRPC(map: Map, rpc: var GDALRPCInfoV2): bool =
  ## Get the RPC info
  ## Returns whether RPC info exists.  If `true` then `rpc` is populated
  var rpcMd = GDALGetMetadata(map.hDs, "RPC")
  if rpcMd != nil:
    return GDALExtractRPCInfoV2(rpcMd, rpc.addr) != 0
  else:
    return false


proc createXformer(map: Map): Xformer =
  ## Create a Transformer from world to pixel coordinates
  
  var rpc: GDALRPCInfoV2
  var coefficients: array[6, float64]
  let nGCPs = getGCPCount(map.hDs)
  
  if getRPC(map, rpc):
    # try Rational Polynomial Coefficients
    let xformer = GDALCreateRPCTransformerV2(rpc.addr, 0, 0, nil)
    return Xformer(kind: xfRPC, rpc: xformer)
  
  elif getGeoTransform(map, coefficients):
    return Xformer(kind: xfAffine, affine: coefficients)
    
  elif nGCPs >= 3:
    # otherwise use Ground Control Points and do a polynomial transformation
    # need at least 3 GCPs for a 1st order transformation so do not transform
    let gcpList = getGCPs(map.hDs)
    let xformer = GDALCreateGCPTransformer(nGCPs, gcpList, 0, 0)
    return Xformer(kind: xfGCP, gcp: xformer)
    # NB: could also use Thin Spline Transformer (GDALCreateTPSTransformer)
    # or GDALCreateGCPRefineTransformer for more accuracyf
  
  else:
    # no transform available
    return Xformer(kind: xfNone)


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
  ## coordinates, the integer values of `e`, and `n` are returned.  This may
  ## happen because the map has no raster data or because it is a plain image
  ## missing geospatial data.
  ## 
  ## `e` x coordinate on the world (easting)
  ## `n` y coordinate on the world (northing)

  if map.xformer == nil:
    # create and cache a xformer since one does not yet exist
    map.xformer = map.createXformer
  
  var pixel: tuple[x: int, y: int]

  case map.xformer.kind:
  of xfRPC: 
    var x: array[1, float64]
    var y: array[1, float64]
    var z: array[1, float64]
    var success: array[1, cint]
    discard GDALRPCTransform(map.xformer.rpc, 1, 1, 
                            x[0].addr, y[0].addr, z[0].addr, success[0].addr)
    pixel = (x[0].int, y[0].int)

  of xfGCP: 
    var x: array[1, float64]
    var y: array[1, float64]
    var z: array[1, float64]
    var success: array[1, cint]
    discard GDALGCPTransform(map.xformer.gcp, 1, 1, 
                            x[0].addr, y[0].addr, z[0].addr, success[0].addr)
    pixel = (x[0].int, y[0].int)
  
  of xfAffine:
    let ul: Pos2D = (map.xformer.affine[0], map.xformer.affine[3]) # upper left
    let pixWidth = map.xformer.affine[1]
    let rotate: Pos2D = (map.xformer.affine[2], map.xformer.affine[4]);
    let pixHeight = map.xformer.affine[5] # -ve if north is up

    let divisor: float64 = (rotate.x * rotate.y - pixWidth * pixHeight)
    let x = -(rotate.x * (ul.y - n) + pixHeight * e - ul.x * pixHeight) / divisor
    let y = (pixWidth * (ul.y - n) + rotate.y * e - ul.x * rotate.y) / divisor
    pixel = (x.int, y.int)

  else:
    pixel = (e.int, n.int)

  return pixel
