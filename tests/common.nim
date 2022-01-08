template notCompiles*(e: untyped): untyped =
  # can't compile `check not compiles:` so we use this template to write
  # ```check:
  #      notCompiles:
  #```    
  not compiles(e)