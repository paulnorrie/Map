## The Map type, and it's accessors and mutators.  
## 
## `import geomap/rastermap` includes this module.
## 
## The Map holds the width, height, number of raster bands, data type,
## spatial reference system and transformer method between raster and world
## co-ordinates.
## 
## You can get all of these as a profile of a Map by calling `profile`.
## 
## See also:
## - `raster_world` module for calculating between raster and world co-ordinates

import ../../gdal/[gdal, gdal_alg, cpl]
import srs, xformer
import std/[options, tables]

{.experimental: "notnil".}

type MapObj = object
  # Map is a reference to MapObj so that when Map is destroyed, it does not
  # destroy the GDAL handle to the dataset.  Only when MapObj is destroyed
  # will that occur.
  isCopy: bool  

  hDs: pointer not nil  # pointer to GDAL Dataset
    ## TODO: make thread-safe as this pointer should not be used by different threads concurrently
  path: string          # path to the maps data source

type Map* = ref MapObj
  ## A raster dataset.



proc handle*(map: Map) : pointer =
  ## Return the handle of the GDAL dataset for calling GDAL procs.  This is
  ## useful if you wish to call a GDAL function with this map.
  result = map.hDs



func path*(map: Map) : string =
  ## The path that `map` was opened with
  result = map.path



func bandCount*(map: Map) : int =
  ## The number of raster bands in `map`
  result = GDALGetRasterCount(map.hDs)



func width*(map: Map) : int =
  ## Width of raster bands in pixels or digital numbers in `map`
  result = GDALGetRasterXSize(map.hDs)



func height*(map: Map) : int =
  ## Height of raster bands in pixels or digital numbers in `map`
  result = GDALGetRasterYSize(map.hDs)



proc `=destroy`(this: var MapObj) =
  # Destructor for MapObj 
  
  #close dataset if this is not a copy
  if this.hDs != nil:
    close(this.hDs)
      


proc close*(map: Map) = 
  ## Close the Map, and release any resources. `Map` should not be referenced
  ## after calling this procedure.  A `Map` is automatically closed when it
  ## is destroyed, so this method does not need to be called in most situations.
  close(map.hDs)



proc `$`*(map: Map) : string =
  result = map.path



proc bandDataType*(map: Map) : GDALDataType =
  ## Data type of the first band in `map`
  let hRb = GDALGetRasterBand(map.hDs, 1)
  result = GDALGetRasterDataType(hRb)



type
  BandColour* = enum 
    ## How a value in a band models colour, implicity 
    ## initialises to `Unknown`
    bcUnknown = (0, "Unknown") ## Not known how this band models colour
    bcGreyscale = (1, "Greyscale") ## values are greyscale
    bcPalette = (2, "Palette") ## values are indicies to a colour table
    bcRed = (3, "Red") ## values are the red component of RGBA colour model
    bcGreen = (4, "Green") ## values are the green component of RGBA colour model
    bcBlue = (5, "Blue") ## values are the blue component of RGBA colour model
    bcAlpha = (6, "Alpha") ## values are the alpha component of RGBA colour model
    bcHue = (7, "Hue") ## values are the hue component of HSL colour model
    bcSaturation = (8, "Saturation") ## values are the saturation component of HSL colour model
    bcLightness = (9, "Lightness") ## values are the lightness component of HSL colour model
    bcCyan = (10, "Cyan") ## values are the cyan component of CMYK colour model
    bcMagenta = (11, "Magenta") ## values are the magenta component of CMYK colour model
    bcYellow = (12, "Yellow") ## values are the yellow component of CMYK colour model
    bcBlack = (13, "Black") ## values are the black component of CMYK colour model
    bcY_Luminance = (14, "Y Luminance") ## values are the Y Luminance of Y Cb Cr colour model
    bcCb_Chroma = (15, "Cb Chroma") ## values are the Cb Chroma of Y Cb Cr colour model
    bcCr_Chroma = (16, "Cr Chroma") ## values are the Cr Chroma of Y Cb Cr colour model



converter toBandColour(bc: GDALColorInterp) : BandColour = 
  ## implicity convert GDALColorInterp to BandColour
  case bc:
  of GCI_Undefined: return bcUnknown
  of GCI_GrayIndex: return bcGreyscale
  of GCI_PaletteIndex: return bcPalette
  of GCI_RedBand: return bcRed
  of GCI_GreenBand: return bcGreen
  of GCI_BlueBand: return bcBlue
  of GCI_AlphaBand: return bcAlpha
  of GCI_HueBand: return bcHue
  of GCI_SaturationBand: return bcSaturation
  of GCI_LightnessBand: return bcLightness
  of GCI_CyanBand: return bcCyan
  of GCI_MagentaBand: return bcMagenta
  of GCI_YellowBand: return bcYellow
  of GCI_BlackBand: return bcBlack
  of GCI_YCbCr_YBand: return bcY_Luminance
  of GCI_YCbCr_CbBand: return bcCb_Chroma
  of GCI_YCbCr_CrBand: return bcCr_Chroma



func bandColours*(map: Map) : seq[BandColour] = 
  ## The band colours, in order of band, if known.
  let numBands = GDALGetRasterCount(map.hDs)
  result = newSeq[BandColour](numBands)

  for b in 1..numBands:
    let hRb = GDALGetRasterBand(map.hDs, b)
    let bandColour = GDALGetRasterColorInterpretation(hRb)
    result[b - 1] = bandColour



proc srs*(map: Map) : Option[SpatialReferenceSystem] =
  ## Return the Spatial Reference System of a map or none if it doesn't
  ## have one.
  var hSrs = GDALGetSpatialRef(map.handle)
  if hSrs == nil:
    hSrs = GDALGetGCPSpatialRef(map.handle)

  if hSrs != nil:  
    result = some(initSpacialReferenceSystem(hSrs))



proc getGeoTransform(map: Map, coefficients: var array[6, float64]): bool =
  ## Does a map have a affine transformation to transform pixel
  ## to world coordinates.  The coefficients for the affine
  ## transformation will be returned in `coefficients` when
  ## this procedure returns.  If `false` is returned, then
  ## the map does not have specified affine transform
  ## coefficients but the default 1:1 coefficients will be
  ## provided in `coefficients`
  let xformErr: int = GDALGetGeoTransform(map.handle, coefficients[0].addr)
  return xformErr != CE_Failure



proc getRPC(map: Map, rpc: var GDALRPCInfoV2): bool =
  ## Get the RPC info
  ## Returns whether RPC info exists.  If `true` then `rpc` is populated
  var rpcMd = GDALGetMetadata(map.handle, "RPC")
  if rpcMd != nil:
    return GDALExtractRPCInfoV2(rpcMd, rpc.addr) != 0
  else:
    return false



proc xformer*(map: Map) : Option[Xformer] =
  ## Get a Transformer from world to pixel coordinates or None if it doesn't
  ## have one.
  
  var rpc: GDALRPCInfoV2
  var coefficients: array[6, float64]
  let nGCPs = getGCPCount(map.handle)
  
  if getRPC(map, rpc):
    # try Rational Polynomial Coefficients
    let xformer = GDALCreateRPCTransformerV2(rpc.addr, 0, 0, nil)
    return some(Xformer(kind: xfRPC, rpc: xformer))
  
  elif getGeoTransform(map, coefficients):
    return some(Xformer(kind: xfAffine, affine: coefficients))
    
  elif nGCPs >= 3:
    # otherwise use Ground Control Points and do a polynomial transformation
    # need at least 3 GCPs for a 1st order transformation so do not transform
    let gcpList = getGCPs(map.handle)
    let xformer = GDALCreateGCPTransformer(nGCPs, gcpList, 0, 0)
    return some(Xformer(kind: xfGCP, gcp: xformer))
    # NB: could also use Thin Spline Transformer (GDALCreateTPSTransformer)
    # or GDALCreateGCPRefineTransformer for more accuracyf
  
  # else no transform available



type MapProfile* = object
  ## information about a Map
  
  width*: int  ## width in pixels of the map.  
              
  height*: int ## height in pixels of the map. 
               
  bandCount*: int ## number of bands, otherwise known as channels. Must be the same as 
                 ## `bandColours.length`
  
  bandDataType*: GDALDataType 
    ## Data type required to represent one bands (not pixel) value.
    ## Images having bands with different 
    ## data types or bit lengths, are converted to a
    ## suitable data type to handle each band the same.  
    ## Images that have sub-byte resolution for a single
    ## band (e.g. 16-bit 565RGB), will be expanded to a 8-bit
    ## data type.  In this example `bandDataType` would be `GDT_Byte` and `bitsPerPixel`
    ## would be 16.

  xformer*: Option[Xformer]
    ## The transformer to map between world and raster coordinates, if available
  
  srs*: Option[SpatialReferenceSystem]
    ## The spatial reference system used to identify world coordinates
  
  options*: Table[string, string]
    ## Open options



proc profile*(map: Map) : MapProfile =
  ## Read the metadata of the map, including dimensions, 
  ## data type, number of bands, and georeferencing information.
  ##
  ## The resulting profile can be used to create new maps when calling 
  ## `<#open(string, MapProfile)>`_
  let xformer = map.xformer()
  let srs = map.srs()
  result.width = map.width()
  result.height = map.height()
  result.bandDataType = map.bandDataType()
  result.bandCount = map.bandCount()
  result.xformer = xformer
  result.srs = srs


type
  BlockInfo* = object
    ## Rasters can be partioned into a grid of smaller rectangles, called blocks 
    ## or tiles. Each block has the same dimensions, although blocks do not
    ## have to evenly align with the width or height of an image.  This means
    ## the right and bottom-most blocks may larger than the portion of the image
    ## contained in them.
    xBlockCount*: int
      ## the number of blocks horizontally in the grid
    yBlockCount*: int
      ## the number of blocks vertically in the grid
    xPixels*: int
      ## the number of horizontal pixels in each block
    yPixels*: int  
      ## the number of vertical pixels in each block



proc blockInfo*(map: Map) : BlockInfo =
  ## Return the number of blocks horizontally and vertically in the maps
  ## raster and their size.
  ## A block is the most efficient size to read and is determined by the
  ## driver.  If the image is tiled, it is normally the size of a tile. 
  ## Otherwise it is normally a scanline.  
  ## 
  ## Note that blocks do not have to divide the image evenly which means
  ## that the right and bottom blocks may be incomplete.
  let dataset = map.handle
  let band = GDALGetRasterBand(dataset, 1) # count blocks in the first band
  var blockXSize, blockYSize: int  
  GDALGetBlockSize(
      band,
      cast[ptr cint](blockXSize.unsafeAddr),
      cast[ptr cint](blockYSize.unsafeAddr)
  )
  let numXBlocks:int = int( (map.width() + blockXSize - 1) / blockXSize)
  let numYBlocks:int = int( (map.height() + blockYSize - 1) / blockYSize)
  
  var blocks: BlockInfo
  blocks.xBlockCount = numXBlocks
  blocks.yBlockCount = numYBlocks
  blocks.xPixels = blockXSize
  blocks.yPixels = blockYSize

  return blocks

  

  
