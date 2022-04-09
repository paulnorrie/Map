when defined(windows):
  const libgdal* = "libgdal.dll"
elif defined(macosx):
  const libgdal* = "libgdal.dylib"
else:
  const libgdal* = "libgdal.so"