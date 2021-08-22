import gdal

when defined(windows):
  const libgdal = "libgdal.dll"
elif defined(macosx):
  const libgdal = "libgdal.dylib"
else:
  const libgdal = "libgdal.so"


proc GDALCreateGCPTransformer*(nGCPs: cint, pasGCPList:ptr GDAL_GCP, 
                              nReqOrder: cint, bReversed: cint) : pointer
                              {.cdecl, dynlib: libgdal, 
                              importc: "GDALCreateGCPTransformer".}

proc GDALCreateRPCTransformerV2*(psRPC: ptr GDALRPCInfoV2, bReversed: cint, 
                                dfPixErrThreshold: cdouble, 
                                papszOptions: ptr cstring): pointer
                                {.cdecl, dynlib: libgdal, 
                              importc: "GDALCreateRPCTransformerV2".}

proc GDALGCPTransform*(pTransformArg: pointer, bDstToSrc: cint, nPointCount: cint,
                       x: ptr cdouble, y: ptr cdouble, z: ptr cdouble, 
                       panSuccess: ptr cint) : cint
                       {.cdecl, dynlib: libgdal, importc: "GDALGCPTransform".}
                    

    
proc GDALDestroyGCPTransformer*(pTransformArg: pointer): void 
                        {.cdecl, dynlib: libgdal, 
                        importc: "GDALDestroyGCPTransformer".}

proc GDALDestroyRPCTransformer*(pTransformArg: pointer): void
                        {.cdecl, dynlib: libgdal, 
                        importc: "GDALDestroyRPCTransformer".}

proc GDALRPCTransform*(pTransformArg: pointer, bDstToSrc: cint, nPointCount: cint,
                       x: ptr cdouble, y: ptr cdouble, z: ptr cdouble, 
                       panSuccess: ptr cint) : cint
                       {.cdecl, dynlib: libgdal, importc: "GDALRPCTransform".}