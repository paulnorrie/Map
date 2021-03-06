## To statically link
## ------------------
## --dynlibOverride:libgdal --passL:libgdal.a  or {.link libgdal.a.}
import cpl_port
import lib



type
  Band* = pointer
  Layer* = pointer
  Feature* = pointer
  FeatureDefn* = pointer
  FieldDefn* = pointer
  Geometry* = pointer
  SpatialReference* = pointer
  CoordinateTransformation* = pointer
  Access* = enum
    ReadOnly               ## Read only (no update) access
    Update                 ## Read/write access
  FieldType* = enum
    Integer                ## Simple 32bit integer.
    IntegerList            ## List of 32bit integers.
    Real                   ## Double Precision floating point.
    RealList               ## List of doubles.
    String                 ## String of ASCII chars.
    StringList             ## Array of strings.
    WideString             ## deprecated
    WideStringList         ## deprecated
    Binary                 ## Raw Binary data.
    Date                   ## Date.
    Time                   ## Time.
    DateTime               ## Date and Time.
    Integer64              ## Single 64bit integer.
    Integer64List          ## List of 64bit integers.
  GeometryType* = enum
    Unknown                ## unknown type, non-standard
    Point                  ## 0-dimensional geometric object, standard WKB
    LineString             ## 1-dimensional geometric object with linear interpolation between Points, standard WKB
    Polygon                ## planar 2-dimensional geometric object defined by 1 exterior boundary and 0 or more interior boundaries, standard WKB
    MultiPoint             ## GeometryCollection of Points, standard WKB.
    MultiLineString        ## GeometryCollection of LineStrings, standard WKB.
    MultiPolygon           ## GeometryCollection of Polygons, standard WKB.
    GeometryCollection     ## geometric object that is a collection of 1 or more geometric objects, standard WKB
    CircularString         ## one or more circular arc segments connected end to end, ISO SQL/MM Part 3. GDAL >= 2.0
    CompoundCurve          ## sequence of contiguous curves, ISO SQL/MM Part 3. GDAL >= 2.0
    CurvePolygon           ## planar surface, defined by 1 exterior boundary and zero or more interior boundaries, that are curves. ISO SQL/MM Part 3. GDAL >= 2.0
    MultiCurve             ## GeometryCollection of Curves, ISO SQL/MM Part 3. GDAL >= 2.0
    MultiSurface           ## GeometryCollection of Surfaces, ISO SQL/MM Part 3. GDAL >= 2.0
    Curve                  ## Curve (abstract type). ISO SQL/MM Part 3. GDAL >= 2.1
    Surface                ## Surface (abstract type). ISO SQL/MM Part 3. GDAL >= 2.1
    PolyhedralSurface      ## a contiguous collection of polygons, which share common boundary segments, ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    TIN                    ## a PolyhedralSurface consisting only of Triangle patches ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    Triangle               ## a Triangle. ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    None                   ## non-standard, for pure attribute records
    LinearRing             ## non-standard, just for createGeometry()
    CircularStringZ        ## wkbCircularString with Z component. ISO SQL/MM Part 3. GDAL >= 2.0
    CompoundCurveZ         ## wkbCompoundCurve with Z component. ISO SQL/MM Part 3. GDAL >= 2.0
    CurvePolygonZ          ## wkbCurvePolygon with Z component. ISO SQL/MM Part 3. GDAL >= 2.0
    MultiCurveZ            ## wkbMultiCurve with Z component. ISO SQL/MM Part 3. GDAL >= 2.0
    MultiSurfaceZ          ## wkbMultiSurface with Z component. ISO SQL/MM Part 3. GDAL >= 2.0
    CurveZ                 ## wkbCurve with Z component. ISO SQL/MM Part 3. GDAL >= 2.1
    SurfaceZ               ## wkbSurface with Z component. ISO SQL/MM Part 3. GDAL >= 2.1
    PolyhedralSurfaceZ     ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    TINZ                   ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    TriangleZ              ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    PointM                 ## ISO SQL/MM Part 3. GDAL >= 2.1
    LineStringM            ## ISO SQL/MM Part 3. GDAL >= 2.1
    PolygonM               ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiPointM            ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiLineStringM       ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiPolygonM          ## ISO SQL/MM Part 3. GDAL >= 2.1
    GeometryCollectionM    ## ISO SQL/MM Part 3. GDAL >= 2.1
    CircularStringM        ## ISO SQL/MM Part 3. GDAL >= 2.1
    CompoundCurveM         ## ISO SQL/MM Part 3. GDAL >= 2.1
    CurvePolygonM          ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiCurveM            ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiSurfaceM          ## ISO SQL/MM Part 3. GDAL >= 2.1
    CurveM                 ## ISO SQL/MM Part 3. GDAL >= 2.1
    SurfaceM               ## ISO SQL/MM Part 3. GDAL >= 2.1
    PolyhedralSurfaceM     ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    TINM                   ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    TriangleM              ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    PointZM                ## ISO SQL/MM Part 3. GDAL >= 2.1
    LineStringZM           ## ISO SQL/MM Part 3. GDAL >= 2.1
    PolygonZM              ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiPointZM           ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiLineStringZM      ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiPolygonZM         ## ISO SQL/MM Part 3. GDAL >= 2.1
    GeometryCollectionZM   ## ISO SQL/MM Part 3. GDAL >= 2.1
    CircularStringZM       ## ISO SQL/MM Part 3. GDAL >= 2.1
    CompoundCurveZM        ## ISO SQL/MM Part 3. GDAL >= 2.1
    CurvePolygonZM         ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiCurveZM           ## ISO SQL/MM Part 3. GDAL >= 2.1
    MultiSurfaceZM         ## ISO SQL/MM Part 3. GDAL >= 2.1
    CurveZM                ## ISO SQL/MM Part 3. GDAL >= 2.1
    SurfaceZM              ## ISO SQL/MM Part 3. GDAL >= 2.1
    PolyhedralSurfaceZM    ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    TINZM                  ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    TriangleZM             ## ISO SQL/MM Part 3. Reserved in GDAL >= 2.1 but not yet implemented
    Point25D               ## 2.5D extension as per 99-402
    LineString25D          ## 2.5D extension as per 99-402
    Polygon25D             ## 2.5D extension as per 99-402
    MultiPoint25D          ## 2.5D extension as per 99-402
    MultiLineString25D     ## 2.5D extension as per 99-402
    MultiPolygon25D        ## 2.5D extension as per 99-402
    GeometryCollection25D  ## 2.5D extension as per 99-402

proc `$`*(ds:pointer) : string =
  result = ds.unsafeAddr.repr

type GDAL_GCP* {.importc, header: "gdal.h".} = object #{.importc: "struct GDAL_GCP", header: "gdal.h".} = object  
  pszId*: cstring
  pszInfo*: cstring
  dfGCPPixel*: cdouble
  dfGCPLine*: cdouble
  dfGCPX*: cdouble
  dfGCPY*: cdouble
  dfGCPZ*: cdouble

type GDALRPCInfoV2* {.importc: "GDALRPCInfoV2", header: "gdal.h".} = object
  dfLINE_OFF*: cdouble
  dfSAMP_OFF*: cdouble
  dfLAT_OFF*: cdouble
  dfLONG_OFF*: cdouble
  dfHEIGHT_OFF*: cdouble
  dfLINE_SCALE*: cdouble
  dfSAMP_SCALE*: cdouble
  dfLAT_SCALE*: cdouble
  dfLONG_SCALE*: cdouble
  dfHEIGHT_SCALE*: cdouble
  adfLINE_NUM_COEFF*: array[20, cdouble]
  adfLINE_DEN_COEFF*: array[20, cdouble]
  adfSAMP_NUM_COEFF*: array[20, cdouble]
  adfSAMP_DEN_COEFF*: array[20, cdouble]
  dfMIN_LONG*: cdouble
  dfMIN_LAT*: cdouble
  dfMAX_LONG*: cdouble
  dfMAX_LAT*: cdouble
  dfERR_BIAS*: cdouble
  dfERR_RAND*: cdouble

type GDALRWFlag* {.size: sizeof(cint).} = enum
  GF_Read = 0
  GF_Write = 1

type GDALDataType* {.size: sizeof(cint).} = enum
  GDT_Unknown = (0, "Unknown")
  GDT_Byte = (1, "Byte")
  GDT_UInt16 = (2, "UInt16")
  GDT_Int16 = (3, "Int16")
  GDT_UInt32 = (4, "UInt32")
  GDT_Int32 = (5, "Int32")
  GDT_Float32 = (6, "Float32")
  GDT_Float64 = (7, "Float64")
  GDT_CInt16 = (8, "CInt16")
  GDT_CInt32 = (9, "CInt32")
  GDT_CFloat32 = (10, "CFloat32")
  GDT_CFloat64 = (11, "CFloat64")
  GDT_TypeCount = (12, "TypeCount")

type GDALRIOResampleAlg*  {.size: sizeof(cint).} = enum
  GRIORA_NearestNeighbour = 0
  GRIORA_Bilinear = 1
  GRIORA_Cubic = 2
  GRIORA_CubicSpline = 3
  GRIORA_Lanczos = 4
  GRIORA_Average = 5
  GRIORA_Mode = 6
  GRIORA_Gauss = 7
  GRIORA_RMS = 14

type GDALProgressFunc* =
    proc (dfComplete: cdouble, pszMessage: cstring, pProgressArg: pointer): cint {.cdecl.}

type GDALRasterIOExtraArg* = object
  nVersion*: cint
  eResampleArg*: GDALRIOResampleAlg
  pfnProgress*: GDALProgressFunc
  pProgressData*: pointer
  bFloatingPointWindowValidity*: cint
  dfXOff*: cdouble
  dfYOff*: cdouble
  dfXSize*: cdouble
  dfYSize*: cdouble

type GDALColorInterp* {.size: sizeof(cint).} = enum
  GCI_Undefined = 0
  GCI_GrayIndex = 1
  GCI_PaletteIndex = 2
  GCI_RedBand = 3
  GCI_GreenBand = 4
  GCI_BlueBand = 5
  GCI_AlphaBand = 6
  GCI_HueBand = 7
  GCI_SaturationBand = 8
  GCI_LightnessBand = 9
  GCI_CyanBand = 10
  GCI_MagentaBand = 11
  GCI_YellowBand = 12
  GCI_BlackBand = 13
  GCI_YCbCr_YBand = 14
  GCI_YCbCr_CbBand = 15
  GCI_YCbCr_CrBand = 16
  #GCI_Max = 16


const
  OF_ALL*       = 0x00  ## Allow all types of drivers to be used    
  OF_READONLY*  = 0x00  ## Open in read-only mode.
  OF_UPDATE*    = 0x01  ## Open in read/write mode.
  OF_RASTER*    = 0x02 ## Allow raster drivers to be used
  OF_VECTOR*    = 0x04  ## Allow vector drivers to be used
  OF_GNM*       = 0x08  ## Allow GNM drivers to be used
  OF_MULTIDIM_RASTER* = 0x10 ##
  OF_SHARED*    = 0x20  ## Open in shared mode
  OF_VERBOSE_ERROR*   = 0x40  ## Emit error message in case of a failed open
  GDAL_DCAP_CREATE* = "DCAP_CREATE".cstring
  GDAL_DCAP_CREATECOPY* = "DCAP_CREATE_COPY".cstring
  GDAL_DCAP_RASTER* = "DCAP_RASTER".cstring
  GDAL_DMD_EXTENSIONS* = "DMD_EXTENSIONS".cstring
  GDAL_DMD_CONNECTION_PREFIX* = "GDAL_DMD_CONNECTION_PREFIX".cstring
  WKT_WGS84* = "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"4326\"]]"  ## WGS 84 geodetic (long/lat) WKT / EPSG:4326 with long,lat ordering
  PT_ALBERS_CONIC_EQUAL_AREA* = "Albers_Conic_Equal_Area"  ## Albers_Conic_Equal_Area projection
  PT_AZIMUTHAL_EQUIDISTANT* = "Azimuthal_Equidistant"  ## Azimuthal_Equidistant projection
  PT_CASSINI_SOLDNER* = "Cassini_Soldner"  ## Cassini_Soldner projection
  PT_CYLINDRICAL_EQUAL_AREA* = "Cylindrical_Equal_Area"  ## Cylindrical_Equal_Area projection 
  PT_BONNE* = "Bonne"  ## Cylindrical_Equal_Area projection 
  PT_ECKERT_I* = "Eckert_I"  ## Eckert_I projection 
  PT_ECKERT_II* = "Eckert_II"  ## Eckert_II projection 
  PT_ECKERT_III* = "Eckert_III"  ## Eckert_III projection 
  PT_ECKERT_IV* = "Eckert_IV"  ## Eckert_IV projection 
  PT_ECKERT_V* = "Eckert_V"  ## Eckert_V projection 
  PT_ECKERT_VI* = "Eckert_VI"  ## Eckert_VI projection 
  PT_EQUIDISTANT_CONIC* = "Equidistant_Conic"  ## Equidistant_Conic projection 
  PT_EQUIRECTANGULAR* = "Equirectangular"  ## Equirectangular projection 
  PT_GALL_STEREOGRAPHIC* = "Gall_Stereographic"  ## Gall_Stereographic projection 
  PT_GAUSSSCHREIBERTMERCATOR* = "Gauss_Schreiber_Transverse_Mercator"  ## Gauss_Schreiber_Transverse_Mercator projection 
  PT_GEOSTATIONARY_SATELLITE* = "Geostationary_Satellite"  ## Geostationary_Satellite projection 
  PT_GOODE_HOMOLOSINE* = "Goode_Homolosine"  ## Goode_Homolosine projection 
  PT_IGH* = "Interrupted_Goode_Homolosine"  ## Interrupted_Goode_Homolosine projection 
  PT_GNOMONIC* = "Gnomonic"  ## Gnomonic projection 
  PT_HOTINE_OBLIQUE_MERCATOR_AZIMUTH_CENTER* = "Hotine_Oblique_Mercator_Azimuth_Center"  ## Hotine_Oblique_Mercator_Azimuth_Center projection 
  PT_HOTINE_OBLIQUE_MERCATOR* = "Hotine_Oblique_Mercator"  ## Hotine_Oblique_Mercator projection 
  PT_HOTINE_OBLIQUE_MERCATOR_TWO_POINT_NATURAL_ORIGIN* = "Hotine_Oblique_Mercator_Two_Point_Natural_Origin"  ## Hotine_Oblique_Mercator_Two_Point_Natural_Origin projection 
  PT_LABORDE_OBLIQUE_MERCATOR* = "Laborde_Oblique_Mercator"  ## Laborde_Oblique_Mercator projection 
  PT_LAMBERT_CONFORMAL_CONIC_1SP* = "Lambert_Conformal_Conic_1SP"  ## Lambert_Conformal_Conic_1SP projection 
  PT_LAMBERT_CONFORMAL_CONIC_2SP* = "Lambert_Conformal_Conic_2SP"  ## Lambert_Conformal_Conic_2SP projection 
  PT_LAMBERT_CONFORMAL_CONIC_2SP_BELGIUM* = "Lambert_Conformal_Conic_2SP_Belgium"  ## Lambert_Conformal_Conic_2SP_Belgium projection 
  PT_LAMBERT_AZIMUTHAL_EQUAL_AREA* = "Lambert_Azimuthal_Equal_Area"  ## Lambert_Azimuthal_Equal_Area projection 
  PT_MERCATOR_1SP* = "Mercator_1SP"  ## Mercator_1SP projection 
  PT_MERCATOR_2SP* = "Mercator_2SP"  ## Mercator_2SP projection 
  PT_MERCATOR_AUXILIARY_SPHERE* = "Mercator_Auxiliary_Sphere"  ## Mercator_Auxiliary_Sphere is used used by ESRI to mean EPSG:3875 
  PT_MILLER_CYLINDRICAL* = "Miller_Cylindrical"  ## Miller_Cylindrical projection 
  PT_MOLLWEIDE* = "Mollweide"  ## Mollweide projection 
  PT_NEW_ZEALAND_MAP_GRID* = "New_Zealand_Map_Grid"  ## New_Zealand_Map_Grid projection 
  PT_OBLIQUE_STEREOGRAPHIC* = "Oblique_Stereographic"  ## Oblique_Stereographic projection 
  PT_ORTHOGRAPHIC* = "Orthographic"  ## Orthographic projection 
  PT_POLAR_STEREOGRAPHIC* = "Polar_Stereographic"  ## Polar_Stereographic projection 
  PT_POLYCONIC* = "Polyconic"  ## Polyconic projection 
  PT_ROBINSON* = "Robinson"  ## Robinson projection 
  PT_SINUSOIDAL* = "Sinusoidal"  ## Sinusoidal projection 
  PT_STEREOGRAPHIC* = "Stereographic"  ## Stereographic projection 
  PT_SWISS_OBLIQUE_CYLINDRICAL* = "Swiss_Oblique_Cylindrical"  ## Swiss_Oblique_Cylindrical projection 
  PT_TRANSVERSE_MERCATOR* = "Transverse_Mercator"  ## Transverse_Mercator projection 
  PT_TRANSVERSE_MERCATOR_SOUTH_ORIENTED* = "Transverse_Mercator_South_Orientated"  ## Transverse_Mercator_South_Orientated projection 
  PT_TRANSVERSE_MERCATOR_MI_21* = "Transverse_Mercator_MapInfo_21"  ## Transverse_Mercator_MapInfo_21 projection 
  PT_TRANSVERSE_MERCATOR_MI_22* = "Transverse_Mercator_MapInfo_22"  ## Transverse_Mercator_MapInfo_22 projection 
  PT_TRANSVERSE_MERCATOR_MI_23* = "Transverse_Mercator_MapInfo_23"  ## Transverse_Mercator_MapInfo_23 projection 
  PT_TRANSVERSE_MERCATOR_MI_24* = "Transverse_Mercator_MapInfo_24"  ## Transverse_Mercator_MapInfo_24 projection 
  PT_TRANSVERSE_MERCATOR_MI_25* = "Transverse_Mercator_MapInfo_25"  ## Transverse_Mercator_MapInfo_25 projection 
  PT_TUNISIA_MINING_GRID* = "Tunisia_Mining_Grid"  ## Tunisia_Mining_Grid projection 
  PT_TWO_POINT_EQUIDISTANT* = "Two_Point_Equidistant"  ## Two_Point_Equidistant projection 
  PT_VANDERGRINTEN* = "VanDerGrinten"  ## VanDerGrinten projection 
  PT_KROVAK* = "Krovak"  ## Krovak projection 
  PT_IMW_POLYCONIC* = "International_Map_of_the_World_Polyconic"  ## International_Map_of_the_World_Polyconic projection 
  PT_WAGNER_I* = "Wagner_I"  ## Wagner_I projection 
  PT_WAGNER_II* = "Wagner_II"  ## Wagner_II projection 
  PT_WAGNER_III* = "Wagner_III"  ## Wagner_III projection 
  PT_WAGNER_IV* = "Wagner_IV"  ## Wagner_IV projection 
  PT_WAGNER_V* = "Wagner_V"  ## Wagner_V projection 
  PT_WAGNER_VI* = "Wagner_VI"  ## Wagner_VI projection 
  PT_WAGNER_VII* = "Wagner_VII"  ## Wagner_VII projection 
  PT_QSC* = "Quadrilateralized_Spherical_Cube"  ## Quadrilateralized_Spherical_Cube projection 
  PT_AITOFF* = "Aitoff"  ## Aitoff projection 
  PT_WINKEL_I* = "Winkel_I"  ## Winkel_I projection 
  PT_WINKEL_II* = "Winkel_II"  ## Winkel_II projection 
  PT_WINKEL_TRIPEL* = "Winkel_Tripel"  ## Winkel_Tripel projection 
  PT_CRASTER_PARABOLIC* = "Craster_Parabolic"  ## Craster_Parabolic projection 
  PT_LOXIMUTHAL* = "Loximuthal"  ## Loximuthal projection 
  PT_QUARTIC_AUTHALIC* = "Quartic_Authalic"  ## Quartic_Authalic projection 
  PT_SCH* = "Spherical_Cross_Track_Height"  ## Spherical_Cross_Track_Height projection 
  PP_CENTRAL_MERIDIAN* = "central_meridian"  ## central_meridian projection paramete 
  PP_SCALE_FACTOR* = "scale_factor"  ## scale_factor projection paramete 
  PP_STANDARD_PARALLEL_1* = "standard_parallel_1"  ## standard_parallel_1 projection paramete 
  PP_STANDARD_PARALLEL_2* = "standard_parallel_2"  ## standard_parallel_2 projection paramete 
  PP_PSEUDO_STD_PARALLEL_1* = "pseudo_standard_parallel_1"  ## pseudo_standard_parallel_1 projection paramete 
  PP_LONGITUDE_OF_CENTER* = "longitude_of_center"  ## longitude_of_center projection paramete 
  PP_LATITUDE_OF_CENTER* = "latitude_of_center"  ## latitude_of_center projection paramete 
  PP_LONGITUDE_OF_ORIGIN* = "longitude_of_origin"  ## longitude_of_origin projection paramete 
  PP_LATITUDE_OF_ORIGIN* = "latitude_of_origin"  ## latitude_of_origin projection paramete 
  PP_FALSE_EASTING* = "false_easting"  ## false_easting projection paramete 
  PP_FALSE_NORTHING* = "false_northing"  ## false_northing projection paramete 
  PP_AZIMUTH* = "azimuth"  ## azimuth projection paramete 
  PP_LONGITUDE_OF_POINT_1* = "longitude_of_point_1"  ## longitude_of_point_1 projection paramete 
  PP_LATITUDE_OF_POINT_1* = "latitude_of_point_1"  ## latitude_of_point_1 projection paramete 
  PP_LONGITUDE_OF_POINT_2* = "longitude_of_point_2"  ## longitude_of_point_2 projection paramete 
  PP_LATITUDE_OF_POINT_2* = "latitude_of_point_2"  ## latitude_of_point_2 projection paramete 
  PP_LONGITUDE_OF_POINT_3* = "longitude_of_point_3"  ## longitude_of_point_3 projection paramete 
  PP_LATITUDE_OF_POINT_3* = "latitude_of_point_3"  ## latitude_of_point_3 projection paramete 
  PP_RECTIFIED_GRID_ANGLE* = "rectified_grid_angle"  ## rectified_grid_angle projection paramete 
  PP_LANDSAT_NUMBER* = "landsat_number"  ## landsat_number projection paramete 
  PP_PATH_NUMBER* = "path_number"  ## path_number projection paramete 
  PP_PERSPECTIVE_POINT_HEIGHT* = "perspective_point_height"  ## perspective_point_height projection paramete 
  PP_SATELLITE_HEIGHT* = "satellite_height"  ## satellite_height projection paramete 
  PP_FIPSZONE* = "fipszone"  ## fipszone projection paramete 
  PP_ZONE* = "zone"  ## zone projection paramete 
  PP_LATITUDE_OF_1ST_POINT* = "Latitude_Of_1st_Point"  ## Latitude_Of_1st_Point projection parameter 
  PP_LONGITUDE_OF_1ST_POINT* = "Longitude_Of_1st_Point"  ## Longitude_Of_1st_Point projection parameter 
  PP_LATITUDE_OF_2ND_POINT* = "Latitude_Of_2nd_Point"  ## Latitude_Of_2nd_Point projection parameter 
  PP_LONGITUDE_OF_2ND_POINT* = "Longitude_Of_2nd_Point"  ## Longitude_Of_2nd_Point projection parameter 
  PP_PEG_POINT_LATITUDE* = "peg_point_latitude"  ## peg_point_latitude projection paramete 
  PP_PEG_POINT_LONGITUDE* = "peg_point_longitude"  ## peg_point_longitude projection paramete 
  PP_PEG_POINT_HEADING* = "peg_point_heading"  ## peg_point_heading projection paramete 
  PP_PEG_POINT_HEIGHT* = "peg_point_height"  ## peg_point_height projection paramete 
  UL_METER* = "Meter"  ## Linear unit Meter 
  UL_FOOT* = "Foot (International)"  ## or just "FOOT"?, Linear unit Foot (International 
  UL_FOOT_CONV* = "0.3048"  ## Linear unit Foot (International) conversion factor to meter 
  UL_US_FOOT* = "Foot_US"  ## or "US survey foot" from EPSG, Linear unit Foot 
  UL_US_FOOT_CONV* = "0.3048006096012192"  ## Linear unit Foot conversion factor to meter 
  UL_NAUTICAL_MILE* = "Nautical Mile"  ## Linear unit Nautical Mile 
  UL_NAUTICAL_MILE_CONV* = "1852.0"  ## Linear unit Nautical Mile conversion factor to meter 
  UL_LINK* = "Link"  ## Based on US Foot, Linear unit Link 
  UL_LINK_CONV* = "0.20116684023368047"  ## Linear unit Link conversion factor to meter 
  UL_CHAIN* = "Chain"  ## based on US Foot, Linear unit Chain 
  UL_CHAIN_CONV* = "20.116684023368047"  ## Linear unit Chain conversion factor to meter 
  UL_ROD* = "Rod"  ## based on US Foot, Linear unit Rod 
  UL_ROD_CONV* = "5.02921005842012"  ## Linear unit Rod conversion factor to meter 
  UL_LINK_Clarke* = "Link_Clarke"  ## Linear unit Link_Clarke 
  UL_LINK_Clarke_CONV* = "0.2011661949"  ## Linear unit Link_Clarke conversion factor to meter 
  UL_KILOMETER* = "Kilometer"  ## Linear unit Kilometer 
  UL_KILOMETER_CONV* = "1000."  ## Linear unit Kilometer conversion factor to meter 
  UL_DECIMETER* = "Decimeter"  ## Linear unit Decimeter 
  UL_DECIMETER_CONV* = "0.1"  ## Linear unit Decimeter conversion factor to meter 
  UL_CENTIMETER* = "Centimeter"  ## Linear unit Decimeter 
  UL_CENTIMETER_CONV* = "0.01"  ## Linear unit Decimeter conversion factor to meter 
  UL_MILLIMETER* = "Millimeter"  ## Linear unit Millimeter 
  UL_MILLIMETER_CONV* = "0.001"  ## Linear unit Millimeter conversion factor to meter 
  UL_INTL_NAUT_MILE* = "Nautical_Mile_International"  ## Linear unit Nautical_Mile_International 
  UL_INTL_NAUT_MILE_CONV* = "1852.0"  ## Linear unit Nautical_Mile_International conversion factor to meter 
  UL_INTL_INCH* = "Inch_International"  ## Linear unit Inch_International 
  UL_INTL_INCH_CONV* = "0.0254"  ## Linear unit Inch_International conversion factor to meter 
  UL_INTL_FOOT* = "Foot_International"  ## Linear unit Foot_International 
  UL_INTL_FOOT_CONV* = "0.3048"  ## Linear unit Foot_International conversion factor to meter 
  UL_INTL_YARD* = "Yard_International"  ## Linear unit Yard_International 
  UL_INTL_YARD_CONV* = "0.9144"  ## Linear unit Yard_International conversion factor to meter 
  UL_INTL_STAT_MILE* = "Statute_Mile_International"  ## Linear unit Statute_Mile_International 
  UL_INTL_STAT_MILE_CONV* = "1609.344"  ## Linear unit Statute_Mile_Internationalconversion factor to meter 
  UL_INTL_FATHOM* = "Fathom_International"  ## Linear unit Fathom_International 
  UL_INTL_FATHOM_CONV* = "1.8288"  ## Linear unit Fathom_International conversion factor to meter 
  UL_INTL_CHAIN* = "Chain_International"  ## Linear unit Chain_International 
  UL_INTL_CHAIN_CONV* = "20.1168"  ## Linear unit Chain_International conversion factor to meter 
  UL_INTL_LINK* = "Link_International"  ## Linear unit Link_International 
  UL_INTL_LINK_CONV* = "0.201168"  ## Linear unit Link_International conversion factor to meter 
  UL_US_INCH* = "Inch_US_Surveyor"  ## Linear unit Inch_US_Surveyor 
  UL_US_INCH_CONV* = "0.025400050800101603"  ## Linear unit Inch_US_Surveyor conversion factor to meter 
  UL_US_YARD* = "Yard_US_Surveyor"  ## Linear unit Yard_US_Surveyor 
  UL_US_YARD_CONV* = "0.914401828803658"  ## Linear unit Yard_US_Surveyor conversion factor to meter 
  UL_US_CHAIN* = "Chain_US_Surveyor"  ## Linear unit Chain_US_Surveyor 
  UL_US_CHAIN_CONV* = "20.11684023368047"  ## Linear unit Chain_US_Surveyor conversion factor to meter 
  UL_US_STAT_MILE* = "Statute_Mile_US_Surveyor"  ## Linear unit Statute_Mile_US_Surveyor 
  UL_US_STAT_MILE_CONV* = "1609.347218694437"  ## Linear unit Statute_Mile_US_Surveyor conversion factor to meter 
  UL_INDIAN_YARD* = "Yard_Indian"  ## Linear unit Yard_Indian 
  UL_INDIAN_YARD_CONV* = "0.91439523"  ## Linear unit Yard_Indian conversion factor to meter 
  UL_INDIAN_FOOT* = "Foot_Indian"  ## Linear unit Foot_Indian 
  UL_INDIAN_FOOT_CONV* = "0.30479841"  ## Linear unit Foot_Indian conversion factor to meter 
  UL_INDIAN_CHAIN* = "Chain_Indian"  ## Linear unit Chain_Indian 
  UL_INDIAN_CHAIN_CONV* = "20.11669506"  ## Linear unit Chain_Indian conversion factor to meter 
  UA_DEGREE* = "degree"  ## Angular unit degree 
  UA_DEGREE_CONV* = "0.0174532925199433"  ## Angular unit degree conversion factor to radians 
  UA_RADIAN* = "radian"  ## Angular unit radian 
  PM_GREENWICH* = "Greenwich"  ## Prime meridian Greenwich 
  DN_NAD27* = "North_American_Datum_1927"  ## North_American_Datum_1927 datum name 
  DN_NAD83* = "North_American_Datum_1983"  ## North_American_Datum_1983 datum name 
  DN_WGS72* = "WGS_1972"  ## WGS_1972 datum name 
  DN_WGS84* = "WGS_1984"  ## WGS_1984 datum name 
  WGS84_SEMIMAJOR* = 6378137.0  ## Semi-major axis of the WGS84 ellipsoid 
  WGS84_INVFLATTENING* = 298.257223563  ## Inverse flattening of the WGS84 ellipsoid. 
  
proc registerAll*() {.cdecl, dynlib: libgdal, importc: "GDALAllRegister".}
  ## Register all known configured GDAL drivers.
  ## This function will drive any of the following that are configured into GDA:
  ## raster list http://gdal.org/formats_list.html, vector list http://gdal.org/ogr_formats.html
  ## This function should generally be called once at the beginning of the application.

proc GDALGetDriverCount*(): int {.cdecl, dynlib: libgdal, importc .}
    ## Return the number of registered drivers

proc GDALGetDriver*(iDriver: cint) : pointer {.cdecl, dynlib: libgdal, importc .}

proc GDALGetDriverShortName*(hDriver: pointer) : cstring {.cdecl, dynlib: libgdal, importc .}

proc GDALGetGeoTransform*(hDS: pointer, transform: ptr float64): int {.cdecl, dynlib: libgdal, importc: "GDALGetGeoTransform".}
    ## Get the affine transform coefficients

proc GDALSetGeoTransform*(hDS: pointer, transform: ptr float64) : cint {.cdecl, dynlib: libgdal, importc .}

proc getGCPCount*(hDS: pointer): cint {.cdecl, dynlib: libgdal, importc: "GDALGetGCPCount".}   
    ## number of GCPs

proc getGCPs*(hDS: pointer): ptr GDAL_GCP {.cdecl, dynlib: libgdal, importc: "GDALGetGCPs".}

proc GDALGetDriverByName*(pszName: cstring) : pointer  {.cdecl, dynlib: libgdal, importc: "GDALGetDriverByName".}

proc GDALGetMetadata*(hDS: pointer, pszDomain: cstring): ptr cstring {.cdecl, dynlib: libgdal, importc: "GDALGetMetadata".}
proc GDALGetMetadataItem*(hD: pointer, pszDomain: cstring, pszItem: cstring) : cstring {.cdecl, dynlib: libgdal, importc .}

proc GDALGetRasterBand*(hDS: pointer, nBandId: cint) : Band {.cdecl, dynlib: libgdal, importc: "GDALGetRasterBand".}

proc GDALGetDataTypeSizeBits*(eDataType: GDALDataType) : cint {.cdecl, dynlib: libgdal, importc: "GDALGetDataTypeSizeBits".}

proc GDALExtractRPCInfoV2*(papszMd: ptr cstring, psRPC: ptr GDALRPCInfoV2): cint {.cdecl, dynlib: libgdal, importc: "GDALExtractRPCInfoV2".}

proc GDALFindDataType* (nBits: cint, bSigned: cint, bFloating: cint, bComplex: cint): GDALDataType {.cdecl, dynlib: libgdal, importc: "GDALFindDataType".}

proc GDALDataTypeUnion*(eType1: GDALDataType, eType2: GDALDataType) : GDALDataType {.cdecl, dynlib: libgdal, importc: "GDALDataTypeUnion".}

proc GDALDatasetRasterIOEx*(hDS: pointer, eRWFlag: GDALRWFlag, nXOff: cint, nYOff: cint,
                            nXSize: cint, nYSize: cint, pData: pointer, 
                            nBufXSize: cint, nBufYSize: cint, 
                            eBufType: GDALDataType, nBandCount: cint, 
                            panBandMap: ptr cint,
                            nPixelSpace: int64, nLineSpace: int64, nBandSpace: int64,
                            psExtraArg: ptr GDALRasterIOExtraArg ) : cint
                            {.cdecl, dynlib: libgdal, importc: "GDALDatasetRasterIOEx".}

proc GDALGetDataTypeName*(eDataType: GDALDataType) : cstring {.cdecl, dynlib: libgdal, importc: "GDALGetDataTypeName".}

proc GDALGetBlockSize*(hBand: Band, xsize: ptr cint, ysize: ptr cint) {.cdecl, dynlib: libgdal,importc: "GDALGetBlockSize".}

proc GDALReadBlock*(hBand: Band, nXBlockOff: cint, bYBlockOff: cint, pImage: pointer) {.cdecl, dynlib: libgdal, importc: "GDALReadBlock".}

proc GDALCreate*(hDriver: pointer, pszFilename: cstring, nXSize: cint, nYSize: cint, nBands: cint, eType: GDALDataType, papszOptions: CSLConstList) : pointer {.cdecl, dynlib: libgdal, importc: "GDALCreate".}

proc GDALCreateCopy*(hDriver: pointer, pszFilename: cstring, hSrsDs: pointer, bStrict: cint, papszOptions: CSLConstList, pfnProgress: GDALProgressFunc, pProgressData: pointer): pointer {.cdecl, dynlib: libgdal, importc .}

proc GDALOpen*(pszFilename: cstring, nOpenFlags: cint, papszAllowedDrivers: cstring, papszOpenOptions: cstring, papszSiblingFiles: cstring): pointer {.cdecl, dynlib: libgdal, importc: "GDALOpenEx".}
  ## Open a raster or vector file as a Dataset.

proc GDALSetProjection*(hDstSrs: pointer, pszProjection: cstring): cint {.cdecl, dynlib: libgdal, importc .}

proc getLayerByName*(hDS: pointer, pszName: cstring): Layer {.cdecl, dynlib: libgdal, importc: "GDALDatasetGetLayerByName".}
  ## Fetch a layer by name.

proc getLayerCount*(hDS: pointer): int32 {.cdecl, dynlib: libgdal, importc: "GDALDatasetGetLayerCount".}
  ## Get the number of layers in this dataset.

proc getLayer*(hDS: pointer, iLayer: int32): Layer {.cdecl, dynlib: libgdal, importc: "GDALDatasetGetLayer".}
  ## Fetch a layer by index.

proc GDALGetRasterDataType*(hBand: Band) : GDALDataType {.cdecl, dynlib: libgdal, importc: "GDALGetRasterDataType".}

proc GDALGetRasterColorInterpretation*(hBand: Band) : GDALColorInterp {.cdecl, dynlib: libgdal, importc: "GDALGetRasterColorInterpretation".}

proc GDALGetRasterXSize*(hDS: pointer): cint {.cdecl, dynlib: libgdal, importc: "GDALGetRasterXSize".}

proc GDALGetRasterYSize*(hDS: pointer): cint {.cdecl, dynlib: libgdal, importc: "GDALGetRasterYSize".}

proc GDALGetRasterCount*(hDS: pointer): cint {.cdecl, dynlib: libgdal, importc: "GDALGetRasterCount".}

proc resetReading*(hLayer: Layer) {.cdecl, dynlib: libgdal, importc: "OGR_L_ResetReading".}
  ## Reset feature reading to start on the first feature.

proc getNextFeature*(hLayer: Layer): Feature {.cdecl, dynlib: libgdal, importc: "OGR_L_GetNextFeature".}
  ## Fetch the next available feature from this layer.

proc getLayerDefn*(hLayer: Layer): FeatureDefn {.cdecl, dynlib: libgdal, importc: "OGR_L_GetLayerDefn".}
  ## Fetch the schema information for this layer.
  
proc getFieldCount*(hDefn: FeatureDefn): int32 {.cdecl, dynlib: libgdal, importc: "OGR_FD_GetFieldCount".}
  ## Fetch number of fields on this feature.

proc getFieldDefn*(hDefn: FeatureDefn, iField: int32): FieldDefn {.cdecl, dynlib: libgdal, importc: "OGR_FD_GetFieldDefn".}
  ## Fetch field definition of the passed feature definition.

proc getFieldIndex*(hDefn: FeatureDefn, pszFieldName: cstring): int32 {.cdecl, dynlib: libgdal, importc: "OGR_FD_GetFieldIndex".}
  ## Find field by name.

proc getType*(hDefn: FieldDefn): FieldType {.cdecl, dynlib: libgdal, importc: "OGR_Fld_GetType".}
  ## Fetch type of this field.

proc getFieldAsInteger*(hFeat: Feature, iField: int32): int32 {.cdecl, dynlib: libgdal, importc: "OGR_F_GetFieldAsInteger".}
  ## Fetch field value as int32.

proc getFieldAsInteger64*(hFeat: Feature, iField: int32): int {.cdecl, dynlib: libgdal, importc: "OGR_F_GetFieldAsInteger64".}
  ## Fetch field value as int64.

proc getFieldAsString*(hFeat: Feature, iField: int32): cstring {.cdecl, dynlib: libgdal, importc: "OGR_F_GetFieldAsString".}
  ## Fetch field value as cstring.

proc getFieldAsDouble*(hFeat: Feature, iField: int32): float {.cdecl, dynlib: libgdal, importc: "OGR_F_GetFieldAsDouble".}
  ## Fetch field value as float32.

proc getGeometryRef*(hFeat: Feature): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_F_GetGeometryRef".}
  ## Fetch an handle to feature geometry.

proc getGeometryRef*(hGeom: Geometry, iSubGeom: int32): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_GetGeometryRef".}
  ## Fetch geometry from a geometry container.

proc getGeometryType*(hGeom: Geometry): GeometryType {.cdecl, dynlib: libgdal, importc: "OGR_G_GetGeometryType".}
  ## Fetch geometry type.

proc getX*(hGeom: Geometry, i: int32): float {.cdecl, dynlib: libgdal, importc: "OGR_G_GetX".}
  ## Fetch the x coordinate of a point from a geometry.

proc getY*(hGeom: Geometry, i: int32): float {.cdecl, dynlib: libgdal, importc: "OGR_G_GetY".}
  ## Fetch the y coordinate of a point from a geometry.

proc getZ*(hGeom: Geometry, i: int32): float {.cdecl, dynlib: libgdal, importc: "OGR_G_GetZ".}
  ## Fetch the z coordinate of a point from a geometry.

proc getGeomFieldCount*(hFeat: Feature): int32 {.cdecl, dynlib: libgdal, importc: "OGR_F_GetGeomFieldCount".}
  ## Fetch number of geometry fields on this feature.

proc getGeomFieldRef*(hFeat: Feature, iField: int32): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_F_GetGeomFieldRef".}
  ## Fetch an handle to feature geometry.

proc destroy*(hFeat: Feature) {.cdecl, dynlib: libgdal, importc: "OGR_F_Destroy".}
  ## Destroy feature

proc close*(hDS: pointer) {.cdecl, dynlib: libgdal, importc: "GDALClose".}
  ## Close GDAL dataset


proc flatten*(eType: GeometryType): GeometryType {.cdecl, dynlib: libgdal, importc: "OGR_GT_Flatten".}
  ## Returns the 2D geometry type corresponding to the passed geometry type.

proc getProjectionRef*(hDS: pointer): cstring {.cdecl, dynlib: libgdal, importc: "GDALGetProjectionRef".}
  ## Fetch the projection definition string for this dataset.

proc GDALGetSpatialRef*(hDS: pointer) : SpatialReference {.cdecl, dynlib: libgdal, importc .}

proc GDALSetSpatialRef*(hDS: pointer, hSrs: pointer) : cint {.cdecl, dynlib: libgdal, importc .}

proc GDALGetGCPSpatialRef*(hDS: pointer) : SpatialReference {.cdecl, dynlib: libgdal, importc .}

proc GDALGetSpatialReference*(hGeom: Geometry): SpatialReference {.cdecl, dynlib: libgdal, importc: "OGR_G_GetSpatialReference".}
  ## Returns spatial reference system for geometry.

proc intersection*(hThis, hOther: Geometry): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_Intersection".}
  ## Compute intersection.

proc intersects*(hThis, hOther: Geometry): int {.cdecl, dynlib: libgdal, importc: "OGR_G_Intersects".}
  ## Do the features intersect?

proc length*(hGeom: Geometry): float {.cdecl, dynlib: libgdal, importc: "OGR_G_Length".}
  ## Compute length of a curve geometry.

proc overlaps*(hThis, hOther: Geometry): int {.cdecl, dynlib: libgdal, importc: "OGR_G_Overlaps".}
  ## Test for overlap.

proc pointOnSurface*(hGeom: Geometry): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_PointOnSurface".}
  ## Returns a point guaranteed to lie on the geometry.

proc touches*(hThis, hOther: Geometry): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_Touches".}
  ## Test for touching

proc value*(hGeom: Geometry, dfDistance: float): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_Value".}
  ## Fetch point at given distance along curve.

proc getName*(hLayer: Layer): cstring {.cdecl, dynlib: libgdal, importc: "OGR_L_GetName".}
  ## Return the layer name.

proc getSpatialRef*(hLayer: Layer): SpatialReference {.cdecl, dynlib: libgdal, importc: "OGR_L_GetSpatialRef".}
  ## Fetch the spatial reference system for this layer.

proc exportToProj4*(hSRS: SpatialReference, ppszReturn: cstring): int32 {.cdecl, dynlib: libgdal, importc: "OSRExportToProj4".}
  ## Export coordinate system in PROJ.4 format.

proc exportSRToWkt*(hSRS: SpatialReference, ppszReturn: cstringArray): int32 {.cdecl, dynlib: libgdal, importc: "OSRExportToWkt".}
  ## Convert this SRS into WKT format.

proc distance*(hFirst, hOther: Geometry): float {.cdecl, dynlib: libgdal, importc: "OGR_G_Distance".}
  ## Compute distance between two geometries.

proc distance3D*(hFirst, hOther: Geometry): float {.cdecl, dynlib: libgdal, importc: "OGR_G_Distance3D".}
  ## Returns 3D distance between two geometries.

proc createGeometry*(gType: GeometryType): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_CreateGeometry".}
  ## Create an empty geometry of indicated type.

proc setPoint2D*(hGeom: Geometry, i: int32, dfX, dfY: float) {.cdecl, dynlib: libgdal, importc: "OGR_G_SetPoint_2D".}
  ## Set the location of a vertex in a point or linestring geometry. i is the index of the vertex to assign (zero based) or zero for a point.

proc setPoint*(hGeom: Geometry, i: int, dfX, dfY, dfZ: float) {.cdecl, dynlib: libgdal, importc: "OGR_G_SetPoint".}
  ## Set the location of a vertex in a point or linestring geometry.

proc getPointCount*(hGeom: Geometry): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_GetPointCount".}
  ## Fetch number of points from a geometry.

proc getPoint*(hGeom: Geometry, i: int32, pdfX, pdfY, pdfZ: var float) {.cdecl, dynlib: libgdal, importc: "OGR_G_GetPoint".}
  ## Fetch a point in line string or a point geometry.

proc forceToLineString*(hGeom: Geometry): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_ForceToLineString".}
  ## Convert to line string.

proc setAttributeFilter*(hLayer: Layer, query: cstring): int32 {.cdecl, dynlib: libgdal, importc: "OGR_L_SetAttributeFilter".}
  ## Set a new attribute query.

proc getFeature*(hLayer: Layer, fId: int): Feature {.cdecl, dynlib: libgdal, importc: "OGR_L_GetFeature".}
  ## Fetch a feature by its identifier.

proc getFeatureCount*(hLayer: Layer, fId: int): int {.cdecl, dynlib: libgdal, importc: "OGR_L_GetFeatureCount".}
  ## Fetch the feature count in this layer.

proc importFromEPSG*(hSRS: SpatialReference, nCode: int32): int32 {.cdecl, dynlib: libgdal, importc: "OSRImportFromEPSG".}
  ## Initialize SRS based on EPSG GCS or PCS code.

proc newCoordinateTransformation*(sourceSRS, targetSRS: SpatialReference): CoordinateTransformation {.cdecl, dynlib: libgdal, importc: "OCTNewCoordinateTransformation".}
  ## Create transformation object

proc transform*(hGeom: Geometry, hTransform: CoordinateTransformation): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_Transform".}
  ## Apply arbitrary coordinate transformation to geometry.

proc transformTo*(hGeom: Geometry, hSRS: SpatialReference): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_TransformTo".}
  ## Transform geometry to new spatial reference system.

proc newSpatialReference*(pszWKT: cstring): SpatialReference {.cdecl, dynlib: libgdal, importc: "OSRNewSpatialReference".}
  ## Constructor.

proc getGeometryCount*(hGeom: Geometry): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_GetGeometryCount".}
  ## Fetch the number of elements in a geometry or number of geometries in container.

proc clone*(hGeom: Geometry): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_Clone".}
  ## Make a copy of this object.

proc getGeometryName*(hGeom: Geometry): cstring {.cdecl, dynlib: libgdal, importc: "OGR_G_GetGeometryName".}
  ## Fetch WKT name for geometry type.

proc exportToWkt*(hGeom: Geometry, ppszSrcText: pointer): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_ExportToWkt".}
  ## Convert a geometry into well known text format.

proc getCurveGeometry*(hGeom: Geometry, p: pointer): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_GetCurveGeometry".}
  ## Return curve version of this geometry. p must be set to nil for now.

proc hasCurveGeometry*(hGeom: Geometry, nonLinear: int32): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_HasCurveGeometry".}
  ## Returns if this geometry is or has curve geometry.

proc isSimple*(hGeom: Geometry): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_IsSimple".}
  ## Returns TRUE if the geometry is simple.

proc isValid*(hGeom: Geometry): int32 {.cdecl, dynlib: libgdal, importc: "OGR_G_IsValid".}
  ## Returns TRUE if the geometry is valid.

proc getLinearGeometry*(hGeom: Geometry, deg: float, opts: cstringArray): Geometry {.cdecl, dynlib: libgdal, importc: "OGR_G_GetLinearGeometry".}
  ## Return, possibly approximate, linear version of this geometry.
  ## deg is the largest step in degrees along the arc, zero to use the default setting.


# helper procs

iterator features*(layer: Layer): Feature =
  var res: Feature
  while true:
    res = layer.getNextFeature()
    if isNil(res):
      break
    yield res

proc getFieldType*(fdefn: FeatureDefn, i: int32): FieldType =
  var fd = fdefn.getFieldDefn(i)
  return fd.getType()

proc getStringField*(f: Feature, fdefn: FeatureDefn, field: string): cstring =
  var index = fdefn.getFieldIndex(cstring(field))
  return f.getFieldAsString(index)

proc point2d*(x, y: float): Geometry =
  ## Point constructor
  result = createGeometry(Point)
  result.setPoint2D(0, x, y)

proc pointi2d*(g: Geometry, i: int32): Geometry =
  ## Point constructor
  var x, y, z: float
  g.getPoint(i, x, y, z)
  result = point2d(x, y)

proc wkt*(geom: Geometry): string =
  var
    dummy: array[1, string]
    wktA = dummy.allocCStringArray
  discard exportToWkt(geom, wktA)
  result = wktA.cstringArrayToSeq()[0]
  wktA.deallocCStringArray()

type
  GEOSContextHandle = pointer
  GEOSGeom = pointer

proc initGEOS(): GEOSContextHandle {.cdecl, dynlib: libgdal, importc: "initGEOS_r".}

proc fromWKT(ctx: GEOSContextHandle, wkt: cstring): GEOSGeom {.cdecl, dynlib: libgdal, importc: "GEOSGeomFromWKT_r".}

proc finishGEOS(ctx: GEOSContextHandle) {.cdecl, dynlib: libgdal, importc: "finishGEOS_r".}

proc Project(ctx: GEOSContextHandle, g, p: GEOSGeom): float {.cdecl, dynlib: libgdal, importc: "GEOSProject_r".}

proc project*(g, p: Geometry): float =
  ## project a point p onto a LINESTRING or MULTILINESTRING geometry g.
  ## EXPERIMENTAL.
  ## returns distance of point 'p' projected on 'g' from origin of 'g'. Geometry 'g' must be a linear geometry
  let
    ctx = initGEOS()
    gwkt = g.wkt()
    pwkt = p.wkt()
    gg = ctx.fromWKT(gwkt.cstring)
    gp = ctx.fromWKT(pwkt.cstring)
  result = ctx.Project(gg, gp)
  ctx.finishGEOS()

