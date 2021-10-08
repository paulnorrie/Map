## Parsing calculation expressions
##
## Call `bindToBands(expr)`to get an `ExprInfo` object which you can interrogate
## by calling other procedures.
## 
## Limitations:
##    
## - No more than 26 images are supported (images A-Z)
## - No image with more than 65,535 bands is supported

import strformat, strutils, tables, typetraits

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
        ## Information about a variable in an expression
        ident*: string
        imageOrd*: uint8
        imageId*: char
        bandOrd*: uint16

    ExprInfo* = object
        ## Information about an expression
        exprRepr*: string
        imageOrds: set[uint8]
        imageIdents: set[char]
        bandOrdsForImage: Table[uint8, set[uint16]]
        vars: seq[VarInfo]

proc constructExprInfo() : ExprInfo {.inline.} =
    ## Create a new ExprInfo object
    var info: ExprInfo
    return info


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



proc bandOrdinalsFor*(info: ExprInfo, imageOrdinal: uint8): set[uint16] {.inline.} =
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
    ## No band num returns 0 (e.g. B -> 0)
    if value.len == 1: return 0
    
    let bandOrdStr = value[1..^1]
    try:
        let bandOrd = parseUInt bandOrdStr
        if bandOrd > 65535:
            raise new ValueError
        return uint16 bandOrd 
    except:
        raise newException(
            ValueError,
            fmt"Expected variable with digit band identifier [1-9]. Got band '{bandOrdStr}' in variable '{value}'"
            )
    
    

func findVars*(s: string) : seq[string] {. inline .} =
    ## Find variables of the form \b[A-Z][0-9]*\b without using regex.
    var vars = newSeq[string]()
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
            vars.add(currentVar)
            currentVar = ""
        else:
            # not a variable or no longer a variable
            currentVar = ""
 
    # add last var if needed   
    if currentVar.len != 0:
        vars.add(currentVar)
    
    return vars



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
    
    var info = constructExprInfo()
    info.exprRepr = `expr`
    
    # This function may be called at compile time. Nim does not support cast[]
    # (or FFI) at compile time so using the (impure) regex library causes
    # "Error: VM does not support 'cast' from tySet to tyInt32" on compile.
    # So we parse manually.
    
    #let regex = re(r"\b[A-Z][0-9]*\b")
    #let variables = `expr`.findAll(regex)

    let variables = `expr`.findVars()

    for variable in variables:

        # image number (e.g. A -> 0)
        let imageOrd = parseVarForImageOrdinal(variable)
        if imageOrd >= uint8 bandCounts.len: #number of images
            raise newException(
                ValueError,
                "No image is provided for " & variable[0] & " in " & " variable"
                )
        let imageId = variable[0]
        info.addImage(imageOrd, imageId)
         
        # add band(s)
        let bandOrd = parseVarForBandOrdinal(variable)
        if bandOrd > uint16 bandCounts[imageOrd]:
            raise newException(
                ValueError,
                "Invalid band " & $bandOrd & " for Image " & imageId & 
                ". Image has " & $bandCounts[imageOrd] & " bands." #bands in a particular image
                )
         
        if bandOrd == 0:
             # use all bands for this image
             let series = toSet 1'u16..uint16 bandCounts[imageOrd] #same
             info.bandOrdsForImage[imageOrd] = series
             
             # add multiple IdentInfo objects
             for b in 1'u16..uint16 bandCounts[imageOrd]:
                var ident: VarInfo
                ident.ident = imageId & $b
                ident.imageOrd = imageOrd
                ident.imageId = imageId
                ident.bandOrd = b
                info.vars.add(ident)
        else:
             # add specified band
             info.bandOrdsForImage[imageOrd].incl(bandOrd)

             # add the IdentInfo object
             var ident: VarInfo
             ident.ident = imageId & $bandOrd
             ident.imageOrd = imageOrd
             ident.imageId = imageId
             ident.bandOrd = bandOrd
             info.vars.add(ident)
    
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
    
    
