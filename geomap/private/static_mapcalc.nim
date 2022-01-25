## Arithmetic calculations on Maps. 

import ../geomap, ../raster, static_memcalc, expressions, anyitems
import tables, sets, macros, strformat

proc commonBlockInfo(rasterMaps: TableRef[ImageIdType, Map], blockInfo: var BlockInfo) : bool = 
  ## Do raster maps have the same block size?  
  ## If so, populate `blockInfo` and return `true`. If not, `blockInfo` will be 
  ## populated with the dimensions of a scanline and `false` is returned.
  var commonBlockInfo = blockInfo(rasterMaps.getAnyValue())
  
  result = true

  # check for different block sizes in maps
  for rasterMap in rasterMaps.values():
    let blockInfo = rasterMap.blockInfo()
    if blockInfo != commonBlockInfo:
      # default to a scanline
      let md = rasterMap.readRasterMetadata()
      commonBlockInfo.xBlockCount = 1
      commonBlockInfo.yBlockCount = md.height
      commonBlockInfo.xPixels = md.width
      commonBlockInfo.yPixels = 1
      result = false
      break

  blockInfo = commonBlockInfo



proc readBlock[T](x, y: int, 
                  blockInfo: BlockInfo, 
                  map: Map,
                  bandOrd: ValidBandOrdinal) :
                  seq[T] =
  ## Read the `x`th horizontal and `y`th vertical block of a band in a map.  
  ## The block to read is identified as the `x`th horizontal and `y`th vertical 
  ## block in the rasters grid of blocks.  I.e. these are not pixel coordinates. 
  ## The top-left block is 0,0.
  ## 
  ## The block sizes must be the same for all rasters.  
  ## This can be determined by calling `commonBlockInfo`.
  ## 
  ## `blockInfo` gives the size of the block in pixels to read.  If the block
  ## is larger than the image bounds, only the image bounds are read.
  ## 
  ## T is band data type 

  # don't read beyond boundaries of band
  let meta = map.readRasterMetadata()
  let x = x * blockInfo.xPixels
  let y = y * blockInfo.yPixels
  var width = blockInfo.xPixels
  if x + width > meta.width:  
    width = meta.width - x
  var height = blockInfo.yPixels
  if y + height > meta.height:
    height = meta.height - y
  
  # use RasterIO and not GDALReadBlock, as we can't tell if the maps
  # have the same block size, which is why we asked for the block size.
  let band = readBand(map, 
                      bandOrd, 
                      x, 
                      y, 
                      width, 
                      height)
  return cast[seq[T]](band.data)
    


#macro castRasterData(ident: untyped, raster: Raster, bandDataType: static[RasterDataType]) =
macro castRasterData(raster: Raster, bandDataType: static[RasterDataType]) =
  ## var `ident` = cast[seq[`bandDataType`]](`raster`.data) (no copy)
  
  let dataTypeStr = bandDataType.toNimTypeStr()
  result = newStmtList(
    #newVarStmt(ident,
      newNimNode(nnkCast).add(
        newNimNode(nnkBracketExpr).add(
          ident "seq",
          ident dataTypeStr
        ),
        newDotExpr(ident raster.strVal, ident "data")
      )
    #)
  )


template calcBlock(expression: static[string],
                   x,y: int, 
                   blockInfo: BlockInfo, 
                   maps: TableRef[ImageIdType, Map],
                   varIdents: HashSet[string],
                   T: typedesc,
                   dst: var Raster) = #var openarray[D]) = 
  ## Calculate on block `x`,`y` of bands in `maps`, with each band having 
  ## type T and store the result in `dst`  
  
  var vectors =  initTable[string, seq[T]]()
  
  # read blocks for each variable
  for varIdent in varIdents.items():
   
    # load vectors with the band data
    let varInfo = parseImageAndBandId(varIdent)
    let map = maps[varInfo.imageId]
    vectors[varIdent] = readBlock[T](x, y, blockInfo, map, varInfo.bandOrd)
  
  # compute the calculation for the block
  evaluateScalar(expression, vectors, cast[seq[uint8]](result.data), offset)
  # increment offset for later (blockInfo may be larger than what is read)
  #offset = offset + vectors[varIdent].len


 


proc staticCalc*(expression: static[string], 
                 maps: TableRef[char, Map], 
                 dt: static[RasterDataType]) : Raster = 
  ## Calculate the result of `expression` referencing one or more Maps. 
  ## The result is stored in `dst` which has type `dt`.  `dt` is required
  ## to be known at compile-time and should match the bandDataType in `dst` or
  ## a RangeError may be raised if data is out of range. `dst` should be large
  ## enough or an `IndexDefect` will be raised.
  ## 
  ## This function will load the rasters in `maps` block by block reducing
  ## memory needed at any one time.
  ## 
  ## The Map instances in `rasterMaps` must contain raster, not vector, data or
  ## a ValueError is raised. All rasters must be the same size or IndexDefect
  ## is raised.  They must have the same datatype.
  ## 
  ## This function is fastest when the rasters are tiled with the same block size,
  ## otherwise the rasters are read line by line.
  ## 
  ## Each variable in `expression` must have a Map in `maps` or a KeyError
  ## is raised.

  if expression.isVector():
    raise newException(ValueError, 
                      "Expected expression to be scalar, but is vector.  " &
                      "Add band ordinals to the variables.")
  
  # Determine the block size common to all rasters - if the rasters do not have
  # the same block sizes, use scanlines
  var blockInfo {.noinit.} : BlockInfo 
  let hasCommonBlocks = commonBlockInfo(maps, blockInfo)

  let varIdents = expression.findVarIdents()
  var offset = 0
  let randomMap = maps.getAnyValue()
  let randomMeta = randomMap.readRasterMetadata()

  # var dstData = cast[seq[`dt`]](dst.data) so dst.data can be used by
  # evaluateScalar
  result = initRaster(randomMeta.width, randomMeta.height, 1, BIP, dt)  
  #castRasterData(dstData, result, dt)
  #castRasterData(result.data, dt)

  # calc block by block, one block at a time.  We pass this to a template
  # so to avoid repeating ourselves as their are different types.
  for x in 0 ..< blockInfo.xBlockCount:
      for y in 0 ..< blockInfo.yBlockCount:
        case randomMeta.bandDataType:
        of i8: 
          calcBlock(expression, x, y, blockInfo, maps, varIdents, int8, result)
        of u8: 
          calcBlock(expression, x, y, blockInfo, maps, varIdents, uint8, result)
        of i16: 
          calcBlock(expression, x, y, blockInfo, maps, varIdents, int16, result)
        of u16: 
          calcBlock(expression, x, y, blockInfo, maps, varIdents, uint16, result)
        of i32: 
          calcBlock(expression, x, y, blockInfo, maps, varIdents, int32, result)
        of u32: 
          calcBlock(expression, x, y, blockInfo, maps, varIdents, uint32, result)
        of f32: 
          calcBlock(expression, x, y, blockInfo, maps, varIdents, float32, result)
        of f64: 
          calcBlock(expression, x, y, blockInfo, maps, varIdents, float64, result)
        of none: 
          raise newException(ValueError, "data type `none` unsupported")
