#roc calc*(`expression`: string, rasters: Table[string, Raster], dst: Raster) =
# ## Calculate an expression referencing multiple rasters and return the result.
# ## 
# ## Rasters A..Z are provided in `rasters[0]..rasters[25]`, i.e. raster "B" is
# ## `rasters[1]`.

#if expression.isVector():
#    raise newException(ValueError, 
#                      "Expected expression to be scalar, but is vector.  " &
#                      "Add band ordinals to the variables.")
# var dataType: RasterDataType = none
# 
# var vectors: Table[string, UnsafeSeq[uint8]] #TODO: data type at runtime
# 
# let variables = expression.findVarIdents()
#
# # arrange band data into sequences
# for varIdent in variables.items():
#   
#   # which raster matches this variable?
#   #let varInfo = parseImageAndBandId(varIdent)
#   let raster = rasters[varIdent] 
#
#   # all raster bands must have same data type
#   if (dataType == none):
#     dataType = raster.meta.bandDataType
#
#   if raster.meta.bandDataType != dataType:
#     raise newException(
#                       ValueError,
#                       "All raster bands must have the same data type.")
#   
#   # sequence of data depends on the raster interleaving
#   case raster.interleave
#   of BIP:
#     echo "TBD"
#   of BIL:
#     echo "TBD"
#   of BSQ:
#     
#     let typedData = cast[ptr uint8](raster.data)
#     let len = raster.meta.width * raster.meta.height
#     let useq = initUnsafeSeq[uint8](typedData, len)
#     vectors[varIdent] = useq
#     echo "TDB"
# 
# # TODO: multi-threads
# #evaluateScalar(expression, vectors, dst)
