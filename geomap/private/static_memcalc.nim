## Arithmetic calculations on contiguous memory.  This module takes an expression
## , e.g. "A + B", and a sequence for each variable and evaluates the expression
## on each item in the sequence.
## 
## E.g. "A + B" on A = @[0, 1], B = @[2, 3] = @[2, 4]
## 
## The expressions must be known at compile-time. This allows
## the compiler to generate code that uses SIMD instructions if possible, and
## use custom procedures.  
## 
## Expressions
## -----------
## An expression contains variables of the form [A-Z][0-65535]?. Examples of
## valid variables are: "A", "C5", but not: "5C",  "1" or "red".
## 
## Expressions can use Nims arithmetic operators and system procedures as long
## as they works on numeric data.  You can use math procedures or even custom
## procedures as long as they are imported in the module that calls 
## `evaluateScalar`_.
## 
## 
## Compiling against SIMD instruction sets
## ---------------------------------------
## C/C++ Compilers do a good job of auto-vectorising this code with SIMD 
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
  
import std/tables, std/macros, sets, strformat, typetraits
import expressions

type 
  UnsafeSeq*[T] {.requiresInit.} = object
    ## If you have only a pointer, type & length instead of a sequence, you can
    ## use UnsafeSeq in calls instead of seq.  While UnsafeSeq is 
    ## memory unmanaged by nim, it does have bounds checking.
    ## 
    ## Create an instance of UnsafeSeq by calling `initUnsafeSeq`
    len: int
    data: ptr[T]

proc initUnsafeSeq*[T](data: ptr[T], len: int) : UnsafeSeq[T] =
  ## Create an UnsafeSeq with a pointer to data type of T
  UnsafeSeq[T](data: data, len: len)

template `+`[T](p: ptr T, off: int): ptr T =
  ## Adds an offset to a pointer
  cast[ptr type(p[])](cast[ByteAddress](p) +% off * sizeof(p[]))
  
  
template `[]`[T](useq: UnsafeSeq[T], off: int): T =
  ## Returns the element at `off` for an UnsafeSeq.  This is bounds-checked.
  if (off >= useq.len):
    raise newException(IndexDefect, fmt"index {off} out of bounds")
  (p + off)[]
  
  
type ArrayLike*[T] = seq[T] | UnsafeSeq[T]
  ## seq[T] or UnsafeSeq[T]
  

proc getSingleGenericType(node: NimNode) : string = 
  ## String representation of a variable identifier that contains a generic type
  ## Returns T from: seq[T], array[N, T]
  let supportedKinds: set[NimTypeKind] = {ntyArray, ntySequence}
  if (node.typeKind() notin supportedKinds):
    raise newException(ValueError, fmt"Unhandled node kind {node.typeKind()}")

  # either array[N, T] or seq[T] or UnsafeSeq
  result = getTypeInst(node)[0].repr
  case result
    of "array": result = getTypeInst(node)[2].repr
    of "seq": result = getTypeInst(node)[1].repr
    else: raise newException(ValueError, fmt"Unandled type {result} of 'node'")

proc getSourceGenericType(node: NimNode) : string = 
  ## String representation of a variable identifier that contains two generic types
  ## Returns V from: Table[K, ArrayLike[V]]
  let base = getTypeInst(node)[0].repr
  case base
    of "Table": result = getTypeInst(node)[2][1].repr
    else: raise newException(ValueError, fmt"Unandled type {result} of 'node'")



macro genEvaluateBody[S, D](
  expression: static[string],
  vectors: Table[string, ArrayLike[S]], #seq[T | SomeNumber]],
  dst: var openarray[D | SomeNumber],
  dstOffset: int): untyped =
  ## Generates the body of the `evaluate <#evaluate>`_ macro 
  
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
  var srcDataTypeStr = getSourceGenericType(vectors) # getSingleGenericType(dst)
  var varSection = newNimNode(nnkVarSection)      # VarSection
  var varIdentDefs = newNimNode(nnkIdentDefs)     #   IdentDefs
  for varIdent in idents.items():
    varIdentDefs.add(ident varIdent)              #     Ident "A1" (etc)
  varIdentDefs.add(ident srcDataTypeStr)          #     Ident "float32"
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
  let dstTypeString = getSingleGenericType(dst)
  autoVecLoopBody.add(
    newAssignment(                                #       Asgn
      newNimNode(nnkBracketExpr).add(             #         BracketExpr
        ident dst.strVal,                         #           Ident "dst"
        newNimNode(nnkInfix).add(                 #            Infix
          ident "+",                              #             Ident "+"
          ident "i",                              #             Ident "i"
          dstOffset                         #             Ident "dstOffset"
        )
      ),                                          
      newDotExpr(                                 #         DotExpr
        newPar(                                   #           Par
          parseExpr(expression)                   #             the NimNode of the expression
        ),
        ident dstTypeString                       #           Ident "float64
      )
    )
  )
  forStmt.add(autoVecLoopBody) 

  fnBody.add(forStmt)



macro evaluateScalar*[S, D](
  expression: static[string],
  vectors: Table[string, ArrayLike[S]],
  dst: var openarray[D | SomeNumber],
  dstOffset: int = 0): untyped =
  ## Evaluate a scalar expression on sequences of numeric data of type S,
  ## and resulting in type D.
  ## 
  ## The expression is a nim expression using built in operators 
  ## for numeric types.
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
  ## the same or `IndexDefect` is raised.
  ## 
  ## If the destination data type, D, is different to source data type, S, the
  ## result is `type converted <https://nim-lang.org/docs/manual.html#statements-and-expressions-type-conversions>`_.
  ## 
  ## Type conversions from signed to unsigned integers, will result in negative
  ## numbers being wrapped (e.g. -1'i8 -> 255'u8)
  ## 
  ## Any under- or overflows from signed or floating point types will result 
  ## in a OverflowDefect being raised.   Unsigned types will wrap around.  
  ## You could check the maximum and minimum value in the `vectors` and test 
  ## they are in the low .. high bounds of D, prior to calling.
  ## 
  ## Optionally an offset to the destination buffer can be provided to write
  ## the result starting at `dst[offset]`.  This enables you to call 
  ## this function to operate only on a part of `dst`.
  
  # Example of generated code with two variables, float32 A1, and B1, 
  # and float64 dst:
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
  #         dst[i + dstOffset] = (A1 + B1).float64
  #   except KeyError:
  #     var k = getCurrentException()
  #     k.msg &= ".  The `expression` in call to `evaluate` contains this " &
  #               "variable which is not in `vectors`." 
  #     raise k
  quote do:
    block:
      try:
         genEvaluateBody(`expression`, `vectors`, `dst`, `dstOffset`)
      except KeyError:
        var k = getCurrentException()
        k.msg &= ".  The `expression` in call to macro `evaluate` contains " &
                 "this variable that is not in `vectors` argument." 
        raise k
