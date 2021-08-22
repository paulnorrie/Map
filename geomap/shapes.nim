# OGR Shapes and their Raster equivilents
# Raster shapes are designed for interoperability with drawing packages

type 
    MapPoint = object
        e: float64
        n: float64
        z: float64

    MapPolygon = object
        points: seq[MapPoint]

type 
    RasterPoint = object
        x: uint32
        y: uint32

    RasterPolygon = object
        points: seq[RasterPoint]



# functions to export definitions to different formats


# functions to create raster versions on an image
#proc toRasterOn(poly: MapPolygon, map: Map) : RasterPolygon =
    # poly: MapPolygon
    # poly.asRasterOn(map).asArrayOfPoints
    # poly.asRasterOn(map).asArrayOfDims
    # point: MapPoint
    # point.asRasterOn(map)
