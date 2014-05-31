import os, re, algorithm, strutils

proc cmpSeq*[T](x, y: seq[T]): int =
  # Compare only the minimum amount of elements necessary
  let maxIterations = min(len(x), len(y))
  for i in 0..maxIterations-1:
    result = cmp(x[i], y[i])
    if result != 0:
      return

  # Well, if we exhausted the comparison, resort to system.cmp implementation.
  result = cmp(len(x), len(y))

proc test1() =
  var
    c: seq[seq[string]] = @[@["c"], @["a"], @["b"],
      @["c", "c"], @["a", "c"], @["b", "c"], @[],
      @["c", "a"], @["c", "b"], @["c", "c"],
    ]

  echo "Before sorting"
  for s in c:
    echo join(s, ", ")
  sort(c, cmpSeq[string])
  echo "After sorting"
  for s in c:
    echo join(s, ", ")


# Now, lets add regular expressions.
type
  StringKind* = enum TextString, NumericString
  MultiString* = object
    text: string
    case kind: StringKind
    of TextString: nil
    of NumericString: value: int

let regex = re"(\d+)|(\D+)"

proc test2() =
  let result = findAll("num23.change1101.ext", regex)
  echo join(result, ", ")

proc `$`*(m: seq[MultiString]): string =
  result = join(map(m, proc (x: MultiString): string = x.text), "")

proc numericalize*(text: string): seq[MultiString] =
  let chunks = findAll(text, regex)
  newSeq(result, len(chunks))
  for f, chunk in pairs(chunks):
    assert len(chunk) > 0
    try:
      let value = parseInt(chunk)
      result[f] = (MultiString(text: chunk, kind: NumericString, value: value))
    except EInvalidValue:
      result[f] = (MultiString(text: chunk, kind: TextString))

proc cmp*(x, y: MultiString): int =
  if x.kind == NumericString and y.kind == TextString: return -1
  elif y.kind == NumericString and x.kind == TextString: return 1
  elif y.kind == TextString and x.kind == TextString:
    result = cmp(x.text, y.text)
  else:
    result = cmp(x.value, y.value)

proc test3() =
  var
    d = @[
      numericalize("num23.change1101.ext"),
      numericalize("num3.change1101.ext"),
      numericalize("num23.change01.ext"),
      numericalize("num23.change0.ext"),
      numericalize("num4.change1101.ext"),
      numericalize("num4.change1.ext"),
      numericalize("num23.change.ext"),
      ]

  echo "Before sorting"
  for s in d:
    echo s
  sort(d, cmpSeq[MultiString])
  echo "After sorting"
  for s in d:
    echo s


  echo "Tuples"

  type
    tup = tuple[name: string, age: int]

  proc `$`(x: tup): string = "tup(name:'" & x.name & "', age:" & $x.age & ")"
  proc `$`(x: seq[tup]): string = join(map(x, `$`), "\n")

  var
    thingies: seq[tup] = @[(name: "AA", age: 30),
      (name: "BA", age: 30),
      (name: "CA", age: 30),
      (name: "AA", age: 40),
      (name: "AD", age: 10),
      (name: "A2", age: 30),
      (name: "AC", age: 30),
      (name: "BA", age: 30),
      (name: "CC", age: 30)]

  echo "Before ", thingies
  sort(thingies, system.cmp[tup])
  echo "After ", thingies

when isMainModule:
  test1()
  test2()
  test3()
