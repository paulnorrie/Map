## Arithmetic calculations on contiguous memory.  This module is for when the
## arithmetic expression (e.g. "A + B") is known at compile-time.  This allows
## the compiler to generate code that uses SIMD instructions if possible.  Even
## if not, there is no runtime expression parsing so it is faster.
## 
## To use this module, call the `evaluateScalar` macro.
## 
## SIMD Instructions
## ------------------
## C/C++ Compilers do a good job of auto-vectorising this code with SIMD .
## instructions.
## You may need to compile with auto-vectorisation arguments by using
## the `--passC:`compiler argument to pass to the C/C++ compiler.  
## 
## `--passC:-O3` forces maximum optimisation and by default
##      uses the architecture on the compiling machine to determine
##      whether MMX, MMX2, AVX, AVX2, etc is used.
## 
## `--passC:-m{mmx, sse, sse2, sse3, ssse3, sse4.1, avx}` instructs the
##      compiler to emit the relevant SIMD instructions
##      e.g `--passC:-mavx`
## 
## see `GCC Intel 386 and AMD x86-64 Options 
## <https://gcc.gnu.org/onlinedocs/gcc-4.5.3/gcc/i386-and-x86_002d64-Options.html>`_
##  or `Clang Command Line Argument Reference 
## <https://clang.llvm.org/docs/ClangCommandLineReference.html>`_
## 
## 
  
import std/tables, std/random, std/macros, sets, strformat, typetraits, math
import calcexpr, ../geomap

type 
  UnsafeSeq*[T] {.requiresInit.} = object
    ## If you have only a pointer, type & length instead of a sequence, you can
    ## use UnsafeSeq in calls instead of seq.  While UnsafeSeq is 
    ## memory unmanaged by nim, it does have bounds checking.
    ## 
    ## Create an instance of UnsafeSeq by calling `initUnsafeSeq`
    len: int
    data: ptr[T]

proc initUnsafeSeq*[T](data: ptr[T], len: int) : UnsafeSeq =
  ## Create an UnsafeSeq
  UnsafeSeq(data: data, len: len)
  
template `+`[T](p: ptr T, off: int): ptr T =
  ## Adds an offset to a pointer
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))
  
  
template `[]`[T](useq: UnsafeSeq[T], off: int): T =
  ## Returns the element at `off` for an UnsafeSeq.  This is bounds-checked.
  if (off >= useq.len):
    raise newException(IndexDefect, fmt"index {off} out of bounds")
  (p + off)[]
  
  
type ArrayLike[T] = seq[T] | UnsafeSeq[T]
  


macro genEvaluateBody[T](
  expression: static[string],
  vectors: Table[string, ArrayLike[T]], #seq[T | SomeNumber]],
  dst: var openarray[T]): untyped =
  ## Generates the body of the 
  ## `evaluate <#evaluate>`_ macro 
  let fnBody = newStmtList()                 # StmtList

  # ----------------------------------------------------
  # iterator over all variable identifiers in expression
  #
  # let A1data = vectors["A1"],
  # let B1data = vectors["B1"], etc.              
  # ----------------------------------------------------
  let idents = expression.findVarIdents()  # get variables from expression
  for varIdent in idents.items():
    let A = newLetStmt(                    # LetStmt
      ident(varIdent & "data"),           #   Ident "A1data"
      newNimNode(nnkBracketExpr).add(     #   BracketExpr
          ident vectors.strVal,           #     Ident "vectors"
          newStrLitNode(varIdent)         #     StrLit "A1"
      )
    )
    fnBody.add(A)

  # -------------------------
  # let vectorsLen = A1.len()
  # -------------------------
  var firstVariable: string
  for varIdent in idents.items():
    firstVariable = varIdent & "data"
    break

  let vectorsLenStmt = newLetStmt(                  # LetSection
                                                    #   IdentDefs
    ident "vectorsLen",                             #     Ident "vectorsLen"
                                                    #     Empty
    newDotExpr(ident(firstVariable), ident "len")   #     DotExpr
                                                    #       Ident "A1data"
                                                    #       Ident "len"
  )
  fnBody.add(vectorsLenStmt)

  # -----------------------------------------
  # variables to define a single data element
  #
  # var A1, B1, etc: float32
  # -----------------------------------------
  let dataTypeStr = getTypeInst(dst)[2].repr
  var varSection = newNimNode(nnkVarSection)      # VarSection
  var varIdentDefs = newNimNode(nnkIdentDefs)     #   IdentDefs
  for varIdent in idents.items():
    varIdentDefs.add(ident varIdent)              #     Ident "A1" (etc)
  varIdentDefs.add(ident dataTypeStr)             #     Ident "float32"
  varIdentDefs.add(newEmptyNode())                #     Empty
  varSection.add(varIdentDefs)
  fnBody.add(varSection)

  # ----------------------------------------------------------------
  # loop that does the arithmetic; designed to be auto-vectorised by
  # compilers
  #
  # for i in 0 ..< vectorsLen:
  # ----------------------------------------------------------------
  var forStmt = newNimNode(nnkForStmt)            #   ForStmt
  forStmt.add(ident "i")                          #     Ident "i"
  var rangeDef = newNimNode(nnkInfix).add(        #     Infix
    ident "..<",                                  #       Ident "..<"
    newIntLitNode(0),                             #       IntLit 0
    ident "vectorsLen")                           #       Ident "vectorsLen"

  forStmt.add(rangeDef)

  # ---------------------------------------------------------
  # body of the loop that does the arithmetic; designed to be
  # auto-vectorised by compilers
  #
  # A1 = A1data[i]
  # B1 = B1data[i]
  # dst[i] = A1 + B1
  # ---------------------------------------------------------
  var autoVecLoopBody = newStmtList()             #     StmtList
  for varIdent in idents.items():
    let asgn = newAssignment(                     #       Asgn
      ident varIdent,                             #         Ident "A1"
      newNimNode(nnkBracketExpr).add(             #         BracketExpr
        ident varIdent & "data",                  #           Ident "A1data"
        ident "i")                                #           Ident "i"
    )
    autoVecLoopBody.add(asgn)  
  
  autoVecLoopBody.add(
    newAssignment(                                #       Asgn
      newNimNode(nnkBracketExpr).add(             #         BracketExpr
        ident dst.strVal,                         #           Ident "dst"
        ident "i"),                               #           Ident "i"
      parseExpr(expression)                       # the NimNode of the expression
    )
  )
  
  forStmt.add(autoVecLoopBody) 
  fnBody.add(forStmt)



macro evaluateScalar*[T](
  expression: static[string],
  vectors: Table[string, ArrayLike[T]],
  dst: var openarray[T]): untyped =
  ## Evaluate a scalar expression on sequences of numeric data of type T.
  ## 
  ## The expression is a nim expression using built in operators 
  ## for numeric types and functions from std/math.
  ## 
  ## `vectors` maps variable identifiers with their sequence of data, e.g.
  ## `{"A1", @[0.4, 0.5], "B1", @[0.1, 0.2]}`.  The values in `vectors` can
  ## be a Nim sequence, or if you have a pointer to memory, you can pass an
  ## `UnsafeSeq`.
  ## 
  ## Each variable identifier in `expression` must have a sequence of 
  ## data in `vectors`, otherwise a `KeyError`will be raised.
  ## 
  ## The length of `dst`and each value in `vectors` should be
  ## the same.
  
  # Example of generated code with two variables, A1, and B1, and floating
  # point data:
  # ----------------------------------------------------------------------
  # block:
  #   try:
  #     let A1data = vectors["A1"]
  #     let B1data = vectors["B1"]
  #     let vectorsLen = A1data.len()
  #     var A1,B1: float32
  #     for i in 0 ..< vectorsLen:
  #         A1 = A1data[i]
  #         B1 = B1data[i]
  #         dst[i] = A1 + B1
  #   except KeyError:
  #     var k = getCurrentException()
  #     k.msg &= ".  The `expression` in call to `evaluate` contains this " &
  #               "variable which is not in `vectors`." 
  #     raise k
  if isVector(`expression`):
    error(`expression` & " is a vector so unsupported")

  quote do:
    block:
      try:
        genEvaluateBody(`expression`, `vectors`, `dst`)
      except KeyError:
        var k = getCurrentException()
        k.msg &= ".  The `expression` in call to macro `evaluate` contains " &
                 "this variable that is not in `vectors` argument." 
        raise k



  


const len = 8# * 1024 * 1024
var a = newSeq[float32](len)
var b = newSeq[float32](len)
var c = newSeq[uint8](len)
var d = newSeq[uint8](len)

for i in 0 .. len - 1:
    a[i] = rand(1.0'f32)
    b[i] = a[i]
    c[i] = rand(255).uint8
    d[i] = c[i]
let vectorsAB = {"A1": a, "B1": b}.toTable()
let vectorsCD = {"C1": c, "D1": d}.toTable()
var dstAB: array[len, float32]
var dstCD: array[len, uint8]

let p: ptr[float32] = a[0].addr
let unsafeA = UnsafeSeq[float32](data: p, len: len)
let unsafeVectors = {"A1": unsafeA, "B1": unsafeA}.toTable()
var unsafeDst = newSeq[float32](len)

evaluateScalar("A1 + B1", unsafeVectors, dstAB) 
echo a
echo b
echo dstAB
echo "----"
# do we know the destination type at compile time
evaluateScalar("A1 + B1", vectorsAB, dstAB)
echo a
echo b
echo dstAB
echo "======"
evaluateScalar("C1 + D1 div 3", vectorsCD, dstCD)
echo c
echo d
echo dstCD


