## The Raster type, and it's accessors and mutators.  A Raster represents
## one or more bands of the entire raster data or a subset of raster data in
## memory of a `Map`.
## 
## The `data` field contains the raster data as an Arraymancer Tensor, and
## the `interleave` field contains the manner that the bands are interleaved. 
## 
## `import geomap/rastermap` includes this module.

import std/[math, options, tables]
import arraymancer
export arraymancer

# ------------------------------------------------------------------------------
# RasterDataType
# ------------------------------------------------------------------------------
type
  SomeBandType* =  byte | int16 | uint16 | int32 | uint32 | float32 | float64
    ## Allowed data types for band storage.  Complex types used by GDAL are
    ## not supported.
    



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
         ## This interleaving provides best performance for accessing parts of
         ## a single band. 
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
         ## This interleaving provides best performance when reading pixels
         ## containing all band values. 
         ## 
         ## As a 3D array this is of the shape [Bands, X, Y]
         ## 
    
    # BIL unsupported
    #BIL = "BIL", ## Band Interleaved by Line. BIL stores the raster each row at a time.
         # Each row has the band data written one after another. This is the
         # least commonly used manner.
         # 
         # E.g. If there are three bands R, G, and B, in a 2x2 image, BIL
         # stores image data as:
         # 
         # +-------+-------+-------+-------+-------+-------+-------+
         # |       | x = 0 | x = 1 | x = 0 | x = 1 | x = 0 | x = 1 |
         # +=======+=======+=======+=======+=======+=======+=======+
         # | y = 0 |   R   |   R   |   G   |   G   |   B   |   B   |
         # +-------+-------+-------+-------+-------+-------+-------+
         # | y = 1 |   R   |   R   |   G   |   G   |   B   |   B   |
         # +-------+-------+-------+-------+-------+-------+-------+
          


proc height*(raster: Tensor) : int = 
  ## Height of the raster
  result = raster.shape[0]



proc width*(raster: Tensor) : int =
  ## Width of the raster
  result = raster.shape[1]



proc bandCount*(raster: Tensor) : int =
  ## Number of bands in the raster
  if raster.rank == 3:
    result = raster.shape[2]
  else:
    result = 1



proc initRaster*[T: SomeBandType](width, 
                                  height, 
                                  bandCount: int, 
                                  interleave: Interleave): Tensor[T] =
  ## Create a new Raster, with band data of type `T`.  `Raster.data` is
  ## allocated to be used but unitialised so it's full of junk values.
  
  result = newTensorUninit[T](height, width, bandCount)



proc echo*[T](data: seq[T], width: int) =
  ## Writes a sequence to the standard output as a 2d array
  let numOfRows = ceilDiv(data.len, width)
  for row in 0 ..< numOfRows:
    let start = row * width
    let stop = start + width - 1
    echo data[start .. stop]



type 
  ImageIdType* = char
  ImageOrdinalType* = uint8
  BandOrdinalType* = uint16 # because sometimes we need 0 to represent all bands
  ValidBandOrdinal* = range[1'u16 .. high(BandOrdinalType)]
        ## Valid Band Ordinal is the number of the band that ranges 1..65535
