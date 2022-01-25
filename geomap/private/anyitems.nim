import std/tables, std/sets

proc getAnyPair*[K, V](table: TableRef[K, V]) : (K,V) {.inline.} = 
  ## get any random immutable (key, value) pair from `table`
  for k, v in table.pairs():
    return (k, v)

proc getAnyValue*[K, V](table: TableRef[K, V]) : V {.inline.} = 
  ## get any random immutable value from `table`
  for v in table.values():
    return v

proc getAnyValue*[T](s: HashSet[T]) : T {.inline.} =
  ## get any random value from a HashSet `s`
  for t in s.items():
    return t