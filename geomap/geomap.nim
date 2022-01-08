## Everything starts with a map.  It contains raster or vector data.
##
## To start, call `open`_.   You should not create new `Map` objects yourself.
## `Map` objects cannot be copied, e.g.
## 
## ```
## # No point in copy assignments.
## let map1 = geomap.open("/map1.tif")
## let map2 = map1  # Compile Error
## let map2a = geomap.open("/map1.tif") # works
## 
## # use TableRef, not Table
## proc wontWork(maps: Table[int, Map]) =
##   echo "This won't compile"
## 
## proc willWork(maps: TableRef[int, Map) =
##   echo "This will compile"
## 
## let map3 = geomap.open("/map3.tif"")
## let copyTable = initTable[int, Map]
## copyTable[3] = map3
## wontWork(copyTable)  # compile error
## 
## let refTable = newTable[int, Map]
## refTable[3] = map3
## willWork(refTable)
## ```

import gdal/[gdal, cpl, gdal_alg], strformat

# register all GDAL drivers before this can be used
registerAll()

type 
  XformerKind* = enum # method used to transform 
    xfNone # there is no transformer
    xfRPC,  # use Rational Polynomial Coefficient 
    xfAffine, # use an affine transformation
    xfGCP # use Ground Control Points
    

  XformerObj* = object # Xformer can be one of XformerKind
    case kind*: XformerKind
    of xfRPC: rpc*: pointer
    of xfAffine: affine*: array[6, float64]
    of xfGCP: gcp*: pointer
    of xfNone: n*: bool # boolean is never used - just a placeholder

  Xformer* = ref XformerObj

type MapKind = enum
  Raster, Vector

{.experimental: "notnil".}

# when Maps are passed to a proc, they are copied then when the proc
# ends, it triggers the close which kills it.  So never make a copy of map

type Map* = object
  ## An image with geospatial data.  When OpenCV functions in this
  ## module are applied to it, the geospatial data will adjust as
  ## required.  E.g. applying a transform, will transform the
  ## image and the geospatial data.
  
  hDs: Dataset not nil # pointer to GDAL Dataset
  path: string
  isCopy: bool
  case kind: MapKind 
  of Raster:
    xformer: Xformer  # transfomer for world to raster coordinates
  of Vector:
    tbd: int # TBD


proc dataset*(map: Map) : Dataset =
  ## Get the pointer to the GDAL dataset for use in GDAL function calls
  result = map.hDs

proc path*(map: Map) : string =
  ## The path used to open the Map
  result = map.path

proc `=destroy`(this: var Map) =
  ## Destructor for Map
  #echo "--"
  #echo fmt"Destroying map at {this.unsafeAddr.repr}"
  #echo "--"
  if this.kind == Raster and this.xformer != nil:
    case this.xformer.kind:
    of xfGCP: 
      GDALDestroyGCPTransformer(this.xformer.gcp)
    of xfRPC: 
      GDALDestroyRPCTransformer(this.xformer.rpc)
    else : 
      discard
  
  # close dataset if this is not a copy
  if this.hDs != nil and not this.isCopy:
    close(this.hDs)


proc `=copy`(dst: var Map, src: Map) =
  # mark copies of Map as such to prevent closing GDAL resources on copies
  # which means they are invalid for other copies

  # protect against self-assignments:
  if dst.path != src.path:
    `=destroy`(dst)
    wasMoved(dst)
    dst.path = src.path
    dst.hDs = src.hDs
    dst.isCopy = true
  

proc open*(path: string): Map {.raises: [IOError].} =
  ## Open a geospatial file.  
  ## 
  ## `path` is the path/filename/url for a driver to load the file.
  ## Different drivers have different paths, and not all refer to
  ## a file.  For example to open ESRI shape files (.shp, .shx, .dbf)
  ## you can specify the directory all the files are in.
  ## 
  ## Raises an IOError if the path could not be opened
  ## by any driver
  let hDs = gdal.open(path, OF_VERBOSE_ERROR, nil, nil, nil)
  if (hDs.isNil):
    # NB: OF_VERBOSE_ERROR required to get error code
    raise newException(IOError, "Unable to open map '" & path & "'. " & $CPLGetLastErrorMsg())
  else:
    var kind: MapKind
    if GDALGetRasterCount(hDs) > 0:
      kind = Raster
    else:
      kind = Vector

    var map = Map(kind: kind, hDs: hDs, path: path)

    return map;
  

