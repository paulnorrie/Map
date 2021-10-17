import unittest
import geomap/calcexpr

#test "bindToBands A with 4 bands":
#
#    # check expr info
#    let info = bindToBands("A", @[2])
#    check info.imageIds() == {'A'}
#    check info.imageOrdinals() == {0'u8}
#    check info.bandOrdinalsFor(0) == {1'u16, 2'u16}
#    
#    # check variable A1
#    var variable = info.variables()[0]
#    check variable.ident == "A1"
#    check variable.imageId == 'A'
#    check variable.imageOrd == 0
#    check variable.bandOrd == 1
#
#    # check variable A2
#    variable = info.variables()[1]
#    check variable.ident == "A2"
#    check variable.imageId == 'A'
#    check variable.imageOrd == 0
#    check variable.bandOrd == 2
#
#
#
#test "bindToBands A2/C3 - 10":
#    # check expr info
#    let info = bindToBands("A2/C3 - 10", @[3,3,3])
#    check info.imageIds() == {'A', 'C'}
#    check info.imageOrdinals() == {0'u8, 2'u8}
#    check info.bandOrdinalsFor(0) == {1'u16, 2'u16, 3'u16}
#    check info.bandOrdinalsFor(1) == {1'u16, 2'u16, 3'u16}
#    check info.bandOrdinalsFor(2) == {1'u16, 2'u16, 3'u16}
#    
#    # check variable A2
#    var variable = info.variables()[0]
#    check variable.ident == "A2"
#    check variable.imageId == 'A'
#    check variable.imageOrd == 0
#    check variable.bandOrd == 2
#
#    # check variable C3
#    variable = info.variables()[1]
#    check variable.ident == "C3"
#    check variable.imageId == 'C'
#    check variable.imageOrd == 2
#    check variable.bandOrd == 3
