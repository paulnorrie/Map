## The SpatialReference type and basic procedures for this type
import ../../gdal/[cpl, cpl_conv, ogr_srs_api, ogr_core]


# ------------------------------------------------------------------------------
# SpatialReferenceSystem
# ------------------------------------------------------------------------------
type
  SpatialReferenceSystem* = object
    hSrs: pointer   # GDAL will free when dataset is freed



proc handle*(srs: SpatialReferenceSystem) : pointer =
  ## Return the GDAL handle to this SRS
  result = srs.hSrs



proc `==`*(a, b: SpatialReferenceSystem) : bool =
  ## `a` is equal to `b` if they describe the same system.
  result = OSRIsSame(a.hSrs, b.hSrs).bool


proc `$`*(srs: SpatialReferenceSystem) : string =
  ## Formatted, Well-Known Text (WKT) representation
  var wkt: ptr cstring
  let err = OSRExportToPrettyWkt(srs.handle, wkt.addr)
  #var options = [cstring "FORMAT=SFSQL", "MULTILINE=YES", nil]
  #let err = OSRExportToWkt(srs.handle, wkt.addr, options[0].addr)
  if err != OGRERR_NONE:
    result = $CPLGetLastErrorMsg()
  else:
    result = $(cast[cstring](wkt))
    CPLFree(wkt)



proc initSpacialReferenceSystem*(hSrs: pointer) : SpatialReferenceSystem =
  ## Create a SpatialReferenceSystem from a GDAL handle
  result = SpatialReferenceSystem(hSrs: hSrs)







  