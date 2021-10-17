import unittest, random, tables, std/monotimes, sequtils, macros
import geomap/calc, geomap/calctypes

#proc calcProc[S, D]( 
#  `expr`: static[string],
#  bandCounts: static seq[int], # only needed if image with no bands included
#  src: BSQData[S],
#  dst: var seq[var seq[D]]) =
#
#  dumpTree:
#    var 
#      A1, B2:S        # sources
#      imageId: char
#      bandOrd: uint16
#    for pixelIx in 0..(dst[0].len - 1):   # for each pixel
#      imageId = 'A'
#      bandOrd = 1
#      A1 = src[imageId][bandOrd][pixelIx]
#
#      imageId = 'B'
#      bandOrd = 2
#      B2 = src[imageId][bandOrd][pixelIx]      
#
#      for dstBandOrd in 0 ..< dst.len:  # TODO: does compiler unroll? should we have a case for countDstBands = 1 (the most common case)
#        dst[dstBandOrd][pixelIx] = cast[D](A1 + B2)

test "Reference same variable multiple times: A1 + A2 div A1":
  var a1 = @[16, 17, 18]
  var a2 = @[32, 33, 34]
  var src = {'A': band({1: a1, 2: a2}) }.toTable()
  
  #var dst = newSeq[seq[int]](1)
  #dst[0] = newSeq[int](3)
  #var dst = newSeq[int](3)
  #expandMacros:
  #calc("A1 + A2 div A1", @[2], src, dst, "int", "int")
  let dst = calc("A1 + A2 div A1", src, int)
  check dst == @[18, 18, 19]

#test "In-place (dst=src): A1 + 1":
#  var a1 = @[1, 2, 3]
#  var src = {'A': BSQBand(1, a1)}.toTable()
#  #expandMacros:
#  calc("A1 + 1", src, a1)
#  check a1 == @[2, 3, 4]


#test "performance":
#  # performance of calculation on 1980 x 1080 pixel images
#  const countPixels = 1980 * 1080
#
#  # random data for bands A1 and B1
#  var a1 = newSeq[uint8](countPixels)
#  var b1 = newSeq[uint8](countPixels)
#  for pixel in 0..(countPixels-1):
#    let val = uint8(rand(0..255))
#    a1[pixel] = val
#    b1[pixel] = val
#
#  var src = {'A': {1'u16: a1}.toTable(), 
#             'B': {1'u16: b1}.toTable() }.toTable()
#  var dst = newSeq[uint8](countPixels)
#  
#  var start = getMonoTime()
#  calc("A1 + B1", @[1,1], src, dst, "uint8", "uint8")
#  var stop = getMonoTime()
#  echo (stop - start)
#  #calc("A1 + A1", @[1], src, dst, "int", "int")


