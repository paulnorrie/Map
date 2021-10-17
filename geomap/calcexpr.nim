## Parsing calculation expressions
##
## Call `bindToBands(expr)`to get an `ExprInfo` object which you can interrogate
## by calling other procedures.
## 
## Limitations:
##    
## - No more than 26 images are supported (images A-Z)
## - No image with more than 65,535 bands is supported

import tables, typetraits, sets, strutils, strformat
import calctypes

template toSet*(iter: untyped): untyped =
  ## Returns a built-in set from the elements of the iterable `iter`.
  runnableExamples:
    assert "helloWorld".toSet == {'W', 'd', 'e', 'h', 'l', 'o', 'r'}
    assert toSet([10u16, 20, 30]) == {10u16, 20, 30}
    assert [30u8, 100, 10].toSet == {10u8, 30, 100}
    assert toSet(@[1321i16, 321, 90]) == {90i16, 321, 1321}
    assert toSet([false]) == {false}
    assert toSet(0u8..10) == {0u8..10}

  var result: set[elementType(iter)]
  for x in iter:
    incl(result, x)
  result


type        
    VarInfo* = object
        ## Information about an (expanded) variable in an expression.
        ## Expanded variables always have a band ordinal
        ident*: string
            ## the identifier of the variable (e.g. A1, B)
        imageOrd*: uint8
            ## the index of the image data this variable is bound to
        imageId*: char
            ## the identifier of the image only without the band
        bandOrd*: BandOrd
            ## the band ordinal of this variable

    ExprInfo* = object
        ## Information about an assignment sexpression
        exprRepr*: string
            ## the expression represented as a string
        vector: bool
        imageOrds: set[uint8]
        imageIdents: set[char]
        bandOrdsForImage: Table[uint8, set[BandOrd]]
        vars: seq[VarInfo]



proc addImage(info: var ExprInfo, imageOrd: uint8, imageId: char) =
    ## Adds an Image ordinal and id to ExprInfo
    info.imageOrds.incl(imageOrd)
    info.imageIdents.incl(imageId)
    discard info.bandOrdsForImage.hasKeyOrPut(imageOrd, {})



proc imageIds*(info: ExprInfo): set[char] {.inline.} =
    ## What are the identifiers of the images used in an expression. 
    ## The expression is previously parsed by `parse`.
    ## 
    ## E.g. for the expression `A1 + B1` īmageIds` returns `['A', 'B']`
    return info.imageIdents



proc imageOrdinals*(info: ExprInfo): set[uint8] {.inline.} =
    ## What are the ordinals of the images used in an expression. 
    ## The expression is previously parsed by `parse`.
    ## 
    ## E.g. for the expression `A1 + B1` `imageOrdinals` returns `[0, 1]`
    return info.imageOrds



proc bandOrdinalsFor*(info: ExprInfo, imageOrdinal: uint8): set[BandOrd] {.inline.} =
    ## What are the ordinals of the bands of an image used in an expression.
    ## The expression is previously parsed by `parse`.
    ## 
    ## E.g. for the expression A1 + A2 / B3 + B4` `bandOrdinalsFor(1)` 
    ## returns `[3, 4]`
    return info.bandOrdsForImage[imageOrdinal]
    


proc variables*(info: ExprInfo): seq[VarInfo] {.inline.} =
    ## The identifiers of the variables in an expression.
    ## The expression is previously parsed by `parse`.
    return info.vars


proc isScalar*(info: ExprInfo): bool {.inline.} =
    ## The expression in `info` is scalar if all variables specify a band
    ## e.g. "A1 + A2 / B1 + B2" is scalar while "A / 2" is not.
    return not info.vector

proc isVector*(info: ExprInfo): bool {.inline.} =
    ## The expression in `info` is vector if at least one variable specifies
    ## all bands
    ## e.g. "A / 3" is a vector expression
    return info.vector

func parseVarForImageOrdinal(value: string) : uint8  {.inline.} =
    ## A2 -> 0, D33 -> 3, B -> 1
    if not value[0].isAlphaAscii():
        raise newException(
            ValueError,
            fmt"Expected variable with alphabetic image identifier [A-Z]. Got {value[0]} in {value}"
            )
                
    let imageOrd = int(value[0].toUpperAscii()) - 65
    return uint8(imageOrd)



func parseVarForBandOrdinal(value: string) : uint16  {.inline.} =
    ## B1 -> 1, A2 -> 2, D69 -> 69, ...
    ## if value is just a letter, than returns 0 indicating all bands in that
    ## image should be used
    
    if value.len == 1: return 0

    let bandOrdStr = value[1..^1]
    try:
        let bandOrd = parseUInt bandOrdStr
        if bandOrd > high(BandOrd):
            raise new ValueError
        return uint16 bandOrd 
    except:
        raise newException(
            ValueError,
            fmt"Expected variable with digit band identifier [1-65535]. Got band '{bandOrdStr}' in variable '{value}'"
            )
    
    

func findVarIdents(s: string) : HashSet[string] =
    ## Find variable identifiers of the form \b[A-Z][0-9]*\b without using regex.
    
    # We don't use regex because this function may be called at compile time. 
    # Nim does not support cast[]
    # or FFI at compile time so using the (impure) regex library causes
    # "Error: VM does not support 'cast' from tySet to tyInt32" on compile.

    var vars = initHashSet[string]()
    var currentVar: string
    for i in 0..(s.len - 1):
        let c = s[i]
        let isVarStart = c.isUpperAscii() and currentVar.len == 0
        let doesVarContinue = currentVar.len != 0 and c.isDigit() 
        if isVarStart:
            # could be a variable
            currentVar.add(c)
        elif doesVarContinue:
            # still appears to be a variable
            currentVar.add(c)
        elif currentVar.len != 0:
            # finished a variable
            vars.incl(currentVar)
            currentVar = ""
        else:
            # not a variable or no longer a variable
            currentVar = ""
 
    # add last var if needed   
    if currentVar.len != 0:
        vars.incl(currentVar)
    
    return vars



proc isVector*(`expr`: string) : bool =
    ## Is a given expression a vector expression, i.e. at least one image variable
    ## references all band numbers (e.g. 'A', 'B')
    var isVector: bool
    let idents = `expr`.findVarIdents()
    for ident in idents:
        let bandOrd = parseVarForBandOrdinal(ident)
        if bandOrd == 0:
            isVector = true
            break; 
    return isVector;



proc isScalar*(`expr`: string) : bool {. inline .} =
    ## Is a given expression a scalar expression, i.e. all variables reference
    ## a band number (e.g. 'A1', 'B3')
    return not isVector(`expr`)



proc isVarIdentAVector(ident: string) : bool {. inline .} =
    ## Is a variable identifier a vector referencing multiple bands
    ## e.g. 'A'  => true
    ##      'A1' => false
    let bandOrd = parseVarForBandOrdinal(ident)
    return bandOrd == 0



proc expandVarIdents(idents: HashSet[string], bandCounts: seq[int]) : HashSet[string] =
    ## Expand variable identifiers if needed (e.g. ['A', 'B1'] -> ['A1', 'A2', 'B1'])
    var newIdents = initHashSet[string]()
    for ident in idents:
        if ident.isVarIdentAVector():
            # expand
            let imageOrd = parseVarForImageOrdinal(ident)
            let imageId = ident[0]
            for bandOrd in 1'u16..uint16 bandCounts[imageOrd]:
                newIdents.incl(imageId & $imageOrd)
        else:
            newIdents.incl(ident)
    return newIdents


    
func bindToBands*(`expr`: string, bandCounts: seq[int]) : ExprInfo {.raises: [ValueError].}  =
    ## Bind the variables in `expr` to a band in an image.
    ## 
    ## Variables in `expr` are of the form:
    ## `[A-Z](1-9)` where:
    ## -  a letter A-Z is an image
    ## -  a digit 1-65535 is a band in the image, or if missing, all bands
    ## 
    ## `bandCounts[0..25]` has the number of bands for images A..Z.  Each 
    ## variable in `expr` must reference one or more bands in an image.
    ## 
    ## 
    ## If `expr` contains an image or band number that is not available in
    ## `maps`, then a `ValueError` is raised.
    
    var info: ExprInfo
    info.exprRepr = `expr`
    
    # get all variable identifiers with their band ordinals. i.e. all identifiers
    # should be scalar.
    var idents = `expr`.findVarIdents()          # may be scalar and vector
    idents = expandVarIdents(idents, bandCounts) # now they are all scalar

    for ident in idents:

        # image number (e.g. A -> 0)
        let imageOrd = parseVarForImageOrdinal(ident)
        if imageOrd >= uint8 bandCounts.len: #number of images
            raise newException(
                ValueError,
                "No image is provided for " & ident[0] & " in " & " variable"
                )
        let imageId = ident[0]
        info.addImage(imageOrd, imageId)
         
        # add band(s)
        let bandOrd = parseVarForBandOrdinal(ident)
        if bandOrd > uint16 bandCounts[imageOrd]:
            raise newException(
                ValueError,
                "Invalid band " & $bandOrd & " for Image " & imageId & 
                ". Image has " & $bandCounts[imageOrd] & " bands." #bands in a particular image
                )
         
        info.bandOrdsForImage[imageOrd].incl(bandOrd)
        # add the IdentInfo object
        var variable = VarInfo(bandOrd: bandOrd)
        variable.ident = imageId & $bandOrd
        variable.imageOrd = imageOrd
        variable.imageId = imageId
        info.vars.add(variable)
    
    return info

#proc bindToBands*(`expr`: string, maps: varargs[Map]) :
# ExprInfo {.raises: [ValueError].}  =
#    ## Parse the variables in `expr` that reference `maps` into a form 
#    ## ready to be used for calculations.
#    ## 
#    ## Variables in `expr` are of the form:
#    ## `[A-Z](1-9)` where:
#    ## -  a letter A-Z is an image
#    ## -  a digit 1-9 is a band in the image, or if missing, all bands
#    ## 
#    ## Each variable must reference a `Map`.  Images A-Z reference `maps[0]`
#    ## to `maps[25]`respectively.  A given band for a variable must exist in 
#    ## it's `Map`.
#    ## 
#    ## If `expr` contains an image or band number that is not available in
#    ## `maps`, then a `ValueError` is raised.
#    
#    var info = constructExprInfo()
#    
#    for kind, value in `expr`.interpolatedFragments():
#        if kind == ikVar:
#
#            # image number (e.g. A -> 0)
#            let imageOrd = parseVarForImageNum(value)
#            if imageOrd >= uint8 maps.len: #number of images
#                raise newException(
#                    ValueError,
#                    fmt"No image is provided for {value[0]} in ${value}"
#                    )
#            let imageId = value[0]
#            info.addImage(imageOrd, imageId)
#            
#            # add band(s)
#            let bandOrd = parseVarForBandNum(value)
#            if bandOrd > uint16 maps[imageOrd].numBands:
#                raise newException(
#                    ValueError,
#                    "Invalid band " & $bandOrd & " for Image " & imageId & 
#                    ". Image has " & $maps[imageOrd].numBands & " bands." #bands in a particular image
#                    )
#            
#            if bandOrd == 0:
#                 # use all bands for this image
#                 let series = toSet 1'u16..uint16 maps[imageOrd].numBands #same
#                 info.bandOrdsForImage[imageOrd] = series
#                 
#                 # add multiple IdentInfo objects
#                 for b in 1'u16..uint16 maps[imageOrd].numBands:
#                    var ident: VarInfo
#                    ident.ident = '$' & imageId & $b
#                    ident.imageOrd = imageOrd
#                    ident.imageId = imageId
#                    ident.bandOrd = b
#                    info.vars.add(ident)
#            else:
#                 # add specified band
#                 info.bandOrdsForImage[imageOrd].incl(bandOrd)
#
#                 # add the IdentInfo object
#                 var ident: VarInfo
#                 ident.ident = '$' & imageId & $bandOrd
#                 ident.imageOrd = imageOrd
#                 ident.imageId = imageId
#                 ident.bandOrd = bandOrd
#                 info.vars.add(ident)
#    
#    return info
    
    
