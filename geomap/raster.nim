
import geomap, gdal/[gdal, cpl]
import math, strformat

## Read and write rasters.
## This module operates only on Map instances that are of the Raster kind.
## 
## Opening a Raster
## ----------------
## The entire raster can be loaded into memory by calling `readRaster`_ or
## `readBand`_ . Raster
## data is stored as `seq[byte]` as the rasters data type is not known until
## runtime.
runnableExamples:
  import geomap, raster
  let map = geomap.open("image.tif")    # open the Map
  let raster = map.readRaster()       
  echo raster.data[0]                   # this is the first byte
  echo raster.meta.width
## You can just read the metadata, without loading any of the raster into 
## memory by calling `readMetadata`_
## 
## You can read part of a raster, by calling `readBand`_ to read just one
## (or part of) a band, or `readRaster`.
## 
## Creating a new Raster
## ---------------------
## Create a new raster by calling `initRaster <#int,int,int,RasterMetadata>`_
runnableExamples:
  # create a 1 pixel RGB grey image
  let raster = initRaster(width = 1, height = 1, 
    bandCount = 3, interleave = BIP, bandDataType = i8)
  raster.rasterData[0] = 0x77 # red
  raster.rasterData[1] = 0x77 # green
  raster.rasterData[2] = 0x77 # blue
## 
## Modifying a Raster
## ------------------
## TBD
## 


type
  RasterDataType* {.pure.} = enum 
    ## Representation of how a pixel value or band value is stored, 
    ## implicity initialises to `none`
    none   ## no known data type
           # none is the implicit initialisation as it's the 0th value
    i8 = "8-bit signed integer",   ## 8 bit signed integer
    u8 = "8-bit unsigned integer",   ## 8 bit unsigned integer (byte)
    i16 = "16-bit signed integer",  ## 16 bit signed integer
    u16 = "16-bit unsigned integer",  ## 16 bit unsigned integer
    i32 = "32-bit signed integer",  ## 32 bit signed integer
    u32 = "32-bit unsigned integer",  ## 32 bit unsigned integer
    f32 = "32-bit floating point",  ## 32 bit floating point
    f64 = "64-bit floating point",   ## 64 bit floating point
    

func bytesForDataType(dt: RasterDataType) : int {.inline.} =
  case dt
  of i8, u8: return 1
  of i16, u16: return 2
  of i32, u32, f32: return 4
  of f64: return 8
  of none: return 1  # 0 bytes would probably lead to bad things

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

type  
  Interleave* {.pure.}= enum ## how raster data is stored uncompressed in memory
    BSQ = "BSQ", ## Band Sequential interleaving, aka. planar format.  BSQ stores
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
         
    BIP = "BIP", ## Band Interleaved by Pixel.  BIP stores the raster each pixel at a
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
    
    BIL = "BIL", ## Band Interleaved by Line. BIL stores the raster each row at a time.
         ## Each row has the band data written one after another. This is the
         ## least commonly used manner.
         ## 
         ## E.g. If there are three bands R, G, and B, in a 2x2 image, BIL
         ## stores image data as:
         ## 
         ## +-------+-------+-------+-------+-------+-------+-------+
         ## |       | x = 0 | x = 1 | x = 0 | x = 1 | x = 0 | x = 1 |
         ## +=======+=======+=======+=======+=======+=======+=======+
         ## | y = 0 |   R   |   R   |   G   |   G   |   B   |   B   |
         ## +-------+-------+-------+-------+-------+-------+-------+
         ## | y = 1 |   R   |   R   |   G   |   G   |   B   |   B   |
         ## +-------+-------+-------+-------+-------+-------+-------+


type RasterMetadata* {.requiresinit.} = object 
  ## information about a Raster
  
  width*: int  ## width in pixels of the map.  
              
  height*: int ## height in pixels of the map. 
               
  numBands*: int ## colour bands, otherwise known as channels. Same as 
                 ## `bandColours.length`
  
  bandColours*: seq[BandColour] ## How each band models a colour component.
                                ## There is one element for `numBands` in order
                                ## of bands, i.e. bandColours[0] is the first
                                ## band.  This may not be known.

  bitsPerPixel*: int ## Number of bits required to store 1 pixel if it was
                     ## stored in BIP format. 
  
  bytesPerPixel*: int ## Number of bytes required to store 1 pixel

  bandDataType*: RasterDataType 
    ## Data type required to represent one bands (not pixel) value.
    ## Images having bands with different 
    ## data types or bit lengths, are converted to a
    ## suitable data type to handle each band the same.  
    ## Images that have sub-byte resolution for a single
    ## band (e.g. 16-bit 565RGB), will be expanded to a 8-bit
    ## data type.  In this example `bandDataType` would be `u8` and `bitsPerPixel`
    ## would be 16.

type Raster* {. requiresInit .} = object 
  ## A raster image in memory.  This isn't designed to handle byte data loaded
  ## by other libraries or code because it doesn't handle non-byte aligned
  ## band data (e.g. RGB565) and much of the calc methods require metadata
  ## to be there.
  data*: seq[byte]  ## The raster data as bytes, formatted according to
                    ## `interleave`
  
  interleave*: Interleave ## the interleaving format of `data` in memory. 
  
  meta*: RasterMetadata ## metadata information about the raster


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


converter toPixelDataType*(gdal: GDALDataType) : RasterDataType =
  ## implicity converts GDALDataType to RasterDataType
  ## e.g. let pdt: RasterDataType = GDT_Byte
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


converter toGDALDataType(dt: RasterDataType) : GDALDataType =
  ## implicity converts RasterDataType to GDALDataType
  ## e.g. let gdal_dt = u8
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

converter toNimTypeStr*(dt: RasterDataType) : string =
  ## implicity converts RasterDataType to a Nim type string description
  case dt:
  of u8: return "uint8"
  of i8: return "int8"
  of u16: return "uint16"
  of i16: return "int16"
  of u32: return "uint32"
  of i32: return "int32"
  of f32: return "float32"
  of f64: return "float64"
  else: raise newException(
                          ValueError,
                          fmt"RasterDataType {dt} does not have a Nim type")


type 
  ImageIdType* = char
  ImageOrdinalType* = uint8
  BandOrdinalType* = uint16 # because sometimes we need 0 to represent all bands

  ValidBandOrdinal* = range[1'u16 .. high(BandOrdinalType)]
        ## Valid Band Ordinal is the number of the band that ranges 1..65535

  VariableInfo* = tuple
    imageId: ImageIdType
    imageOrdinal: ImageOrdinalType
    bandOrd: BandOrdinalType


proc calcBitsBytesPerPixelAndDataType(map: Map): (int, int, RasterDataType) = 
  ## Calculate the number of bits required to store a pixel and the data type 
  ## that addresses the a pixel value.  If bands have different data types or 
  ## bit lengths then the smallest data type that fully expresses
  ## all bands is used.
  ## 
  ## Returns a tuple (bits per pixel, bytes per pixel, data type).
  ## If the dataset does not have a raster, this will return (0, none)
  
  var bitsPerPixel: int = 0
  var bestDataType: GDALDataType
  let hDs = map.dataset

  let bandCount = GDALGetRasterCount(hDs)
  for b in 1..bandCount:
    let hRb = GDALGetRasterBand(hDs, b)
    if hRb.isNil:
      let msg = fmt"Unable to get band {b} for map {map.path}. " & $CPLGetLastErrorMsg()
      echo msg
      raise newException(IOError, msg)
    let dt = GDALGetRasterDataType(hRb)
    bitsPerPixel += GDALGetDataTypeSizeBits(dt)
    if b == 1:
      bestDataType = dt
    else:
      bestDataType = GDALDataTypeUnion(dt, bestDataType)

  let bytesPerPixel = ceil(bitsPerPixel / 8).int

  return (bitsPerPixel, bytesPerPixel, bestDataType.toPixelDataType);



proc initRasterMetadata(width, height, bandCount: int, bandDataType: RasterDataType) : RasterMetadata =
  let bytesPerPixel = bandCount * bytesForDataType(bandDataType)
  let bitsPerPixel = bytesPerPixel * 8

  result = RasterMetadata(width: width, 
                          height: height,
                          numBands: bandCount,
                          bandColours: newSeq[BandColour](bandCount),
                          bandDataType: bandDataType,
                          bytesPerPixel: bytesPerPixel,
                          bitsPerPixel: bitsPerPixel)
  



proc initRaster(md: RasterMetadata, interleave: Interleave) : Raster =
  ## Initialise a blank Raster with metadata and interleaving.  The returned
  ## Raster will have a sequence suitable to hold
  let dataLen = md.width * md.height * md.bytesPerPixel
  result = Raster(data: newSeqUninitialized[byte](dataLen),
                  interleave: interleave,
                  meta: md)



proc initRaster*(width, height, bandCount: int, 
                 interleave: Interleave, 
                 bandDataType: RasterDataType): Raster =
  ## Create a blank raster.  At the return of this call, the raster is able
  ## to have the `rasterData` field assigned to.
  runnableExamples:
    let rgbRaster = initRaster(256, 256, 3, BIP, int8)
    for i in countUp(0, 256, step = 3):
      rgbRaster.rasterData[i] = i
      rgbRaster.rasterData[i + 1] = i
      rgbRaster.rasterData[i + 2] = i
  
  # metadata
  var md = initRasterMetadata(width, height, bandCount, bandDataType)

  result = initRaster(md, interleave)
  #let rasterDataSize = (width * height * bytesPerPixel).uint
  #var raster = Raster(rasterDataSize: rasterDataSize)
  #raster.rasterData = createU(byte, rasterDataSize) # dealloced in destructor   #TODO: UnsafeSeq[byte]?
  #raster.interleave = interleave


func getBandColours(hDs: Dataset) : seq[BandColour] = 
  ## retrieve the band colours from the GDAL dataset
  let numBands = GDALGetRasterCount(hDs)
  var bandColours = newSeq[BandColour](numBands)

  for b in 1..numBands:
    let hRb = GDALGetRasterBand(hDs, b)
    bandColours[b - 1] = GDALGetRasterColorInterpretation(hRb)

  return bandColours


proc readRasterMetadata*(map: Map): RasterMetadata =
  ## Read the metadata of a raster without loading the raster itself
  let width = getRasterXSize(map.dataset)
  let height = getRasterYSize(map.dataset)
  let bandCount = GDALGetRasterCount(map.dataset)
  let (bitsPerPixel, bytesPerPixel, bandDataType) = 
    calcBitsBytesPerPixelAndDataType(map)
  
  result = initRasterMetadata(width, height, bandCount, bandDataType)
  result.bandColours = getBandColours(map.dataset)



proc readRaster*(map: Map, 
                interleave: Interleave = BIP, 
                x, y, width, height: int = 0,
                bands: openarray[ValidBandOrdinal]): Raster = 
  ## Read a raster of a Map into memory.  It is stored in the format defined
  ## by `interleave` in left-to-right, top-to-bottom order.  Bands are
  ## in the same order as the image and you may use the returned rasters
  ## `meta.bandColours` field to determine
  ## the colour components each band represents and the order of them.
  ## 
  ## If the Map has no raster data, a ValueError is thrown.
  ## 
  ## To read only a portion of a raster, specify the rectangle to read by 
  ## passing `x`, `y`, `width`, and `height` pixel coordinates of the rectangle.
  ## For most efficient partial reads, `x`, and `y` should be aligned
  ## on block boundaries and `width` and `height` should be the size of the
  ## block.  This information can be obtained by calling `blockInfo`_ . If `x`,
  ## `y`, `width`, and `height` are out of the boundaries of the image, 
  ## IOError is raised.
  ## 
  ## If `bands` is empty, all bands are read. Otherwise the bands given in
  ## `bands` will be read.  Bands start from 1.  A ValueError is thrown if
  ## more bands are given than in the raster.
  ## 
  ## **Images with different band bit lengths**
  ## 
  ## Each band in
  ## the raster will be of the same data type and size.  This means that formats
  ## with bands of different band bit lengths will use the most suitable bit
  ## length. E.g. RGB565 format (5 bits red, 6 bits green, 5 bits blue), common
  ## in embedded systems and cameras, will become 24 bits per pixel instead of
  ## 16 bits per pixel.
  ## 
  
  # CxHxW of (3,1,1) [c][w][h] = c + w * CHANNEL + (h * CHANNEL * WIDTH)
  # => 3 + 1 * 4 + (1 * 4 * 3)
  # => 3 + 4 + 12
  # => 19
  # = 11

  let md = map.readRasterMetadata()
  
  if md.numBands <= 0:
    raise newException(ValueError, "Map contains no raster");

  result = initRaster(md, interleave)

  # read all bands or just the ones given?
  var readBands: seq[cint]
  if bands.len == 0:
    readBands = newSeq[cint](md.numBands)
    for b in 1..md.numBands:
      readBands[b - 1] = b.cint
  else:
    for b in 0 ..< bands.len:
      readBands[b] = b.cint

  # control how interleaving is done
  var nPixelSpace, nLineSpace, nBandSpace: cint
  case interleave
  of BSQ:
    nPixelSpace = 0 # GDAL default
    nLineSpace = 0  # GDAL default
    nBandSpace = 0  # GDAL default
  of BIP:
    nPixelSpace = md.bytesPerPixel.cint
    nLineSpace = (md.bytesPerPixel * md.width).cint
    nBandSpace = bytesForDataType(md.bandDataType).cint
  of BIL:
    nPixelSpace = bytesForDataType(md.bandDataType).cint
    nLineSpace = (md.bytesPerPixel.cint * md.width).cint
    nBandSpace = nPixelSpace
  
  # read entire image or just width and height as specified
  var readWidth = width
  var readHeight = height
  if width == 0: readWidth = md.width
  if height == 0: readHeight = md.height

  # read into memory in requested interleaving
  let success = GDALDatasetRasterIOEx(
                map.dataset,
                GF_Read,
                x.cint,
                y.cint,
                readWidth.cint, readHeight.cint, # width, height
                result.data[0].addr,     # data is read into this memory
                readWidth.cint, readHeight.cint, # 1:1 (no overviews/scaling)
                md.bandDataType,    # target data type of a individual band value
                md.numBands.cint,   # number of bands to read 
                readBands[0].addr,  # bands to read
                nPixelSpace,        # bytes from one pixel to the next pixel in 
                                    # the scanline = dt (i.e. pixel interleaved)
                nLineSpace,         # bytes from start of one scanline to the
                                    # next = dt * nBufXSize (i.e pixel interleaved)
                nBandSpace,
                nil)                # TODO: progress callback
  if success != CE_None:
    raise newException(IOError, $CPLGetLastErrorMsg())


proc readRaster*(map: Map, 
                interleave: Interleave = BIP, 
                bands: openarray[ValidBandOrdinal]): Raster = 
  ## Read a raster of a Map into memory.  It is stored in the format defined
  ## by `interleave` in left-to-right, top-to-bottom order.  Bands are
  ## in the same order as the image and you may use the returned rasters
  ## `meta.bandColours` field to determine
  ## the colour components each band represents and the order of them.
  ## 
  ## If the Map has no raster data, a ValueError is thrown.
  ## 
  ## If `bands` is empty, all bands are read. Otherwise the bands given in
  ## `bands` will be read.  Bands start from 1.  A ValueError is thrown if
  ## more bands are given than in the raster.
  ## 
  ## **Images with different band bit lengths**
  ## 
  ## Each band in
  ## the raster will be of the same data type and size.  This means that formats
  ## with bands of different band bit lengths will use the most suitable bit
  ## length. E.g. RGB565 format (5 bits red, 6 bits green, 5 bits blue), common
  ## in embedded systems and cameras, will become 24 bits per pixel instead of
  ## 16 bits per pixel.
  readRaster(map, interleave, 0, 0, 0, 0, bands)
  
proc readBand*(map: Map,
              bandOrdinal: ValidBandOrdinal,
              x: int = 0, 
              y: int = 0, 
              width: int = 0, 
              height: int = 0) : Raster =
  ## Read a single band of a raster into memory.
  ## 
  ## To read only a portion of a band, specify the rectangle to read by 
  ## passing `x`, `y`, `width`, and `height` pixel coordinates of the rectangle.
  ## For most efficient partial reads, `x`, and `y` should be aligned
  ## on block boundaries and `width` and `height` should be the size of the
  ## block.  This information can be obtained by calling `blockInfo`_ . If `x`,
  ## `y`, `width`, and `height` are out of the boundaries of the image, 
  ## IOError is raised.
  ## 
  ## If the Map has no raster data, a ValueError is raised.
  ## 
  ## A ValueError is raised if `bandOrdinal` does not exist.
  ## 
  ## **Images with different band bit lengths**
  ## 
  ## Each band in
  ## the raster will be of the same data type and size.  This means that formats
  ## with bands of different band bit lengths will use the most suitable bit
  ## length. E.g. RGB565 format (5 bits red, 6 bits green, 5 bits blue), common
  ## in embedded systems and cameras, will become 24 bits per pixel instead of
  ## 16 bits per pixel.
  readRaster(map, BIP, x, y, width, height, @[bandOrdinal])
  


proc blockInfo*(map: Map) : BlockInfo =
  ## Return the number of blocks horizontally and vertically in the maps
  ## raster and their size.
  ## A block is the most efficient size to read and is determined by the
  ## driver.  If the image is tiled, it is normally the size of a tile. 
  ## Otherwise it is normally a scanline.  
  ## 
  ## Note that blocks do not have to divide the image evenly which means
  ## that the right and bottom blocks may be incomplete.
  let dataset = map.dataset
  let band = GDALGetRasterBand(dataset, 1) # count blocks in the first band
  var blockXSize, blockYSize: int  
  GDALGetBlockSize(
      band,
      cast[ptr cint](blockXSize.unsafeAddr),
      cast[ptr cint](blockYSize.unsafeAddr)
  )
  let metadata = map.readRasterMetadata()
  let numXBlocks:int = int( (metadata.width + blockXSize - 1) / blockXSize)
  let numYBlocks:int = int( (metadata.height + blockYSize - 1) / blockYSize)
  
  var blocks: BlockInfo
  blocks.xBlockCount = numXBlocks
  blocks.yBlockCount = numYBlocks
  blocks.xPixels = blockXSize
  blocks.yPixels = blockYSize

  return blocks




  
#proc main(): void = 
  #var map = open("/Users/nozza/Downloads/gdal-2.4.4/autotest/gdrivers/data/wcs/ArcGIS-1.0.0-scaled.tiff")
  #var map = open("chart-nz-5612-napier-roads.jpg")
  #var map = open("DSM_AZ31_1026_2013.tif")
  #var map = open("0703622w_332603s_20200624T090349Z_dtm.tif")
  #var map = open("/Users/nozza/rgb565.bmp") # none
  #var map = open("/Users/nozza/Downloads/gdal-2.4.4/autotest/gcore/data/1bit_2bands.tif") # none
  #var map = open("/Users/nozza/nakedbrix-analyser/analyse/src/test/resources/16BitDepthMonoChannel.tiff") #none
  #let raster = map.readRaster(BIP)
  #echo fmt"BandDataType: {raster.metadata.bandDataType}, bpp: {raster.metadata.bitsPerPixel}"
  #echo "Read"



#main()