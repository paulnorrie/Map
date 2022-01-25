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

import gdal/[gdal, cpl, gdal_alg]

# register all GDAL drivers before this can be used
registerAll()

type 
  XformerKind* = enum # method used to transform 
    xfNone # there is no transformer
    xfRPC,  # use Rational Polynomial Coefficient 
    xfAffine, # use an affine transformation
    xfGCP # use Ground Control Points
    

  XformerObj* = object 
    ## Transforms between world and raster coordinates.
    # Xformer can be one of XformerKind, and are read-only.
    case kind*: XformerKind
    of xfRPC: rpc: pointer
    of xfAffine: affine: array[6, float64]
    of xfGCP: gcp: pointer
    of xfNone: n: bool # boolean is never used - just a placeholder

  Xformer* = ref XformerObj

type MapKind = enum
  mkRaster, mkVector

{.experimental: "notnil".}

# when Maps are passed to a proc, they are copied then when the proc
# ends, it triggers the close which kills it.  So never make a copy of map

type Map* = object
  ## A reference to geospatial data stored in some raster or vector format.
  
  # if the object is a copy of another Map, mark it as such in the `=copy`
  # proc, so the the `=destroy` proc does not release GDAL pointers. Only
  # non-copied objects should release GDAL pointers otherwise they will be
  # invalid for other copies of the object.
  isCopy: bool  

  # ----------------------------------------------------------------
  # IMPORTANT: when you add a field here, copy it in `=copy` as well
  # ----------------------------------------------------------------

  hDs: Dataset not nil # pointer to GDAL Dataset
  path: string         # path to the maps data source
  
  case kind: MapKind 
  of mkRaster:
    xformer: Xformer  # transfomer for world to raster coordinates
  of mkVector:
    tbd: int # TBD


proc dataset*(map: Map) : Dataset =
  ## Get the pointer to the GDAL dataset for use in GDAL function calls
  result = map.hDs

proc path*(map: Map) : string =
  ## The path used to open the Map
  result = map.path

proc `=destroy`(this: var Map) =
  ## Destructor for Map 
  # only remove GDAL resources if this map is not a copy otherwise 
  # pointers will be dangling and other copies GDAL calls will fail
  # because the pointers are invalid.
  if not this.isCopy:
    if this.kind == mkRaster and this.xformer != nil:
      case this.xformer.kind:
      of xfGCP: 
        GDALDestroyGCPTransformer(this.xformer.gcp)
      of xfRPC: 
        GDALDestroyRPCTransformer(this.xformer.rpc)
      else : 
        discard
      
    # close dataset if this is not a copy
    if this.hDs != nil:
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
    case dst.kind:
    of mkRaster:
      dst.xformer = src.xformer
    of mkVector:
      dst.tbd = src.tbd

    # mark new object as copy to prevent dangling pointers on its
    # destruction
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
      kind = mkRaster
    else:
      kind = mkVector

    var map = Map(kind: kind, hDs: hDs, path: path)

    return map;
  

