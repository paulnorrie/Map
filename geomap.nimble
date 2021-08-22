#import osproc

# Package

version       = "3.2.0"
author        = "Paul Norrie"
description   = "Manipulate geospatial data and images"
license       = "MIT"
#srcDir        = "map"


# Dependencies

requires "nim >= 1.4.8"

#before install:
#    import distros
#    if detectOs(MacOSX):
        # to distribute on MacOSX you will need to either:
        # brew install gdal (for command line applications distributed on Homebrew)
        # or,
        # statically link libraries for a App Package (.dmg)
#        foreignDepCmd("gdal")
#        discard exec("brew install gdal")
        
#    else if detectOs(Linux):
        # to distribute on Linux you will need gdal-dev package
#        foreignDepCmd("gdal-dev")

#    else if detectOs(Windows):
#    else:    

## Tasks
#task build, "builds Map dynamically linking to GDAL":

#task build_static: "builds Map statically linking to GDAL":

