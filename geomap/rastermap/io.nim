
## Open and close a `Map` and read and write raster data to/from it.
## 
## `import geomap/rastermap` includes this module
## 
## Use the `open`, `newMap`, `read` and `write` functions. 

import ../gdal/[gdal, cpl, cpl_string]
import common/[map, raster, srs, xformer] 
import private/gdalutils 
import std/[math, tables, strformat, options]
from std/importutils import privateAccess
import arraymancer

# register all GDAL drivers before this can be used
registerAll()



proc calcBytesPerPixelAndDataType(map: Map): (int, GDALDataType) = 
  ## Calculate the number of bytes required to store a pixel and the data type 
  ## that addresses the a pixel value.  If bands have different data types or 
  ## bit lengths then the smallest data type that fully expresses
  ## all bands is used.
  ## 
  ## Returns a tuple (bytes per pixel, data type).
  
  var bitsPerPixel: int = 0
  var bestDataType: GDALDataType
  let hDs = map.handle

  let bandCount = GDALGetRasterCount(hDs)
  for b in 1..bandCount:
    let hRb = GDALGetRasterBand(hDs, b)
    if hRb.isNil:
      let msg = fmt"Unable to get band  {b} for map {map.path}. {$CPLGetLastErrorMsg()}"
      echo msg
      raise newException(IOError, msg)
    let dt = GDALGetRasterDataType(hRb)
    bitsPerPixel += GDALGetDataTypeSizeBits(dt)
    if b == 1:
      bestDataType = dt
    else:
      bestDataType = GDALDataTypeUnion(dt, bestDataType)

  let bytesPerPixel = ceil(bitsPerPixel / 8).int
  
  let bestDataTypeAsRDT = bestDataType 
  return (bytesPerPixel, bestDataTypeAsRDT);



func bytesForDataType(dt: GDALDataType) : int {.inline.} =
  ## Number of bytes required to store `dt`
  case dt
  of GDT_Byte: return 1
  of GDT_Int16, GDT_UInt16, GDT_CInt16: return 2
  of GDT_Int32, GDT_UInt32, GDT_Float32, GDT_CInt32, GDT_CFloat32: return 4
  of GDT_Float64, GDT_CFloat64: return 8
  of GDT_Unknown, GDT_TypeCount: return 1  # 0 bytes would probably lead to bad things



proc rasterIoSpacingFor(map: Map, interleave: Interleave, width: int) : (cint, cint, cint) =
  ## Get the (nPixelSpace, nLineSpace, nBandSpace) values to use with
  ## GDAL RasterIO for a given interleaving method.
  var nPixelSpace, nLineSpace, nBandSpace: cint
  case interleave
  of BSQ:
    nPixelSpace = 0 # GDAL default
    nLineSpace = 0  # GDAL default
    nBandSpace = 0  # GDAL default
  of BIP:
    let (bytesPerPixel, pixelDt) = map.calcBytesPerPixelAndDataType()
    nPixelSpace = bytesPerPixel.cint
    nLineSpace = (bytesPerPixel * width).cint
    nBandSpace = bytesForDataType(map.bandDataType()).cint
  
  result = (nPixelSpace, nLineSpace, nBandSpace)



proc gdalDataTypeFor[T]() : GDALDataType =
 ## What is the corresponding RasterDataType for generic type `T`.  If there
 ## is no match RasterDataType is `none`.
 result = 
   when T is byte: GDT_Byte
   elif T is int8: GDT_Byte
   elif T is uint16: GDT_UInt16
   elif T is int16: GDT_Int16
   elif T is uint32: GDT_UInt32
   elif T is int32: GDT_Int32
   elif T is float32: GDT_Float32
   elif T is float64: GDT_Float64
   else: GDT_Unknown



# TODO: raster with a geospation Polygon or MultiPolygon Feature



proc read*[T: SomeBandType](map: Map, 
              x, y, width, height: int = 0,
              bands: openarray[ValidBandOrdinal] = @[]): Tensor[T] = 
  ## Read a raster of a Map into memory. The resulting Tensor is of shape
  ## (height, width, band count) therefore `tensor[y, x, band]` will refer to
  ## a pixel.  Note the order **[y, x, band]**, and that **the band dimension
  ## counts from 0**.
  ## 
  ## If there are multiple bands, the band data is interleaved, i.e. 
  ## for a given pixel, the band data is stored contigously in memory as
  ## `band1, band2, band3, band1, band2, band3`.  This provides increased
  ## performance for multiband calculations, such as spatial 
  ## indexes like NDVI` and interoperability with graphics libraries.
  ##  
  ## The raster data will be allocated as type `T` which is the type of a
  ## bands value (not a pixels value).  If the raster to be read is of a 
  ## different data type, the raster will be converted as it is read.  Floating
  ## point rasters represented as integers will be rounded.  If a value in the
  ## raster is larger or smaller than type `T` can hold, the minimum or maximum
  ## of `T` is used.
  ## 
  ## To read only a portion of a raster, specify the rectangle to read by 
  ## passing `x`, `y`, `width`, and `height` pixel coordinates of the rectangle.
  ## For most efficient partial reads, `x`, and `y` should be aligned
  ## on block boundaries and `width` and `height` should be the size of the
  ## block.  This information can be obtained by calling `Map.blockInfo`_ . If `x`,
  ## `y`, `width`, and `height` are out of the boundaries of the image, 
  ## IOError is raised.
  ## 
  ## If `bands` is empty, all bands are read. Otherwise the bands given in
  ## `bands` will be read.  Bands start from 1.  A ValueError is thrown if
  ## more bands are given than in the raster.
  ## 
  ## If the Map has no raster data, a ValueError is thrown.
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
  
  # read all bands or just the ones given?
  var cbands: seq[cint]
  if bands.len == 0:
    let bandCount = map.bandCount()
    cbands = newSeq[cint](bandCount)
    for b in 1..bandCount:
      cbands[b - 1] = b.cint
  else:
    cbands = newSeq[cint](bands.len)
    for b in 0 ..< bands.len:
      cbands[b] = cbands[b].cint  #WRONG
    
  # read entire image or just width and height as specified
  var xSize = width
  var ySize = height
  if width == 0: xSize = map.width()
  if height == 0: ySize = map.height()
  
  # control how interleaving is done
  let interleave = if cbands.len == 1: BSQ 
                   else: BIP
  var (nPixelSpace, nLineSpace, nBandSpace) = rasterIoSpacingFor(map, interleave, xsize)

  # instantiate raster
  result = initRaster[T](xSize, ySize, cbands.len, interleave)
  
  # read into memory with requested interleaving
  let success = GDALDatasetRasterIOEx(
                map.handle,
                GF_Read,
                x.cint, y.cint,         # start reading at x, y offset
                xSize.cint, ySize.cint, # read this width, height
                result.get_data_ptr(),    # data is read into this memory
                xSize.cint, ySize.cint, # scale 1:1 (no overviews/scaling)
                gdalDataTypeFor[T](),         # target data type of a individual band value
                cbands.len.cint,     # number of bands to read 
                cbands[0].addr,      # which bands to read
                nPixelSpace,        # bytes from one pixel to the next pixel in 
                                    # the scanline 
                nLineSpace,         # bytes from start of one scanline to the
                                    # next 
                nBandSpace,         # bytes between bands
                nil)                
  if success != CE_None:
    raise newException(IOError, $CPLGetLastErrorMsg())


  
proc read*[T: SomeBandType](map: Map,
              band: ValidBandOrdinal,
              x, y, width, height: int = 0) : Tensor[T] =
  ## Read a single band of a raster into memory.  `band` starts from 1.
  ## 
  ## The shape of the returned tensor is (height, width)
  ## 
  ## To read only a portion of a band, specify the rectangle to read by 
  ## passing `x`, `y`, `width`, and `height` pixel coordinates of the rectangle.
  ## For most efficient partial reads, `x`, and `y` should be aligned
  ## on block boundaries and `width` and `height` should be the size of the
  ## block.  This information can be obtained by calling `blockInfo`_ . If `x`,
  ## `y`, `width`, and `height` are out of the boundaries of the image, 
  ## IOError is raised.
  ## 
  ## A ValueError is raised if `band` does not exist.
  read[T](map, x, y, width, height, @[band])
  


proc errorIfRasterAndMapSizeDiffers(raster: Tensor, map: Map) =
  ## Raise `ValueError` if raster and map height and width don't match
  let mapXSize = GDALGetRasterXSize(map.handle)
  let mapYSize = GDALGetRasterYSize(map.handle)
  if raster.width() != mapXSize or 
     raster.height() != mapYSize:
     raise newException(ValueError, 
                        fmt"""Unable to write raster with dimensions {raster.width()}, 
                           {raster.height()} to a map expecting dimensions of
                           {mapXSize}, {mapYSize}.""")
  


proc errorIfRasterAndMapBandsDiffer(raster: Tensor, map: Map) =
  ## Raise `ValueError` if raster and map band counts don't match
  let mapBands = GDALGetRasterCount(map.handle)
  if raster.bandCount() != mapBands:
    raise newException(ValueError, 
                       fmt"""Unable to write raster with {raster.bandCount()} 
                          bands to a map expecting {mapBands}""")



proc write*(map: Map, raster: Tensor) {.raises: [IOError, ValueError].} =
  ## Writes `raster` to an open map which must have been opened with a mode
  ## allowing writing or `IOError` is raised.  
  ##
  ## `raster` must contain all the bands to write.  To write just one band,
  ## call `write(Map, Tensor, ValidBandOrdinal)
  ## 
  ## Writing a raster with 
  ## different dimensions, dataype, or number bands raises a `ValueError`.  
  ## Create a new raster map by calling `rastermap.open` and then calling this procedure.
  
  # write the entire image dimenstions
  let x: cint = 0.cint
  let y: cint = 0.cint
  let xSize:cint = raster.width().cint()
  let ySize:cint = raster.height().cint()

  # Don't allow different dimensions or bands because then the maps geotransform
  # will need to change, and most drivers don't let you change number of bands.
  errorIfRasterAndMapSizeDiffers(raster, map)
  errorIfRasterAndMapBandsDiffer(raster, map)

  # how to read the image interleaving
  let interleave = if raster.bandCount() == 1: Interleave.BSQ 
                              else: Interleave.BIP
  
  let nPixelSpace = cint(raster.strides[1])
  let nLineSpace = cint(raster.strides[0])
  let nBandSpace = cint(raster.strides[2])
  
  let success = GDALDatasetRasterIOEx(
                map.handle,
                GF_Write,
                x, y,                   # start writing at x, y offset
                xSize, ySize,           # write this width, height
                raster.get_offset_ptr,    # data is written from this memory
                xSize, ySize,           # scale 1:1 (no overviews/scaling)
                map.bandDataType(),     # target data type of a individual band value
                raster.bandCount().cint,# number of bands to write 
                nil,                    # write all bands
                nPixelSpace,        # bytes from one pixel to the next pixel in 
                                    # the scanline 
                nLineSpace,         # bytes from start of one scanline to the
                                    # next 
                nBandSpace,         # bytes between bands
                nil)   
  if success != CE_None:
    raise newException(IOError, $CPLGetLastErrorMsg())
            



proc write*[T](map: Map, raster: Tensor[T], bandNumber: ValidBandOrdinal) 
  {.raises: [IOError, ValueError].} =
  ## Writes a single band, given by `data` to an open map.  The map must be 
  ## opened with a mode allowing writing or `IOError` is raised.  
  ##
  ## Attempting to write data of a different data type raises a `ValueError`.
  
  # Don't allow different dimensions because then the maps geotransform
  # will need to change
  errorIfRasterAndMapSizeDiffers(raster, map)

  var bandCount = @[cint bandNumber]

  ## write entire dimension
  let x = 0.cint
  let y = 0.cint
  let xSize = raster.width().cint
  let ySize = raster.height().cint

  let nPixelSpace = cint(raster.strides[1])
  let nLineSpace = cint(raster.strides[0])
  let nBandSpace = cint(raster.strides[2])
  
  let success = GDALDatasetRasterIOEx(
                  map.handle,
                  GF_Write,
                  x, y,                   # start writing at (x,y)=(0,0)
                  xSize, ySize,           # write this width, height
                  raster.get_offset_ptr,    # data is written from this memory
                  xSize, ySize,           # scale 1:1 (no overviews/scaling)
                  map.bandDataType(),     # target data type of a individual band value
                  1.cint,                 # number of bands to write 
                  bandCount[0].addr,      # which band to write
                  nPixelSpace,        # bytes from one pixel to the next default
                  nLineSpace,        # bytes between scanlines default
                  nBandSpace,        # bytes between bands default
                  nil)   
  if success != CE_None:
    raise newException(IOError, $CPLGetLastErrorMsg())
  


proc open*(path: string, mode: FileMode = fmRead): Map =
  ## Open an existing geospatial dataset.  
  ## 
  ## `path` is the path/filename/url for a driver to load the file.
  ## Different drivers have different paths, and not all refer to
  ## a file.  For example to open ESRI shape files (.shp, .shx, .dbf)
  ## you can specify the directory all the files are in.
  ## 
  ## By default, the dataset is read-only, unless `mode` is specified as
  ## `fmReadWriteExisting`. If `path` does not exist, it is not created, 
  ## regardless of `mode`.  To create a new map, use 
  ## `<#open(string, MapProfile)>`_ or `<#newMap(MapProfile)>`_
  ## 
  ## Raises an `IOError` if the path could not be opened
  ## by any driver.
  var accessMode = OF_READONLY
  case mode:
  of fmWrite, fmReadWrite, fmReadWriteExisting, fmAppend:
    accessMode = OF_UPDATE
  else:
    discard
  let flags = (OF_VERBOSE_ERROR or OF_SHARED or accessMode).cint

  let hDs = gdal.GDALOpen(path, flags, nil, nil, nil)
  if (hDs.isNil):
    # NB: OF_VERBOSE_ERROR required to get error code
    raise newException(IOError, fmt"Unable to open map '{path}'. {$CPLGetLastErrorMsg()}")
  else:
    privateAccess(result.type)
    result = Map(hDs: hDs, path: path)

  

proc open*(path: string, 
          profile: MapProfile): 
          Map  =
  ## Open an new dataset for writing.
  ## 
  ## `path` is the path/filename/url for a driver to load the file.
  ## Different drivers have different paths, and not all refer to
  ## a file.  For example to open ESRI shape files (.shp, .shx, .dbf)
  ## you can specify the directory all the files are in.
  ## 
  ## `meta` specifies the raster dimensions, number of bands, and datatype.
  ## You will not be able to write rasters of different dimensions, bands, or
  ## data type to the resulting `Map`.
  ## 
  ## `xform`, and `srs` specify the geo transform and spatial reference system
  ## for the resulting `Map`.
  ## 
  ## `options` provides creation options for the new dataset.  Different types
  ## of datasets have different creation options.  See `<https://gdal.org/drivers/raster/index.html>`_.
  ## 
  ## Raises an `IOError` if the path could not be opened
  ## by any driver.
  ## 
  ## See also:
  ## * `<#open(string, FileMode)>`_
  
  # create a mem dataset 
  let hMemDriver = GDALGetDriverByName("MEM")
  let hMemDs = GDALCreate(hMemDriver, 
                          path, 
                          profile.width.cint, 
                          profile.height.cint, 
                          profile.bandCount.cint, 
                          profile.bandDataType, 
                          nil)
  if hMemDs == nil:
    raise newException(IOError, 
          fmt"Unable to create temporary in-memory datasource. {$CPLGetLastErrorMsg()}")

  # set transform
  if profile.xformer.isSome:
    case profile.xformer.get.kind
    of xfAffine:  discard GDALSetGeoTransform(hMemDs, profile.xformer.get.affine[0].addr)
    else:
      close(hMemDs)
      raise newException(ValueError, fmt"Unsupported transform: {profile.xformer.get.kind}")

  # set projection using SRS
  if profile.srs.isSome:
    discard GDALSetSpatialRef(hMemDs, profile.srs.get.handle())

  # convert table to options string
  var gdalOptions: ptr cstring = nil 
  for key, value in profile.options:  
    gdalOptions = CSLSetNameValue( gdalOptions, key.cstring, value.cstring)

  # what's the output driver for the final dataset?
  let driverShortNames = getOutputDriversFor(path)
  if driverShortNames.len == 0:
    raise newException(ValueError, fmt"No driver supports creating dataset at '{path}'.")
  
  # copy mem dataset to final dataset
  let hDriver = GDALGetDriverByName(driverShortNames[0].cstring)
  let hDstDs = GDALCreateCopy(hDriver,
                              path.cstring,
                              hMemDs,0.
                              cint,gdalOptions,
                              nil,
                              nil)
  close(hMemDs)
  if hDstDs == nil:
    raise newException(IOError, fmt"Unable to create dataset at '{path}'. {$CPLGetLastErrorMsg()}")
  else:
    privateAccess(result.type)
    result = Map(hDS: hDstDs, path: path)



proc newMap*(profile: MapProfile) : Map {.raises: [IOError, ValueError].} = 
  ## Create a new in-memory map given the attributes specified in `profile`.
  ## The profile must have `bandDataType` other than `rdtNone`, positive width
  ## height, and bandCount or `ValueError` is raised.
  ## If the map cannot be created in memory, an `IOError` is raised.
  
  if profile.bandCount < 1:
    raise newException(
      ValueError, 
      fmt"Expected bandCount > 0 but was {profile.bandCount}")

  if profile.width < 1 or profile.height < 1:
    raise newException(
      ValueError, 
      fmt"""Expected width and height > 0 but was {profile.width}, and 
            {profile.height} respectively""")

  # create an empty mem dataset 
  let hMemDriver = GDALGetDriverByName("MEM")
  let hMemDs = GDALCreate(hMemDriver, 
                          "", 
                          profile.width.cint, 
                          profile.height.cint, 
                          profile.bandCount.cint, 
                          profile.bandDataType, 
                          nil)
  if hMemDs == nil:
    raise newException(
      IOError, 
      fmt"""Unable to create temporary in-memory datasource. 
            {$CPLGetLastErrorMsg()}""")
  else:
    # set transform
    if profile.xformer.isSome:
      case profile.xformer.get.kind
      of xfAffine:  discard GDALSetGeoTransform(hMemDs, profile.xformer.get.affine[0].addr)
      else:
        close(hMemDs)
        raise newException(ValueError, fmt"Unsupported transform: {profile.xformer.get.kind}")

    # set projection using SRS
    if profile.srs.isSome:
      discard GDALSetSpatialRef(hMemDs, profile.srs.get.handle())

    privateAccess(result.type)
    result = Map(hDS:hMemDs, path:"MEM:")


  

const StdGTiffOptions* = {
  "COMPRESS": "DEFLATE",    # well-supported, good compression, fast decompress
  "NUM_THREADS": "ALL_CPUS",
  }.toTable()
  ## Common GeoTiff options for the `open` procedures when creating a new
  ## dataset.




