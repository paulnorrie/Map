import tables, raster

type  
  BandDataPtr* = pointer
  
  
  BSQData*[T] = Table[char, Table[ValidBandOrdinal, seq[T]]]

#const hasNoBand*: BandOrdinalType = 0
## A variable is a vector variable without a band, e.g. "A", "D"