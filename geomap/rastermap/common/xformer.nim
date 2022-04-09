## The Xformer type, it's accessors and mutators.  A Xformer converts
## co-ordinates between 2D raster-space (y, x) and the world, e.g. (lat, lon)
## 
## `import geomap/rastermap` includes this module.
## 
## `import geomap/raster_world` module to convert between
## raster and world co-ordinates rather than using this module.

import ../../gdal/[gdal_alg]
import std/[strformat]

# ------------------------------------------------------------------------------
# Xformer
# ------------------------------------------------------------------------------
type 
  XformerKind* = enum # method used to transform raster to world coordinates
    xfNone # there is no transformer
    xfRPC,  # use Rational Polynomial Coefficient 
    xfAffine, # use an affine transformation
    xfGCP # use Ground Control Points
    

  XformerObj* = object 
    ## Transforms between world and raster coordinates.
    # Xformer can be one of XformerKind, and are read-only.
    case kind*: XformerKind
    of xfRPC: rpc*: pointer
    of xfAffine: affine*: array[6, float64]
    of xfGCP: gcp*: pointer
    of xfNone: n: bool # boolean is never used - just a placeholder

  Xformer* = ref XformerObj



proc `=destroy`(this: var XformerObj) =
  case this.kind:
    of xfGCP: 
      GDALDestroyGCPTransformer(this.gcp)
    of xfRPC: 
      GDALDestroyRPCTransformer(this.rpc)
    else : 
      discard



proc `==`*(a, b: Xformer) : bool = 
  if a.kind == b.kind:
    result = case a.kind
    of xfAffine: a.affine == b.affine
    of xfNone: true
    else:
      raise newException(ValueError, fmt"Unsupported xformer of kind '{a.kind}'") 


proc `$`*(xform: Xformer) : string =
  case xform.kind:
  of xfAffine:
    result = $xform.affine
  of xfNone:
    result = "None"
  else:
    raise newException(ValueError, fmt"Unsupported xformer of kind '{xform.kind}'") 

