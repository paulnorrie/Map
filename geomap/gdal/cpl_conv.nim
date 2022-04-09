
import lib

proc CPLFree*(p: pointer) {.cdecl, dynlib:libgdal, importc: "VSIFree".}

{.push cdecl, dynlib:libgdal, importc.}

proc VSIFree*(p: pointer) 

{.pop.}