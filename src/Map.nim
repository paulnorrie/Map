## Map
## ===
## 
## Opening Geospatial Files
## ------------------------
## ``#read``
## 
## Types of Geospatial Data
## ------------------------
## Raster: e.g. a satellite image, a Digital Elevation Model
## Vector: e.g. a shape of country boundaries
## These can be in files or databases.
## 
## Where in the world are we?  Coordinate Reference Systems
## --------------------------------------------------------
## Each Map references somewhere in the world.  There are different ways
## of specifying this.  Latitude and Longitude are very common.
## 
## Converting between raster and geospatial coordinates
## ----------------------------------------------------
## Maps with rasters have two coordinate systems: one to identify the pixel
## on the raster and the other to identify where in the world a point on the
## map is.
## 
## For example, the upper-left pixel of a raster has x coordinate of 0 and
## y coordinate of 0.  That pixel may be located on the world at 36.9°S and
## 174.8°E.
## 
## The naming convention `x`,`y` is used for raster coordinates
## and `e` (for easting), `n` (for northing) are used
## for world coordinates.  This allows us to easily specify both coordinates
## in the same scope.
## 
## You can convert world coordinates to raster coordinates this way:
## ``
## var map = read("picture.tif")
## let (x, y) = map.worldToPixel(-36.9, 174.8)
## ``
## This example uses latitude and longitude world coordinates.  You must
## pass world coordinates in the same Coordinate Reference System the raster
## uses.  If the image above used UTM60 as a Coordinate Reference System then
## you would get an incorrect x,y value if you passed in latitude, longitude.
import gdal/gdal, gdal/cpl, gdal/gdal_alg

# register all GDAL drivers before this can be used
registerAll()

# Transformer types for transforming from world to raster coords
type 
  XformerKind = enum # method used to transform 
    xfRPC,  # use Rational Polynomial Coefficient 
    xfAffine, # use an affine transformation
    xfGCP # use Ground Control Points
    xfNone # there is no transformer

  XformerObj = object # Xformer can be one of XformerKind
    case kind: XformerKind
    of xfRPC: rpc: pointer
    of xfAffine: affine: array[6, float64]
    of xfGCP: gcp: pointer
    of xfNone: n: bool # boolean is never used - just a placeholder

  Xformer = ref XformerObj



type Map* = object
  ## An image with geospatial data.  When OpenCV functions in this
  ## module are applied to it, the geospatial data will adjust as
  ## required.  E.g. applying a transform, will transform the
  ## image and the geospatial data.
  #mat: Mat 3x2x3 (C3) interleaved
  # R G B A, R G B A, R G B A
  # R G B A, R G B A, R G B A
  #
  # GDAL looks like RasterIO defers to the driver's RasterIO type
  # so the data is loaded by the driver which may be interleaved
  #metadata: string ## custom image metadata, depending on format
  
  hDs: Dataset  # pointer to GDAL Dataset
  xformer: Xformer  # transfomer for world to raster coordinates
  
  width*: int32  ## width in pixels of the map. If the map has no
                 ## raster data, this will be 0. 
  height*: int32 ## height in pixels of the map. If the map has no
                 ## raster data, this will be 0.
  numBands*: int ## colour bands, otherwise known as channels


proc `=destroy`(this: var Map) =
  if this.xformer != nil:
    case this.xformer.kind:
    of xfGCP: 
      GDALDestroyGCPTransformer(this.xformer.gcp)
    of xfRPC: 
      GDALDestroyRPCTransformer(this.xformer.rpc)
    else : 
      discard
    
  if this.hDs != nil:
    close(this.hDs)
  

type Pos2D = tuple[x: float64, y: float64]


proc read*(path: string): Map {.raises: [IOError].} =
  ## Open a geospatial file.  
  ## 
  ## `path` is the path/filename/url for a driver to load the file.
  ## Different drivers have different paths, and not all refer to
  ## a file.
  ## 
  ## Raises an IOError if the path could not be opened
  ## by any driver
  let hDs = gdal.open(path, OF_VERBOSE_ERROR, nil, nil, nil)
  if (hDs == nil):
    # NB: OF_VERBOSE_ERROR required to get error code
    raise newException(IOError, $CPLGetLastErrorMsg())

  var map = Map(hDs: hDs)
  map.width = getRasterXSize(hDs)
  map.height = getRasterYSize(hDs)
  map.numBands = getRasterCount(hDs)

  return map;
  

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
  ## coordinates, the integer values of `e`, and `n` are returned.
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



#proc pixelToWorld(map: Map, x: int, y: int): (float64, float64) =
#  let e = 

var map = read("ArcGIS-1.1.0-scaled.tiff")
echo map.width, " x ", map.height
echo map.worldToPixel(0.0, 0.0)