## Calculations on rasters, e.g. NDVI.
##
## Calculations must be provided at compile time by referencing one of the
## `calc` procedures which require an expression to evaluate. There are 
## overloaded `calc`procedures for convenience varying by:
## 
## - raster interleaving type (e.g. BSQ, BIP)
## - whether one band of data (scalar) is generated or multiple bands (vector)
## - whether the destination of the data is new or in-place (destination = source)
## 
## Expressions
## -----------
## An expression is an algebraic nim  statement that is run on every pixel
## in a `Map` or `Raster`.  The expression references image data with variables
## of the form: `[A..Z][1..65536]` where:
## -  a letter A-Z references an image
## -  an integer in the range 1-65536 references a band in the image,
## or if missing, all bands
## 
## e.g.
## - `A2`is the second band in the first image
## - `B10`is the tenth band in the second image
## - `B`is all bands in the second image
## 
## Nim functions other than algebraic operators available in the `system`
## module should not be used.
##
## Scalar and Vector expressions
## -----------------------------
## Scalar expressions produce one result per data element in `src`. E.g.
## the expression `A1 + B1` is a scalar expression.  
## 
## Vector expressions produce multiple results per data element in `src` because
## the same expression operates on multiple bands.  E.g. the expression
## `A div 2` operates on all bands in `A`.
## Example expressions:
## 
## - `C1 = A1 - B1 / A1 + B1` calculates the result of the first bands from two
## different images and stores the result in the first band of the third image
## - `B1 = A2 - A1 / A2 + A1 - A3` refers to three bands in only one image and
## stores the result in the first band of the second image
## - `A = 10 * (A / 10)` 

# TODO: run-time supplied calculations (import mathexpr)
# TODO: add multithreading
# TODO: optimise method for BIP formats (faster IO for different drivers?)
# TODO: use SIMD instructions
# TODO: handle Regions of Interest
# TODO: support for NoData


import geomap, calctypes, calcexpr, gdal/gdal
import tables, algorithm, macros, typetraits


type
    Progress* = concept p
        p.progress is uint8
    
    NoProgress = object
        progress: uint8

  
converter toBandOrd*(o: int): BandOrd =
    ## convert integer to BandOrd
    let max_int16: int = int high(uint16)
    if o < 1 or o > max_int16:
        raise newException(ValueError, "Band Ordinals range 1 .. 65536 but got {o}")
    return uint16 o

proc BSQBand*[T](bandOrd: int, data: seq[T]) : Table[BandOrd, seq[T]] = 
  ## create a new BSQBand
  let t = [(toBandOrd(bandOrd), data)].toTable()
  return t

proc band*[T](data: openarray[(int, seq[T])]) : Table[BandOrd, seq[T]] =
  result = initTable[BandOrd, seq[T]](data.len)
  for (bandOrd, bandData) in data:
    result[toBandOrd(bandOrd)] = bandData
  return result

type
  BlockInfo = object
    xBlocks*: int
    yBlocks*: int
    xSize*: int
    ySize*: int

func countBands(data: BSQData) : seq[int] {.inline.} =
  ## Return the number of bands for each image in `data`
  var counts = newSeq[int](data.len)
  for imageId, bandData in data.pairs:
    let imageOrd = int(imageId) - 65  # 'A' - 65 = 0
    counts[imageOrd] = bandData.len
  
  return counts



macro calc*(
  `expr`: static[string],
  bandCounts: static seq[int], # only needed if image with no bands included
  src: BSQData,
  dst: var seq[var seq],
  srcType: static[string],
  dstType: static[string]) : untyped = 
  ## Evaluate `expr` on band data in `src` and store the result in `dst`. This
  ## operates on Band Sequential Data where each band is in a different sequence.
  ## Because this is a macro, the expression and image band counts must be known
  ## at compile-time.
  ## 
  ## Scalar and Vector expressions
  ## -----------------------------
  ## Scalar expressions produce one result per data element in `src`. E.g.
  ## the expression `A1 + B1` is a scalar expression.  For scalar expressions
  ## `dst` must have one sequence (i.e. dst.len == 1)
  ## 
  ## Vector expressions produce multiple results per data element in `src` because
  ## the same expression operates on multiple bands.  E.g. the expression
  ## `A div 2` operates on all bands in `A` and produces one result per band.
  ## For vector expressions `dst`must have a sequence for each band in A 
  ## (i.e. dst.len == number of bands in src)
  ## 
  ## Vector expressions that have multiple source images (e.g. `A + B` must
  ## have the same number of bands and this must be the same as `dst.len`)
  ## 
  ## Vector expressions require `bandCounts` to be specified, otherwise there
  ## is no way of knowing at compile-time, how many bands are in the source
  ## images.
  ## 
  ## Destination data types
  ## ----------------------
  ## Elements in `src` are read as type `srcType`, and the result is stored in 
  ## `dst` as type `dstType`.  `srcType` must match the type `S`in `BSQData[S]`
  ## and `dstType`must match the type `D`in `seq[D]`of `dst`. 
  ## The results are casted, not converted. It is your responsibility to ensure
  ## the result of evaluating `expr` will fit in `dstType`.
  ## 
  ## 
  ## In-place or new destinations
  ## ----------------------------
  ## `dst`does not have to be a new sequence, but can reference a sequence in
  ## `src`.
  ## 
  ## Troubleshooting:
  ## 
  ## - Compile error _Error: type mismatch: got <int> but expected 'uint16'_ : either
  ## `srcType`does not match the type `S` in `BSQData[S]` or `dstType`does
  ## not match the type `D`in `var seq[D]`.
  ## 
  ## - Runtime error _Unhandled exception: index 3 not in 0 .. 2 [IndexDefect]_:
  ## `dst.len`is greater than the length of the bands (or at least one band)
  ## data in `src`.
  
   
  # TODO: allow this to be called multiple times for the same expression so you
  # can use WriteBlock instead of RasterIO

  let bindings = bindToBands(`expr`, bandCounts)
  result = newStmtList()

  # Example of resulting statements
  #
  # 1: var 
  # 2:   A1, B2:S        # sources
  # 3:   imageId: char
  # 4:   bandOrd: uint16
  # 5:   
  # 6: for pixelIx in 0..(dst[0].len - 1):   # for each pixel
  # 7:  
  # 8:   imageId = 'A'
  # 9:   bandOrd = 1
  # 10:  A1 = src[imageId][bandOrd][pixelIx]
  #   
  # 11:  imageId = 'B'
  # 12:  bandOrd = 2
  # 13:  B2 = src[imageId][bandOrd][pixelIx]      
  # 
  # 14:  for dstBandOrd in 0 ..< dst.len:  # TODO: does compiler unroll? should we have a case for countDstBands = 1 (the most common case)
  # 15:    dst[dstBandOrd][pixelIx] = cast[D](A1 + B2)

  ## TODO: compile-time check there's same number of destination bands as "A" needs if expanded
  ## TODO: compile-time check all destination bands are of the same size
  ## TODO: compile-time check all source bands are of the same size and same as destination
  ## TODO: compile-time expect dst[0].len is valid - i.e. dst is a seq of seq
  
  # 1: variable declarations
  var varSection = newNimNode(nnkVarSection)
  result.add varSection

  # 2: band variables, var A1..Z65535: S
  for variable in bindings.variables():
    varSection.add newIdentDefs(ident variable.ident, ident srcType)
  
  # 3: var imageId = 
  let imageIdIdent = ident "imageId"
  varSection.add newIdentDefs(imageIdIdent, ident "char")
  
  # 4: var bandOrd =
  let bandOrdIdent = ident "bandOrd"
  varSection.add newIdentDefs(bandOrdIdent, ident "uint16")

  # 6: for pixelIx in 0..(dst[0].len - 1)
  var forEachPixelStmt = newNimNode(nnkForStmt)
  let pixelIxIdent = ident "pixelIx"
  forEachPixelStmt.add pixelIxIdent

  var dst0 = newNimNode(nnkBracketExpr)
  dst0.add dst
  dst0.add newLit(0)

  var dst0LenNode = newDotExpr(dst0, ident "len") 
  var dstLenMinus1Node = infix(dst0LenNode, "-", newLit(1))
  var parens = newPar(dstLenMinus1Node)
  var range1 = newNimNode(nnkInfix).add(ident "..").add(newLit 0).add(parens)
  forEachPixelStmt.add range1
  result.add forEachPixelStmt

  # A1, A2, etc. assignment in for statment
  var inForEachPixelLoop = newStmtList()
  for variable in bindings.variables():
    
    # 8, 11: imageId = 
    inForEachPixelLoop.add newAssignment(imageIdIdent, newLit(variable.imageId))  
    
    # 9, 12: bandOrd =
    inForEachPixelLoop.add newAssignment(bandOrdIdent, newLit(variable.bandOrd))  
  
    # 10, 13: A1 = src[imageId][bandOrd][pixelIx]
    var bandDataNode = newNimNode(nnkBracketExpr)
    bandDataNode.add(src).add(imageIdIdent)

    var pixelDataNode = newNimNode(nnkBracketExpr)
    pixelDataNode.add(bandDataNode).add(bandOrdIdent)
  
    var pixelIxNode = newNimNode(nnkBracketExpr)
    pixelIxNode.add(pixelDataNode).add(pixelIxIdent)
  
    inForEachPixelLoop.add newAssignment(ident variable.ident, pixelIxNode)

  # 14: for dstBandOrd in 0 ..< dst.len:
  var forEachDstBand = newNimNode(nnkForStmt)
  var dstBandOrd = ident "dstBandOrd"
  forEachDstBand.add dstBandOrd

  var dstLen = newDotExpr(dst, ident "len") # dst.len
  var range2 = newNimNode(nnkInfix).add(ident "..<").add(newLit 0).add(dstLen)

  forEachDstBand.add(range2) # 0 ..< dst.len
  inForEachPixelLoop.add(forEachDstBand)

  # dst[dstBandOrd][pixelIx] = cast[D](A1 + B2)
  var inForEachDstBandLoop = newStmtList()
  let fullExpr = dst.repr & "[dstBandOrd][pixelIx] = cast[" & dstType & "](" & bindings.exprRepr & ")"
  inForEachDstBandLoop.add parseStmt(fullExpr)
  forEachDstBand.add(inForEachDstBandLoop)

  forEachPixelStmt.add(inForEachPixelLoop)

  #echo result.treeRepr



proc calc*[S](
  expression: static[string],
  src: BSQData[S],
  D: typedesc) : seq[D] =
  ## Evaluate `expression` on band data in `src` returning a single band of 
  ## data.  `expression` must be known at compile-time.
  ## 
  ## This operates on **Band Sequential Data** where each band is in a different sequence.
  ## Because this is a macro, the expression and image band counts must be known
  ## at compile-time.
  ## 
  ## `expression` must be a **scalar expression** as this procedure returns only
  ## one band of resulting data.  A ValueError is raised if the expression is
  ## vector.
  ## 
  ## The datatype of the result is defined by `D`.  
  ## The results are casted, not converted. It is your responsibility to ensure
  ## the result of evaluating `expr` will fit in `dstType`.
  
  # check expr is scalar because we only return one band
  if expression.isVector():
    raise newException(ValueError, 
      "Expected expression '" & expression & "' to be scalar but has vector " &
      "variables referencing multiple bands.  Call a different 'calc' procedure " &
      "that supports multiple band results.")
  
  # TODO: generate bandcounts for each image A-Z, 

  var len = 0
  #var bandCounts = newSeq[src.len]
  for bands in src.values():
    for pixels in bands.values():
      len = pixels.len
      break
  
  var dstWrapper = newSeq[seq[D]](1)
  var dst = newSeq[D](len)
  dstWrapper[0] = dst
  calc(expression, @[2], src, dstWrapper, S.name, D.name)
  
  return dstWrapper[0]


proc countBlocks(map: Map) : BlockInfo =
  # Return the number of blocks horizontally and vertically in the maps
  # raster and their size.
  # A block is the most efficient size to read and is determined by the
  # driver.  If the image is tiled, it is normally the size of a tile. 
  # Otherwise it is normally a scanline.
  let hDs = map.dataset()
  let band = GDALGetRasterBand(hDs, 1)
  var blockXSize, blockYSize: int  
  GDALGetBlockSize(
      band,
      cast[ptr cint](blockXSize.unsafeAddr),
      cast[ptr cint](blockYSize.unsafeAddr)
  )
  let numXBlocks:int = int( (map.width + blockXSize - 1) / blockXSize)
  let numYBlocks:int = int( (map.height + blockYSize - 1) / blockYSize)
  
  var blocks: BlockInfo
  blocks.xBlocks = numXBlocks
  blocks.yBlocks = numYBlocks
  blocks.xSize = blockXSize
  blocks.ySize = blockYSize
  return blocks









#proc calc*(raster: Raster, `expr`: string, bandCount: seq[int]) : Raster =
  ## Evaluate `expr` on `raster` and return a new raster.
  ## 
  ## `expr` will be evaluated on each element in `src` `dst.len`times.  That is,
  ## if dst is smaller than any referenced band, only the first part of the
  ## bands will be used.  An IndexError at runtime will occur if the length of
  ## dst is greater than any referenced band in src.
  ## 
  ## Elements in `src` are read as type `srcType`, and the result is stored in 
  ## `dst` as type `dstType`.  `srcType` must match the type `S`in `BSQData[S]`
  ## and `dstType`must match the type `D`in `seq[D]`of `dst`. 
  ## The results are casted, not converted. It is your responsibility to ensure
  ## the result of evaluating `expr` will fit in `dstType`.
  ## 
  ## The `bandCounts`give the number of bands for each image by ordinal (A=0,
  ## B=1, etc).  This must be known at compile time along with the expression.
  ## This is only really needed if the expression contains a variable specifying
  ## all bands.  E.g. "A / 3" needs to expand to "A1 / 3", "A2 / 3", "A3 / 3",
  ## etc.
  ## 
  

#roc calc*(map: Map, `expr`: string, bandCounts: seq[int], progress: Progress = NoProgress) : Raster =
# let blocks = countBlocks(map)
#   
# # what bands are needed to be read in the expression?
# let bindings = bindToBands(`expr`, @[map.numBands])
# let imageId = bindings.imageIds()[0]
#
# var bandsData = initTable[uint16, seq[int]] #TODO: determine int from typedesc
#
# # evaluate expression block by block
# for x in 0..blocks.xBlocks:
#   for y in 0..blocks.yBlocks:
#       
#     for i in 0..bindings.bandOrdinalsFor(0).len:
#         
#       # read band data for each required band    
#       let bandData = newSeq[int](blocks.xSize * blocks.ySize)
#       bandsData[imageId] = bandData
#       let pBandData = bandData.addr
#       GDALReadBlock(i, x, y, pBandData) # TODO: images of non-aligned blocks
# 
#       # evaluate this block
#       let src = {imageId: bandsData}.toTable
#       let dst = newSeq[int](blocks.xSize * blocks.ySize)
#       calc(`expr`, bandCounts, src, dst, "int", "int")
#
#       # TODO: add dst to Map (partial)

            




#func calc*(calc: string, `type`: typedesc, progress: Progress = NoProgress, maps: varargs[Map]) : Map =
# Scalar calulation on multiple Maps, producing an output Map

#func calc*(map: Map, calc: string, progress: Progress = NoProgress) =
# Scalar on all bands in a map, in-place.  Each band will have `calc`
# applied to it, and modified in-place.
# 
# If the value from `calc` would overflow the data type in `Map`, it will
# be truncated. 
# 
# [A-Z] image
# e.g
# "10 * (A / 10)": Pixels in each band of image A will be modified.
# example of colour-space reduction.