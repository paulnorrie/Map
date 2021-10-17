import tables

type 
  ImageIdType = char
  BandOrdinalType = uint16
  BandDataPtr = pointer
  BandOrd* = range[1'u16 .. high(uint16)]
        ## Band Ordinal is the number of the band that ranges 1..65535
  BSQData*[T] = Table[char, Table[BandOrd, seq[T]]]
