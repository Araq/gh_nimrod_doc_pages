import parsecfg, strutils, streams, tables, sequtils, algorithm

type
  Section* = object ## Contains the parameters for a section in the .ini file.
    name*: string ## Not nil. Name of the section.
    update_html*: string ## Not nil. Html file to update.
    doc_dir*: string ## Not nil. Base directory where docs will be placed.
    ignore_tags*: seq[string] ## Nil or contains the tags to ignore.
    branches*: seq[string] ## Not nil. Branches to regenerate.
    doc2_modules*: seq[string] ## Nil or files to run through doc2 command.
    doc_modules*: seq[string] ## Not nil. Files to run through doc command.
    rst_files*: seq[string] ## Nil or files to be rested.
    link_html*: seq[string] ## Nil or files to be linked in the index.

  Ini_config* = object ## Holds the whole .ini contents.
    default*: Section ## Content of the default gh-pages section.
    specific*: TTable[string, Section] ## All other possible sections.


const
  start_branch* = "gh-pages" ## The git branch containing the generated docs.


proc init(X: var Section) =
  ## Initializes a Section with default values.
  X.name = ""
  X.update_html = ""
  X.doc_dir = ""
  X.ignore_tags = nil
  X.branches = @[]
  X.doc2_modules = nil
  X.doc_modules = @[]
  X.rst_files = nil
  X.link_html = nil


proc init_section(): Section =
  ## Shortcut wrapper around init(Section).
  result.init


proc init(X: var Ini_config) =
  ## Initializes a Ini_config with default values.
  X.default.init
  X.specific = init_table[string, Section]()


proc init_ini_config(): Ini_config =
  ## Shortcut wrapper around init(Ini_config).
  result.init


proc is_valid(section: Section): bool =
  ## Returns true if a section is valid.
  ##
  ## To be valid, a section requires to have a non null name. Additionally if
  ## the name is start_branch, some global fields are required to be filled in.
  if section.name.len < 1: return

  if section.name == start_branch:
    # Additional checks
    if section.update_html.len < 1:
      echo "Missing update_html for section " & section.name & "."
      return
    if section.doc_dir.len < 1:
      echo "Missing doc_dir for section " & section.name & "."
      return

  result = true


proc is_valid(ini: Ini_config): bool =
  ## Returns true if the config is valid.
  ##
  ## To be valid the default configuration has to be filled in.
  result = ini.default.is_valid


proc `$`*(section: Section): string =
  ## Outputs the contents of the section in a human friendly way.
  if not section.is_valid:
    result = "\n\tInvalid section"
  else:
    result = "\n\t[" & section.name & "]"
    for name, value in fieldPairs(section):
      if not value.isNil and value.len > 0:
        result.add "\n\t\t" & name & " = '" & $value & "'"


proc `$`*(ini: Ini_config): string =
  ## Outputs the contents of the parsed configuration.
  result = "Ini_config:" & $ini.default
  var keys = to_seq(ini.specific.keys)
  keys.sort(system.cmp)
  for key in keys:
    result.add($ini.specific[key])


proc add(ini: var Ini_config; section: Section) =
  ## Adds or replaces an existing `section` in the `ini`.
  ##
  ## If `section` is not valid, the proc will return without doing anything.
  ## Failures are echoed.
  if not section.is_valid:
    return

  if section.name == start_branch:
    ini.default = section
  else:
    ini.specific[section.name] = section


proc parse_lines(s: var seq[string]; text: string) =
  ## Adds to `s` whatever text were found in `text`.
  assert(not s.isNil)
  for line in text.split_lines:
    let token = line.strip
    if token.len > 0:
      s.add(token)


proc parse_lines(text: string): seq[string] =
  ## Returns a secuence with the contents of text or nil if nothing was found.
  result = @[]
  result.parse_lines(text)
  if result.len < 1:
    result = nil


proc add(section: var Section; event: TCfgEvent; parser: TCfgParser) =
  ## Adds a key,value pair to the section.
  case event.key
  of "update_html": section.update_html = event.value.strip
  of "doc_dir": section.doc_dir = event.value.strip
  of "ignore_tags": section.ignore_tags = parse_lines(event.value)
  of "branches": section.branches.parse_lines(event.value)
  of "doc2_modules": section.doc2_modules = parse_lines(event.value)
  of "doc_modules": section.doc_modules.parse_lines(event.value)
  of "rst_files": section.rst_files = parse_lines(event.value)
  of "link_html": section.link_html = parse_lines(event.value)
  else: echo parser.ignore_msg(event)


proc load_ini(filename: string): Ini_config =
  ## Loads the specified configuration file.
  ##
  ## Returns the Ini_config structure or raises an IOE hexception.
  var f = filename.newFileStream(fmRead)
  if f.isNil: raise new_exception(EIO, "Could not open " & filename)
  finally: f.close

  var p: TCfgParser
  p.open(f, filename)
  finally: p.close

  result.init
  var s = init_section()

  while true:
    var e: TCfgEvent
    try: e = next(p)
    except EInvalidField:
      quit(p.errorStr("""Internal error parsing file.

Please look up the ini file at the specified position and see if you are naming
a section with non alphabetic characters. If so, try quoting the section (eg:
["a-section"]). If you still can't get this working, please report the bug at
https://github.com/gradha/gh_nimrod_doc_pages/issues providing the contents of
the .ini file.
"""))
    case e.kind
    of cfgEof: break
    of cfgSectionStart:
      result.add(s)
      s.init()
      if not e.section.isNil:
        s.name = e.section
    of cfgKeyValuePair:
      if s.name.len < 1:
        echo p.ignore_msg(e)
      else:
        s.add(e, p)
    of cfgOption: discard
    of cfgError: raise new_exception(EInvalidValue,
      "Error parsing " & filename & ": " & e.msg)

  result.add(s)
  if not result.is_valid:
    raise new_exception(EInvalidValue,
      "Error parsing " & filename & ", doesn't contain all required values.")


proc test() =
  ## Mini unit test proc.
  var
    ini = init_ini_config()
    temp_section: Section
  temp_section.init
  ini = load_ini("gh_nimrod_doc_pages.ini")
  echo ini
  echo "Hey!"


when isMainModule: test()
