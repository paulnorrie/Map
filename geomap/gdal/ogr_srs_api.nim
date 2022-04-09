import lib

type
  OGRSpatialReferenceH* = pointer
  OGRErr* = int


{.push cdecl, dynlib:libgdal, importc.}


proc OSRIsSame*(aSrs: OGRSpatialReferenceH, bSrs: OGRSpatialReferenceH) : cint 
proc OSRExportToWkt*(hSrs: OGRSpatialReferenceH, ppszResult: ptr ptr cstring, papszOptions: ptr cstring) : OGRErr
proc OSRExportToPrettyWkt*(hSrs: OGRSpatialReferenceH, ppszResult: ptr ptr  cstring, bSimplify: cint = 1.cint) : OGRErr
{.pop.}  