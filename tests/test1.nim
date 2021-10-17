# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest
import geomap/calc, geomap/calcexpr, tables, macros, typetraits

macro ast(e: static[string]): untyped =
  let tree = parseStmt(e)
  echo tree.treeRepr
  echo tree[0].kind
  echo tree[0].len
  if tree[0].kind == nnkAsgn:
    echo "Assign " & tree[0][0].repr


proc entry() = 
  ast("A1 = 2 * 3")
  #StmtList
  #Asgn
  #  Ident "A1"
  #  Infix
  #    Ident "*"
  #    IntLit 2
  #    IntLit 3

entry()

