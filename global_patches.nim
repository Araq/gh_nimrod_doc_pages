import os, strutils
# Convenience code?

template notNil*[T](x: T): bool = (not x.isNil)

iterator dot_walk_dir*(dir: string,
    filter={pcFile, pcDir}): string {.tags: [FReadDir].} =
  ## Version of walkDirRec which ignores directories starting with a dot.
  var stack = @[dir]
  while stack.len > 0:
    for k,p in walkDir(stack.pop()):
      if k in filter:
        case k
        of pcFile, pcLinkToFile: yield p
        of pcDir, pcLinkToDir:
          if p.find("/.") < 0:
            stack.add(p)
