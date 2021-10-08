# Use cases

1. Open a georeferenced raster and manipulate in OpenCV then save

# Types of Geospatial Data

**Raster**: e.g. a satellite image, a Digital Elevation Model, a radar map
Common raster formats are GeoTIFF and JPEG2000.  You use `RasterMap` to
work with rasters.

**Vector**: e.g. a shape of country boundaries, points of interest in a city.
Common vector formats are GeoJSON files, Google Earth KML files, and
ESRI Shapefiles (a directory of .shp, .shx, .dbf).  You use `VectorMap` to
work with vectors.

# Where in the world are we?  Coordinate Reference Systems

Each Map references somewhere in the world.  There are different ways
of specifying this.  Latitude and Longitude are very common.

## Converting between raster and geospatial coordinates

Maps with rasters have two coordinate systems: one to identify the pixel
on the raster and the other to identify where in the world a point on the
map is.

For example, the upper-left pixel of a raster has x coordinate of 0 and
y coordinate of 0.  That pixel may be located on the world at 36.9°S and
174.8°E.

The naming convention `x`,`y` is used for raster coordinates
and `e` (for easting), `n` (for northing) are used
for world coordinates.  This allows us to easily specify both coordinates
in the same scope.

You can convert world coordinates to raster coordinates this way:
``
var map = geomap.open("picture.tif")
let (x, y) = map.worldToPixel(-36.9, 174.8)
``
This example uses latitude and longitude world coordinates.  You must
pass world coordinates in the same Coordinate Reference System the raster
uses.  If the image above used UTM60 as a Coordinate Reference System then
you would get an incorrect x,y value if you passed in latitude, longitude.

# TODO: Getting vector shapes

Vector shapes often define boundaries, such as property, or markers, like
survey points.  For example, you can read a KML file created on Google Earth
that identifies points of interest in a city and the city boundaries.

Vectors are arranged in one or more Layers.  Each Layer has one or more
Features.  Each Feature has one or more Geometries (such as a polygon, or a
point), and some attributes (describing the Feature, e.g. "My House").

To read vectors, open a `VectorMap` with `geomap.openVector` then you can 
iterate through all the vector data:
``
for layer in map.layers:
  for feature in layer.features:
    for geometry in feature.geometries
      echo geometry
``

# Performing graphics operations on Rasters

## Working with vector shapes on rasters
Often you want to take a vector shape and do something to a raster based on it. 
For example, you want an image to be transparent outside a polygon, or an
image to have the outline of a line drawn on the raster.

To start you need a map of the raster and a map of the vectors.  As an example,
say we have a raster file which is an RGB satellite image of our country, and a
vector file that gives city and country boundaries:
``
map boundaries = geomap.openVector("boundaries.kml") # state and country boundaries
map image = geomap.openRaster("landscape.tif")  #satellite image in RGB format
``

### TODO: Create mask that has 0's on the outside of a polygon

```
let border = boundaries.layers[0].features[0]  # assume this is a polygon
let mask = border.createMaskOn(image, mskExterior, pen) # mskBorder, mskterior using the pen
image &&= mask  # all pixels on the outside will
                # become black, the remaining stay
                # as they are
```

## Raster operations

SDL and Java use [x...][y...] while opencv uses [(x,y), (x,y)]

poly: tuple[T][x: seq[T], y: seq[T]]
let poly = border.createPolygonOn(image)
let rect = border.createRectOn(image)
let line = border.createLineOn(image)

# TODO: addition, subtraction, bitwise operators
dataset operator array1D # apply operator on all bands in dataset with 1D array (dataset is lhs, array is rhs)
band operator array1D
e.g. 
``
let mask = [[0x00, 0xFF, 0x00],
            [0x00, 0xFF, 0x00]]
let result = map + mask  # applies mask to all the map
let result = map.bands[0] && mask # applies mask to one band in the map
``

To do this in-place and actually modify the raster:
``
map += mask  # map raster is overwritten
map.bands[0] &&= mask # bands raster is overwritten
``

# TODO: band calculations you export to array and do it yourself
e.g. NDVI
import arraymancer

proc ndvi[T](nir: T, red: T):
   nir + red / nir - red

let tensor = map.toArray().toTensor() #toArray gives shape Channel xHeight x Width
let red = map.bands[4]
let nir = map.bands[7]
map2(red.toArray, ndvi, nir.toArray) # arraymancer

for x = 0 x < width:
 for y = 0 y < height:   # faster way of iterating is just one loop
   let i = x * width + y
   result[i] = red[i] + nir[i] / red[i] - nir[i]


calc does not operate on NO_DATA values - they remain the same.  If you don't
want that, remove NO_DATA values with map.noDataTo(value: uint8 etc) first

Doing in-place operations requires write permission to storage and the driver
to support it along with AddBand() and RemoveBand().  As soon as we do 
in-place writes, we may need to create a new dataset and destroy the old one
TODO: Reading large rasters one chunk at a time, process them, then read
next chunk, process it, etc (probably do this using an iterator)


# Operating on the raster with an external library like OpenCV or Pixie
Raster maps have a pointer to the raster data if it has been read which can
be used to manipulate the raster with other libraries.  The raster data can
be arranged in a variety of ways to be compatible with these libraries.

This data can be changed in place but it cannot be reduced or increased in
the size of the raster, which is defined by the width, height and data type.
If you want to change the raster in a way that changes the size in memory or
the structure (bands, data type), then you must create a new raster to do this.
**TODO:** Create new raster

## OpenCV
```
let map = geomap.openRaster("image.tif")
let raster = map.readRaster(BIP)  # OpenCV needs pixel interleaved format in memory
let mat = constructMat(map.height.cint,
             map.width.cint,
            toOpenCVType(map.dataType, map.numBands), 
            raster.rasterData)
# we now have a Mat object we can do things with in OpenCV
# if we want to display it with imshow we must convert to BGR colour space
```




# Building and Distributing Map with your Application
Map uses GDAL native libraries which must be available on your users system at
runtime.

## Mac OSX

### If your app is distributed on Homebrew
If you distribute using a Homebrew package, you can simply add gdal as a dependancy.
This will use dynamic linking at runtime with the dylibs in the same locations as
you have.
(TODO: check versions)

### If your app is distributed on the Mac App Store

### or outside the App Store (.dmg)
Either build Map as a framework and include it in your dmg file 
otherwise statically link Map.



## Linux
If you distribute using a package manager, add libgdal as a dependancy.  This
will use dynamic linking at runtime.


## Windows
If you distribute using chocolate, gdal is not yet a dependancy, and most likely
you don't distribute using chocolate.  Therefore you either have to build and
supply the GDAL and it's required dependancies (e.g. libgif, openjpeg, openssl,
 etc) for Windows or statically Map and dynamically link to it (Map.dll) 
 or statically compile your entire application.

## With a customised GDAL build
In some cases, you may want to customise your own GDAL build, for example to
exclude certain drivers or statically compile all the dependancies.

# TODO

* Large images
* Multi-threading
