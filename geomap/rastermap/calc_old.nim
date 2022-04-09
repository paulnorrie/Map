## Calculations on rasters, e.g. NDVI.
##
## Calculations must be provided at compile time by referencing one of the
## `calc` procedures which require an expression to evaluate. 
## 
## Expressions
## ===========
## An expression is an algebraic nim statement that is run on every pixel
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
## Nim library functions can be used if imported.
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
import common/raster, private/calc/[static_mapcalc, static_memcalc, expressions]
import std/tables, std/sets, std/monotimes, std/strformat, std/macros

#proc loadRequiredBands[T](map: Map, expression: static[string]) : Table[string, seq[T]] =
#  ## Load the band data needed for `expression` to be evaluated on one map 
#  ## into a table.
#  ## The keys of the table are the variables in `expression`.
#  ## If `expression` contains variables referencing more than one map 
#  ## `ValueError` is raised.
#  
#  let exprInfo = expression.exprInfo()
#
#  let imageCount = exprInfo.imageIds.len
#  if imageCount > 1:
#    raise newException(ValueError, 
#                      fmt"""Expected only 1 image.  
#                            Got {imageCount} in expression: {expression}
#                         """)
#
#  # load the needed bands
#  for variable in exprInfo.variables:
#    let bandNotLoaded = not result.contains(variable.ident)
#    if bandNotLoaded:
#      let rasterBand = readBand[T](map, variable.bandOrd)
#      result[variable.ident] = rasterBand.data



#proc calc*[T](expression: static[string], 
#          maps: TableRef[char, Map]): Raster[T]  = 
#  ## Calculate the result of a scalar `expression` referencing one or more Maps. 
#  ## This function, loads the rasters of each `Map` block by block reducing
#  ## memory requirements.  
#  ## 
#  ## `maps` values contain the instances of each `Map` used in `expression`. The
#  ## key for each `Map` is the image id used in `expression`.  E.g. 
#  ## `A1 + B1` requires `maps` to have keys of `A` and `B`.  If a variable has
#  ## no corresponding map, a `KeyError` will be raised.
#  ## 
#  ## The `Map` instances must contain raster, not vector, data or
#  ## a ValueError is raised. All rasters must be the same size or IndexDefect
#  ## is raised.  They must have the same datatype.
#  
#  return staticCalc[T](expression, maps)



proc calc*[S,D](raster: Raster[S], expression: static[string]) : Raster[D] =
  ## Calculate `expression` on a single raster.  For greatest performance, the
  ## raster should have `BIP` interleaving.
  ## 
  ## The band data type of the source raster, `S`, and the band data type of
  ## the result (destination), `D` must be given.
  ## 
  ## e.g.
  ## 
  ## .. code-block:: Nim
  ##  # using UFCS calling convention:
  ##  let dst = src.calc[:byte, int16]("A1 + 1") 
  ##  # is the same as:  
  ##  let dst = calc[byte, int16](src, "A1 + 1")`
  ## 
  ## Variables must all start with the same letter, and the subsequent number
  ## indicates the band to use.  e.g. "A1 + A3" adds the first and third bands 
  ## together.
  ## 
  ## BIL interleaved rasters are unsupported.
  runnableExamples:
    let map = geomap.open("map.tif")
    let src = map.readRaster(BIP)
    let dst = src.calc[:byte, byte]("A1 + 1")
  
  case raster.interleave
  of BIP:
    # fastest method for multiple bands
    result = initRaster[D](raster.meta.width, raster.meta.height, 1, BIP)
    raster.data.evaluateInterleaved(expression, raster.meta.bandCount, result.data)
  
  #of BSQ:
  #  var vectors: Table[string, seq[S]]
  #  let exprInfo = expression.exprInfo()
  #  let pixelCount = (raster.meta.width * raster.meta.height).uint
  #  for varInfo in exprInfo.variables():
  #    let start = (varInfo.bandOrd - 1) * pixelCount
  #    let stop = start + pixelCount - 1
  #    vectors[varInfo.ident] = raster.data[start..stop]
  #  result = initRaster[D](raster.meta.width, raster.meta.height, 1, BSQ)
  #  vectors.evaluate(expression, result.data)
  else:
    raise newException(ValueError, "BIL interleaving unsupported")
  
