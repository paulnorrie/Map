## Map
## ===
## 
## Opening Geospatial Data
## -----------------------
## You must first ``#open`` the data (e.g. the file or database) you
## will work with.  
## 
## You can then ``#read`` the raster data or vector data.
## 
## Types of Geospatial Data
## ------------------------
## Raster: e.g. a satellite image, a Digital Elevation Model, a radar map
## Common raster formats are GeoTIFF and JPEG2000
## 
## Vector: e.g. a shape of country boundaries, points of interest in a city.
## Common vector formats are GeoJSON files, Google Earth KML files, and
## ESRI Shapefiles (a directory of .shp, .shx, .dbf).
## 
##
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
## 
## Reading very large rasters: trading performance for memory
## --------------------------
## Some images can be very large, multiple GB's.  These are not loaded in 
## memory all at one time.  Large images are worked in blocks (if the 
## driver supports it).  If you write to the raster, it may write to storage
## as you go (if the driver supports it and it has been opened with those
## permissions).
## 
## Reading vector shapes
## ---------------------
## Vector shapes often define boundaries, such as property, or markers, like
## survey points.  For example, you can read a KML file created on Google Earth
## that identifies points of interest in a city and the city boundaries.
## 
## Vectors are arranged in one or more Layers.  Each Layer has one or more
## Features.  Each Feature has one or more Geometries (such as a polygon, or a
## point), and some attributes (describing the Feature, e.g. "My House").
## 
## To read vectors, once you've opened a Map, you can iterate through all
## the vector data:
## ``
## for layer in map.layers:
##   for feature in layer.features:
##     for geometry in feature.geometries
##       echo geometry
## ``
## 
## Making masks of areas of interest on a Raster
## ---------------------------------------------
## Often you want to take a vector polygon and apply it to a raster and do 
## some operation on the raster inside or outside the polygon.  For example, you
## want an image to be transparent outside a polygon, or an image to have the
## outline of a line drawn on the raster.
## 
## ``
## map boundaries = read("boundaries.kml")
## map image = read("landscape.tif")  #RGB format
## 
## # create mask that has 0's on the outside of a polygon
## let border = boundaries.layers[0].features[0]  # assume this is a polygon
## let mask = border.createMaskOn(image, mskExterior) # mskBorder, mskInterior
## image &&= mask  # all pixels on the outside will
##                 # become black, the remaining stay
##                 # as they are
## 
## Advanced graphics operations on Rasters
## ---------------------------------------
## # or for more capability you can use SDL by exporting the border as 
## a primative polygon
## 
## SDL and Java use [x...][y...] while opencv uses [(x,y), (x,y)]
## 
## poly: tuple[T][x: seq[T], y: seq[T]]
## let poly = border.createPolygonOn(image)
## let rect = border.createRectOn(image)
## let line = border.createLineOn(image)
## 
## # addition, subtraction, bitwise operators
## dataset operator array1D # apply operator on all bands in dataset with 1D array (dataset is lhs, array is rhs)
## band operator array1D
## e.g. let result = map + mask
## let result = map.bands[0] && mask
## 
## # same but in-place (less memory and overwrites lhs)
## map += mask  #maps raster is overwritten
## map.bands[0] &&= mask #bands raster is overwritten
## 
## # band calculations you export to array and do it yourself
## e.g. NDVI
## import arraymancer
## 
## proc ndvi[T](nir: T, red: T):
##    nir + red / nir - red
## 
## let tensor = map.toArray().toTensor() #toArray gives shape Channel xHeight x Width
## let red = map.bands[4]
## let nir = map.bands[7]
## map2(red.toArray, ndvi, nir.toArray) # arraymancer
## 
## for x = 0 x < width:
##  for y = 0 y < height:   # faster way of iterating is just one loop
##    let i = x * width + y
##    result[i] = red[i] + nir[i] / red[i] - nir[i]
## 
## 
## calc does not operate on NO_DATA values - they remain the same.  If you don't
## want that, remove NO_DATA values with map.noDataTo(value: uint8 etc) first
## 
## Doing in-place operations requires write permission to storage and the driver
## to support it along with AddBand() and RemoveBand().  As soon as we do 
## in-place writes, we may need to create a new dataset and destroy the old one
##
## ``
import gdal/gdal, gdal/cpl, gdal/gdal_alg
#import shape
from math import ceil

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


type
  PixelDataType* = enum ## Representation of how a pixel value is stored
    i8,   ## 8 bit signed integer
    u8,   ## 8 bit unsigned integer
    i16,  ## 16 bit signed integer
    u16,  ## 16 bit unsigned integer
    i32,  ## 32 bit signed integer
    u32,  ## 32 bit unsigned integer
    f32,  ## 32 bit floating point
    f64,   ## 64 bit floating point
    none   ## no known data type

  Interleave* = enum ## how raster data is stored uncompressed in memory
    BSQ, ## Band Sequential interleaving, aka. planar format.  BSQ stores
         ## the raster one band at a time. I.e. All the data for band 1 is
         ## stored first, then band 2, etc.  Represented as a 3D array, the
         ## dimensions of BSQ are [Channel][X][Y]
         ## 
         ## E.g. If there are 3 bands, R, G, and B in a 2x2 image, BSQ stores
         ## image data as:
         ## 
         ## +-------+-------+-------+
         ## |       | x = 0 | x = 1 |
         ## +=======+=======+=======+
         ## | y = 0 |   R   |   R   |
         ## +-------+-------+-------+
         ## | y = 1 |   R   |   R   |
         ## +-------+-------+-------+
         ## | y = 0 |   G   |   G   |
         ## +-------+-------+-------+
         ## | y = 1 |   G   |   G   |
         ## +-------+-------+-------+
         ## | y = 0 |   B   |   B   |
         ## +-------+-------+-------+
         ## | y = 1 |   B   |   B   |
         ## +-------+-------+-------+
         ## 
         ## As a 3D array this is of shape [X, Y, Band]
         
    BIP, ## Band Interleaved by Pixel.  BIP stores the raster each pixel at a
         ## time. Each pixel has the band data written one after another.
         ## The Pixie library and OpenCV store images in this manner.
         ## 
         ## E.g. If there are three bands R, G, and B, in a 2x2 image, BIP
         ## stores image data as:
         ## 
         ## +-------+-----------+-----------+
         ## |       | x = 0     | x = 1     |
         ## +=======+===+===+===+===+===+===+
         ## | y = 0 | R | G | B | R | G | B |
         ## +-------+---+---+---+---+---+---+
         ## | y = 1 | R | G | B | R | G | B |
         ## +-------+---+---+---+---+---+---+
         ## 
         ## As a 3D array this is of the shape [Bands, X, Y]
    
    BIL, ## Band Interleaved by Line. BIL stores the raster each row at a time.
         ## Each row has the band data written one after another. This is the
         ## least commonly used manner.
         ## 
         ## E.g. If there are three bands R, G, and B, in a 2x2 image, BIL
         ## stores image data as:
         ## 
         ## +-------+-------+-------+-------+-------+-------+-------+
         ## |       | x = 0 | x = 1 | x = 0 | x = 1 | x = 0 | x = 1 |
         ## +=======+=======+=======+=======+=======+=======+=======+
         ## | y = 0 |   R   |   R   |   B   |   B   |   G   |   G   |
         ## +-------+-------+-------+-------+-------+-------+-------+
         ## | y = 1 |   R   |   R   |   B   |    B  |   G   |   G   |
         ## +-------+-------+-------+-------+-------+-------+-------+



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
  
  # raster properties
  width*: int  ## width in pixels of the map. If the map has no
                 ## raster data, this will be 0. 
  height*: int ## height in pixels of the map. If the map has no
                 ## raster data, this will be 0.
  numBands*: int ## colour bands, otherwise known as channels
  
  bitsPerPixel*: int ## number of bits required to store 1 pixel
  dataType*: PixelDataType ## data type a pixel is represented as if
                           ## interpolated
  
  rasterData*: ptr[byte]  ## raster data stored in a format indicated by
                        ## `interleave`
                        ## TODO: ptr can be set once but not changed although
                        ## the contents can be
  rasterDataSize*: uint ## size of `rasterData` in bytes
  interleave*: Interleave


proc `=destroy`(this: var Map) =
  ## Destructor for Map
  if this.xformer != nil:
    case this.xformer.kind:
    of xfGCP: 
      GDALDestroyGCPTransformer(this.xformer.gcp)
    of xfRPC: 
      GDALDestroyRPCTransformer(this.xformer.rpc)
    else : 
      discard
  
  if this.rasterData != nil:
    dealloc(this.rasterData) # must run in the same thread it was allocated on
  
  if this.hDs != nil:
    close(this.hDs)
  

type Pos2D = tuple[x: float64, y: float64]



converter toPixelDataType(gdal: GDALDataType) : PixelDataType =
  # implicity converts GDALDataType to PixelDataType
  # e.g. let pdt: PixelDataType = GDT_Byte
  case gdal:
  of GDT_Unknown: return none
  of GDT_Byte: return u8
  of GDT_Int16: return i16
  of GDT_UInt16: return u16
  of GDT_Int32: return i32
  of GDT_UInt32: return u32
  of GDT_Float32: return f32
  of GDT_Float64: return f64
  else: return none



converter toGDALDataType(dt: PixelDataType) : GDALDataType =
  # implicity converts PixelDataType to GDALDataType
  # e.g. let gdal_dt = u8
  case dt:
  of u8: return GDT_Byte
  of i8: return GDT_Byte
  of u16: return GDT_UInt16
  of i16: return GDT_Int16
  of u32: return GDT_UInt32
  of i32: return GDT_Int32
  of f32: return GDT_Float32
  of f64: return GDT_Float64
  else: return GDT_Unknown    



proc calcBitsPerPixelAndDataType(hDs: Dataset): (int, PixelDataType) = 
  ## Calculate the number of bits required to store a pixel and the data type 
  ## that addresses the a pixel value.  If bands have different data types or 
  ## bit lengths then the smallest data type that fully expresses
  ## all bands is used.
  ## 
  ## Returns a tuple (bits per pixel, data type).
  ## If the dataset does not have a raster, this will return (0, none)
  
  var bpp: int = 0
  var bestDataType: GDALDataType
  
  for b in 1..getRasterCount(hDs):
    let hRb = GDALGetRasterBand(hDs, b)
    let dt = GDALGetRasterDataType(hRb)
    bpp += GDALGetDataTypeSizeBits(dt)
    if b == 1:
      bestDataType = dt
    else:
      bestDataType = GDALDataTypeUnion(dt, bestDataType)

  return (bpp, bestDataType.toPixelDataType);



proc open*(path: string): Map {.raises: [IOError].} =
  ## Open a geospatial file.  
  ## 
  ## `path` is the path/filename/url for a driver to load the file.
  ## Different drivers have different paths, and not all refer to
  ## a file.  For example to open ESRI shape files (.shp, .shx, .dbf)
  ## you can specify the directory all the files are in.
  ## 
  ## Raises an IOError if the path could not be opened
  ## by any driver
  let hDs = gdal.open(path, OF_VERBOSE_ERROR, nil, nil, nil)
  if (hDs == nil):
    # NB: OF_VERBOSE_ERROR required to get error code
    raise newException(IOError, $CPLGetLastErrorMsg())

  var map = Map(hDs: hDs)

  # TODO: move these to readRaster functions?  Maybe not, because metadata
  # is useful without having to read a large image entirely just because
  # you want to know the metadata
  map.width = getRasterXSize(hDs)
  map.height = getRasterYSize(hDs)
  map.numBands = getRasterCount(hDs)
  (map.bitsPerPixel, map.dataType) = calcBitsPerPixelAndDataType(hDs)

  return map;
  


proc readRaster*(map: var Map): bool = 
  ## Read a raster of a Map into memory.  It is stored as Band Interleaved by Pixel.
  ## Once this proc successfully returns, the Map will store the raster in 
  ## `map.rasterData`.
  ## 
  ## TODO: For large images, you can either load a region of interest (clipped
  ## area) or a single band, or a region of interest on a single band.
  ## This is useful if you intend to do some processing on the image that can
  ## be done in chunks.  A large image is most efficiently iterated over
  ## in it's GDALGetBlockSize  https://www.gis.usu.edu/~chrisg/python/2009/lectures/ospy_slides4.pdf page 34
  ## 
  ## If the Map has no raster data
  
  # CxHxW of (3,1,1) [c][w][h] = c + w * CHANNEL + (h * CHANNEL * WIDTH)
  # => 3 + 1 * 4 + (1 * 4 * 3)
  # => 3 + 4 + 12
  # => 19
  # = 11

  if map.numBands <= 0:
    return false;

  let bytesPerPixel = ceil(map.bitsPerPixel.float / 8'f).int
  map.rasterDataSize = (map.width * map.height * bytesPerPixel).uint
  #map.rasterData = create(byte, map.rasterDataSize) # dealloced in destructor
  map.rasterData = createU(byte, map.rasterDataSize) # dealloced in destructor
  var bands = newSeq[cint](map.numBands)
  for b in 1..map.numBands:
    bands[b - 1] = b.cint

  #TODO: why does gdal use signed integers for width, height, numBands etc
  # because then I have to use the same resolution (we could lose data if
  # we wrote unsigned int to a signed int in GDAL and couldn't handle larger
  # images anyway)
  let success = GDALDatasetRasterIOEx(map.hDs,
                        GF_Read,
                        0,
                        0,
                        map.width.cint, map.height.cint, # read from these x,y
                        map.rasterData,     # data is read into this memory
                        map.width.cint, map.height.cint, # read until here
                        map.dataType,       # data type of a individual pixel
                        map.numBands.cint,        # number of bands to read 
                        bands[0].addr, # bands to read
                        0.cint,        # bytes from one pixel to the next pixel in 
                                  # the scanline = dt (i.e. pixel interleaved)
                        0.cint,        # bytes from start of one scanline to the
                                  # next = dt * nBufXSize (i.e pixel interleaved)
                        0.cint,        # 
                        nil)      # TODO: progress callback
  
  return success == CE_None



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



proc main(): void = 
  #var map = open("ArcGIS-1.1.0-scaled.tiff")
  #var map = open("chart-nz-5612-napier-roads.jpg")
  #var map = open("DSM_AZ31_1026_2013.tif")
  #var map = open("0703622w_332603s_20200624T090349Z_dtm.tif")
  var map = open("/Users/nozza/Downloads/rgb.jpeg")
  echo map.readRaster()
  echo "Read"


main()