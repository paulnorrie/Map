import cpl_port, lib

proc CSLFetchBoolean*(papszStrList: CSLConstList, pszKey: cstring, bDefault: cint) : cint {.cdecl, dynlib: libgdal, importc.}

proc CSLSetNameValue*(papszStrList: CSLConstList, pszName: cstring, pszValue: cstring) : ptr cstring {.cdecl, dynlib: libgdal, importc.}

proc CSLTokenizeString*(pszString: cstring) : ptr cstring {.cdecl, dynlib: libgdal, importc.}
