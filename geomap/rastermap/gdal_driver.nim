## GDAL Driver utilities

import std/[os, strutils, re]
import ../gdal/[gdal]

iterator drivers*() : pointer =
  ## iterate over loaded drivers, returning their handle
  let count = GDALGetDriverCount()
  for i in 0 ..< count:
    let hDriver = GDALGetDriver(i.cint)
    yield hDriver



proc canCreate*(hDriver: pointer) : bool =
  ## Does the driver support Create?
  let item = GDALGetMetadataItem(hDriver, GDAL_DCAP_CREATE, nil)
  if item != nil:
    result = true
  #let driverMetadata = GDALGetMetadata(hDriver, nil)
  #result = CSLFetchBoolean(driverMetadata, GDAL_DCAP_CREATE, 0).bool



proc canCreateCopy*(hDriver: pointer) : bool =
  ## Does the driver support CreateCopy?
  let item = GDALGetMetadataItem(hDriver, GDAL_DCAP_CREATECOPY, nil)
  if item != nil:
    result = true



proc handlesRaster*(hDriver: pointer) : bool =
  ## Does the driver support Raster data
  let item = GDALGetMetadataItem(hDriver, GDAL_DCAP_RASTER, nil)
  if item != nil:
    result = true


proc tokenize(str: string) : seq[string] =
  let pattern = "\"([^\"]*)\"|(\\S+)"
  result = str.findAll(re pattern)
  # strip any leading/trailing speech marks
  for i in 0 ..< result.len:
    if result[i].startsWith("\"") and result[i].endsWith("\""):
      result[i] = result[i][1 .. ^1]


proc extensions(hDriver: pointer) : seq[string] =
  ## Extensions handled by driver, returned in lower case
  let driverExts = GDALGetMetadataItem(hDriver, GDAL_DMD_EXTENSIONS, nil)
  
  if driverExts != nil:
    result = tokenize($driverExts)
    for i in 0 ..< result.len:
      result[i] = result[i].toLowerAscii


proc handlesExtension(hDriver: pointer, ext: string) : bool =
  ## Does the driver support a local file based system with a file extension of
  ## `ext`?
  ## * `hDriver` is the handle to the driver
  ## * `ext` is the extension of the file
  if ext.startsWith('.'): 
    let exts = extensions(hDriver)
    result = exts.contains(ext[1 .. ^1])
  else:
    let exts = extensions(hDriver)
    result = exts.contains(ext)


proc getOutputDriversFor*(path: string): seq[string] =
  ## Get the raster drivers short names that support writing to a given `path`
  
  let lowerPath = path.toLowerAscii
  var ext = splitFile(lowerPath).ext
  if ext == "zip" and lowerPath.endsWith("shp.zip"):
    ext = "shp.zip"

  for hDriver in drivers():
    
    if (hDriver.canCreate or hDriver.canCreateCopy) and hDriver.handlesRaster:
      if hDriver.handlesExtension(ext):
        # file based driver
        result.add $GDALGetDriverShortName(hDriver)
      else:
        # connection based driver
        let prefix = GDALGetMetadataItem(hDriver, GDAL_DMD_CONNECTION_PREFIX, nil)
        if prefix != nil and lowerPath.startsWith($prefix):
          result.add $GDALGetDriverShortName(hDriver)
  
  # GMT is registered before netCDF for opening reasons, but we want
  # netCDF to be used by default for output.
  if ext == "nc" and result.len == 2 and
     result[0] == "GMT" and result[1] == "NETCDF":
    
    result[0] = "NETCDF"
    result[1] = "GMT"

  