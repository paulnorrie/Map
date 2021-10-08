## Calculations on rasters, e.g. NDVI.
##
## Calculations must be provided at compile time by referencing one of the
## `calc` templates which require an expression to calculate.
## 
## Expressions
## -----------
## 
## An expression is an algebraic nim statement that is run on every pixel
## in a `Map`.  The expression references image data with variables
## of the form: `[A..Z][1..65536]` where:
## -  a letter A-Z is an image
## -  an integer in the range 1-65536 is a band in the image, or if missing, all bands
## 
## e.g.
## - `A2`is the second band in the first image
## - `B10`is the tenth band in the second image
## 
## Nim functions other than algebraic operators available in the `system`
## module should not be used.
## 
## Example expressions:
## 
## - `A1 - B1 / A1 + B1` calculates the result of the first bands from two
## different images
## - `A2 - A1 / A2 + A1 - A3`refers to three bands in only one image
## - `10 * (A / 10)`
    
# TODO: run-time supplied calculations (import mathexpr)
# TODO: add multithreading
# TODO: optimise method for BIP formats (faster IO for different drivers?)
# TODO: use SIMD instructions
# TODO: handle Regions of Interest
# TODO: support for NoData


import calcexpr
import tables, algorithm, macros

type
    Progress* = concept p
        p.progress is uint8
    
    NoProgress = object
        progress: uint8

type 
  ImageIdType = char
  BandOrdinalType = uint16
  BandDataPtr = pointer
  BSQData*[T] = Table[char, Table[uint16, seq[T]]]


func countBands(data: BSQData) : seq[int] {.inline.} =
  ## Return the number of bands for each image in `data`
  var counts = newSeq[int](data.len)
  for imageId, bandData in data.pairs:
    let imageOrd = int(imageId) - 65  # 'A' - 65 = 0
    counts[imageOrd] = bandData.len
  
  return counts


# 1.  Pass to bsqCalc static expression and not ExprInfo.
#     This means bandCounts in bindToBands(expr, bandCounts) must be known at 
#     compile-time and passed statically to bsqCalc.
#
#     E.g. calling bsqCalc:
#       bsqCalc "A + 1", @[3]   (2nd parameter is bandCounts)
#     
# 2.  Pass to bsqCalc the node identifier of BSQData so we know what variable
#     to interrogate. 
#
#     E.g. 
#       let data: BSQData = ....
#       bsqCalc "A1 + B1", @[1, 1], data
#
# 3. Still need to pass dst for dst.len
#
#    E.g.
#       let data: BSQData[float32] = ...
#       var dst:seq[float32] = ...
#       bsqCalc "A1 + B1", @[1, 1], data, dst
#
# 4. Make sure macro doesn't use variables already in scope (pixelIx, A1, imageOrd)
#    This is unlikely but possible

macro bsqCalc*(
  `expr`: static[string],
  bandCounts: static seq[int],
  src: BSQData,
  dst: var seq,
  srcType: static[string],
  dstType: static[string]) : untyped = 
  ## Evaluate `expr` on band `src` and store the result in `dst`.
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
  # var 
  #   A1, B2:S
  #   imageId: char
  #   bandOrd: uint16
  # for pixelIx in 0..(dst.len - 1):
    #  
    # imageId = 'A'
    # bandOrd = 1
    # A1 = src[imageId][bandOrd][pixelIx]
    #  
    # imageId = 'B'
    # bandOrd = 2
    # B2 = src[imageId][bandOrd][pixelIx]      
    # 
    # dst[pixelIx] = cast[D](A1 + B2)

  # variable declarations
  var varSection = newNimNode(nnkVarSection)
  result.add varSection

  # band variables, var A1..Z65535: S
  for variable in bindings.variables():
    varSection.add newIdentDefs(ident variable.ident, ident srcType)
  
  # var imageId = 
  let imageIdIdent = ident "imageId"
  varSection.add newIdentDefs(imageIdIdent, ident "char")
  
  # var bandOrd =
  let bandOrdIdent = ident "bandOrd"
  varSection.add newIdentDefs(bandOrdIdent, ident "uint16")

  # for pixelIx in 0..(dst.len - 1)
  var forStmt = newNimNode(nnkForStmt)
  let pixelIxIdent = ident "pixelIx"
  forStmt.add pixelIxIdent
  var dstLenNode = newDotExpr(dst, ident "len")
  var dstLenMinus1Node = infix(dstLenNode, "-", newLit(1))
  var parens = newPar(dstLenMinus1Node)
  var range = newNimNode(nnkInfix).add(ident "..").add(newLit 0).add(parens)
  forStmt.add range
  result.add forStmt

  # A1, A2, etc. assignment in for statment
  var inForLoop = newStmtList()
  inForLoop.add newCall(ident "echo", pixelIxIdent)
  for variable in bindings.variables()[0..^1]:
    
    # imageId = 
    inForLoop.add newAssignment(imageIdIdent, newLit(variable.imageId))  
    
    # bandOrd =
    inForLoop.add newAssignment(bandOrdIdent, newLit(variable.bandOrd))  
  
    # A1 = src[imageId][bandOrd][pixelIx]
    var bandDataNode = newNimNode(nnkBracketExpr)
    bandDataNode.add(src).add(imageIdIdent)

    var pixelDataNode = newNimNode(nnkBracketExpr)
    pixelDataNode.add(bandDataNode).add(bandOrdIdent)
  
    var pixelIxNode = newNimNode(nnkBracketExpr)
    pixelIxNode.add(pixelDataNode).add(pixelIxIdent)
  
    inForLoop.add newAssignment(ident variable.ident, pixelIxNode)
    
  # dst[pixelIx] = cast[D](A1 + B2)
  let fullExpr = "dst[pixelIx] = cast[" & dstType & "](" & bindings.exprRepr & ")"
  inForLoop.add parseStmt(fullExpr)

  forStmt.add(inForLoop)

  #echo result.astGenRepr



#proc numBlocks(map: Map) : (int, int) =
#   # Return the number of blocks horizontally and vertically in the maps
#   # raster.
#   # A block is the most efficient size to read and is determined by the
#   # driver.  If the image is tiled, it is normally the size of a tile. 
#   # Otherwise it is normally a scanline.
#   let hDs = map.dataset()
#   let band = GDALGetRasterBand(hDs, 1)
#   var blockXSize, blockYSize: int  
#   GDALGetBlockSize(
#       band,
#       cast[ptr cint](blockXSize.unsafeAddr),
#       cast[ptr cint](blockYSize.unsafeAddr)
#   )
#   let numXBlocks:int = int( (map.width + blockXSize - 1) / blockXSize)
#   let numYBlocks:int = int( (map.height + blockYSize - 1) / blockYSize)
#   return (numXBlocks, numYBlocks)









#proc calc*(rasterBandsByImage: BSQData, `expr`: string, D: typedesc, progress: Progress = NoProgress) : seq[D] =
    ## Evaluate an expression, `expr`, on raster data in `rasterBandsByImage`.
    ## This returns a sequence representing the result of the type `D.`
    #var dst = newSeq[D](3)
    #let bandCounts = rasterBandsByImage.countBands()
    #let bindings = bindToBands(`expr`, bandCounts) # can't evaluate at compile time because don't have image data
    #bsqCalc `expr`, bandCounts, rasterBandsByImage, dst
    #return dst


#proc calc*(map: Map, `expr`: string, `type`: typedesc, progress: Progress = NoProgress) : Map =
#    ## Scalar calulation on one Map, producing an output Map with one band.
#    ## 
#    ## A `ValueError` is raised if `expr` is invalid.
#     
#    # Get block sizes so we can loop through map efficiently
#    let (numXBlocks, numYBlocks) = numBlocks(map)
#    
#    # what bands are needed to be read in the expression?
#    let exprInfo = bindToBands(`expr`, @[map.numBands]) #getImageAndBandNumbers(`expr`)
#
#    for x in 0..numXBlocks:
#        for y in 0..numYBlocks:
#            var bandsData = newSeq[1, pointer]
#            try:
#                # read band data for each required band    
#                for i in 0..exprInfo.bandOrdinalsFor(0).len():
#                    let size = map.width * map.height * map.bytesPerPixel
#                    let pBandData = createU(byte, size) # for threads createSharedU?
#                    bandsData.add(pBandData)
#                    GDALReadBlock(i, x, y, pBandData) # TODO: images of non-aligned blocks
#            
#                # output is a sequence of datatype
#                bsqCalc `expr`, {'A': bandsData}
#
#            finally:
#                # free memory
#                for i in bandsData:
#                    dealloc(bandsData[i]) # must run in same thread as createShared
            




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