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
import geomap, raster, private/[static_mapcalc, expressions]
import std/tables, std/sets, std/strformat


proc calc*(expression: static[string], 
          maps: TableRef[char, Map], 
          dt: static[RasterDataType]): Raster  = 
  ## Calculate the result of a scalar `expression` referencing one or more Maps. 
  ## This function, loads the rasters of each `Map` block by block reducing
  ## memory requirements.  
  ## 
  ## `maps` values contain the instances of each `Map` used in `expression`. The
  ## key for each `Map` is the image id used in `expression`.  E.g. 
  ## `A1 + B1` requires `maps` to have keys of `A` and `B`.  If a variable has
  ## no corresponding map, a `KeyError` will be raised.
  ## 
  ## The `Map` instances must contain raster, not vector, data or
  ## a ValueError is raised. All rasters must be the same size or IndexDefect
  ## is raised.  They must have the same datatype.
  
  return staticCalc(expression, maps, dt)

proc calc*(map: Map, expression: static[string], dt: static[RasterDataType]): Raster = 

  let varIdents = findVarIdents(expression)
  let varCount = varIdents.len
  if varCount > 1:
    raise newException(ValueError,  "Expected only 1 variable in expression, not {varCount}")
  let anyVarIdent = varIdents.getAnyValue()
  let imageId = parseImageId(anyVarIdent)
  let maps = {imageId: map}.newTable()
  return calc(expression, maps, dt)
