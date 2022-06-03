## Band calculations, such as calculating a spectral index.
## 
## Calculations work on expressions, using variables `x`,`y`,`z` for bands 1,
## 2, and 3 respectively.  Only the first three bands of a raster can be
## used in an expression.
## 
## Use `calc1` when using 1 variable, `calc2` when 2, and `calc3` when 3 
## variables.
## 
## e.g.
## 
## ```
## # For each pixel in src, multiply the first band by two and subtract the
## second band, storing the result as 1 band in dst.
## let dst = src.calc2[:byte, byte]((2 * x) - y)   
## 
## # You can change data types.  This creates an  NDVI index if band 1
## # is red and band2 is NIR.  Assume src is type Tensor[byte]. 
## let dst = src.calc2[:byte, float32](y - x / y + x) # dst is Tensor[float32]
## 
## # You can calculate an expression in-place
## src.calc1(x div 2)  # src is modified 
## 
## # You can use anything that's a legal nim expression
## # except library functions other than system
## src.calc1:
##  if x <= 100:
##    1
##  else:
##    0
## 
## ```
## 
## The usual rules of signed and unsigned arithmetic apply when the calculated
## value is out of range of the values the type can handle:
## - unsigned integers will wrap around 
## - signed integers will raise a `OverflowDefect` 
## 
## This means you may have to convert types as appropriate.  For example
## on a Tensor[byte] the expression `(x + y) div 2` for the values x= 200, y = 200
## does not equal 200 but 72 as x + y = 144, since unsigned integers wrap around.
## The solution is to convert the types so `byte((x.integer + y.integer) div 2)`  

import common/[raster]
import arraymancer
import std/[macros]

#
# NB: Nim does not support template overloading when variables are injected
#     so templates must have different names



template calc3*[S,D](src: Tensor[S], `expr`: untyped) : Tensor[D] =
  ## Calculate `expr` on each pixel in `src` and return the result in `dst`.
  ##
  ## `expr` may contain the following variables that are injected into scope:
  ## - `x` for the first band in `src`
  ## - `y` for the second band in `src`
  ## - `z` for the third band in `src`
  ## 
  ## `ValueError` is raised if `src` contains less than 3 bands.  
  ## 
  ## `dst` will be a 2D tensor with the result.
  ## 
  ## The destination type may be different than the source type. This is useful
  ## if the expression will expand the data size needed.
  block:
    var dst = newTensorUninit[D](src.shape[0], src.shape[1], 1)
    if src.bandCount() < 3:
      raise newException(ValueError, "calc3 requires at least 3 bands")
    else:
      let band1 = src[_, _, 0].astype(type(D))
      let band2 = src[_, _, 1].astype(type(D))
      let band3 = src[_, _, 2].astype(type(D))
      dst = map3_inline(band1, band2, band3):
        `expr`
    dst
      



template calc2*[S,D](src: Tensor[S], `expr`: untyped) : Tensor[D] =
  ## Calculate `expr` on each pixel in `src` and return the result in `dst`.
  ##
  ## `expr` may contain the following variables that are injected into scope:
  ## - `x` for the first band in `src`
  ## - `y` for the second band in `src`
  ## 
  ## `ValueError` is raised if `src` contains less than 2 bands.  
  ## 
  ## `dst` will be a 2D tensor with the result.
  ## 
  ## The destination type may be different than the source type. This is useful
  ## if the expression will expand the data size needed.
  block:
    var dst = newTensorUninit[D](src.shape[0], src.shape[1], 1)
    if src.bandCount() < 2:
      raise newException(ValueError, "calc2 requires at least 2 bands")
    else:
      let band1 = src[_, _, 0].astype(type(D))
      let band2 = src[_, _, 1].astype(type(D))
      dst = map2_inline(band1, band2):
        `expr`
    dst
      

template calc1*[S,D](src: Tensor[S], `expr`: untyped) : Tensor[D] =
  ## Calculate `expr` on each pixel in `src`. The result is stored in
  ## the first band.
  ##
  ## `expr` may contain the following variables that are injected into scope:
  ## - `x` for the first band in `src`
  ## 
  ## `ValueError` is raised if `src` contains less than 1 band.  
  ## 
  ## `dst` will be a 2D tensor with the result.
  ## 
  ## The destination type may be different than the source type. This is useful
  ## if the expression will expand the data size needed.
  block:
    var dst = newTensorUninit[D](src.shape[0], src.shape[1], 1)
    if src.bandCount() < 1:
      raise newException(ValueError, "calc1 requires at least 1 band")
    else:
      let band1 = src[_, _, 0].astype(type(D))
      dst = map_inline(band1):
        `expr`
    dst



template calcInPlace3*[T](raster: var Tensor[T], `expr`: untyped) =
  ## Calculate `expr` on each pixel in `src`The result is stored in
  ## the first band.
  ## 
  ## `expr` may contain the following variables that are injected into scope:
  ## - `x` for the first band in `src`
  ## - `y` for the second band in `src`
  ## - `z` for the third band in `src`
  ## 
  ## `ValueError` is raised if `src` contains less than 3 bands.  
  
  if raster.bandCount() < 3:
    raise newException(ValueError, "calc3 requires at least 3 bands")
  else:
    var band1:Tensor[T] = raster[_, _, 0]
    var band2:Tensor[T] = raster[_, _, 1]
    var band3:Tensor[T] = raster[_, _, 2]
    apply3_inline(band1, band2, band3):
      `expr`



template calcInPlace2*[T](raster: var Tensor[T], `expr`: untyped) =
  ## Calculate `expr` on each pixel in `src`.  The result is stored in
  ## the first band.
  ## 
  ## `expr` may contain the following variables that are injected into scope:
  ## - `x` for the first band in `src`
  ## - `y` for the second band in `src`
  ## 
  ## `ValueError` is raised if `src` contains less than 3 bands.  
  
  if raster.bandCount() < 2:
    raise newException(ValueError, "calc2 requires at least 2 bands")
  else:
    var band1 = raster[_, _, 0]
    var band2 = raster[_, _, 1]
    apply2_inline(band1, band2):
      `expr`





template calcInPlace1*[T](raster: var Tensor[T], `expr`: untyped) =
  ## Calculate `expr` on each pixel in `src`, modifying the pixel in place.
  ## 
  ## `expr` may contain the following variables that are injected into scope:
  ## - `x` for the first band in `src`
  ## 
  ## `ValueError` is raised if `src` contains less than 1 band.  
  
  if raster.bandCount() < 1:
    raise newException(ValueError, "calc1 requires at least 1 band")
  apply_inline(raster):
      `expr`