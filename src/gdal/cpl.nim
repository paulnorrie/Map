when defined(windows):
  const libgdal = "libgdal.dll"
elif defined(macosx):
  const libgdal = "libgdal.dylib"
else:
  const libgdal = "libgdal.so"

const
    CPLE_None* = 0
    CPLE_AppDefined* = 1
    CPLE_OutOfMemory* = 2
    CPLE_FileIO* = 3
    CPLE_OpenFailed* = 4
    CPLE_IllegalArg* = 5
    CPLE_NotSupport* = 6
    CPLE_AssertionFailed* = 7
    CPLE_NoWriteAccess* = 8
    CPLE_UserInterrupt* = 9
    CPLE_ObjectNull* = 10
    CPLE_HttpResponse* = 11
    CPLE_AWSBucketNotFound* = 12
    CPLE_AWSObjectNotFound* = 13
    CPLE_AccessDenied* = 14
    CPLE_AWSInvalidCredentials* = 15
    CPLE_AWSSignatureDoesNotMatch* = 16
    CPLE_AWSError* = 17

const
  CE_None* = 0
  CE_Debug* = 1
  CE_Warning* = 2
  CE_Failure* = 3
  CE_Fatal* = 4 


proc CPLGetLastErrorNo*(): cint {.cdecl, dynlib: libgdal, importc: "CPLGetLastErrorNo"}
    # Get the last reported GDAL error

proc CPLGetLastErrorMsg*(): cstring {.cdecl, dynlib: libgdal, importc: "CPLGetLastErrorMsg"}
    # Get the last reported human-readable description of the error