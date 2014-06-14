import parsecfg, strutils, streams, tables, sequtils, algorithm, global_patches

type
  Section* = object ## Contains the parameters for a section in the .ini file.
    name*: string ## Not nil. Name of the section.
    update_html*: string ## Not nil. Html file to update.
    doc_dir*: string ## Not nil. Base directory where docs will be placed.
    ignore_tags*: seq[string] ## Nil or contains the tags to ignore.
    branches*: seq[string] ## Not nil. Branches to regenerate.

    multiple_indices*: bool ## When true, the user wants multiple theindex.html.
    doc2_modules*: seq[string] ## Nil or files to run through doc2 command.
    doc_modules*: seq[string] ## Not nil. Files to run through doc command.
    md_files*: seq[string] ## Nil or files to run through md library.
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
  X.md_files = nil
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


proc safe(x: seq[string]): string =
  if x.is_nil: "" else: "'" & $x & "'"
proc safe(x: string): string =
  if x.is_nil: "" else: "'" & $x & "'"
proc safe(x: bool): string = $x

proc `$`*(section: Section): string =
  ## Outputs the contents of the section in a human friendly way.
  if not section.is_valid:
    result = "\n\tInvalid section"
  else:
    result = "\n\t[" & section.name & "]"
    for name, value in fieldPairs(section):
      let v = value.safe
      if v.len > 0:
        result.add "\n\t\t" & name & " = " & v


proc `$`*(ini: Ini_config): string =
  ## Outputs the contents of the parsed configuration.
  result = "Ini_config:" & $ini.default
  var keys = to_seq(ini.specific.keys)
  keys.sort(system.cmp)
  for key in keys:
    result.add($ini.specific[key])


proc combine*(ini: Ini_config; target: string): Section =
  ## Returns a Section for the specific `target`.
  ##
  ## The returned section will use the default settings for whatever is missing.
  if not ini.specific.has_key(target):
    # If there is no specific target, use the default one and change the name.
    result = ini.default
    result.name = target
    return

  result = ini.specific[target]
  result.update_html = ini.default.update_html
  result.doc_dir = ini.default.doc_dir
  result.ignore_tags = ini.default.ignore_tags
  result.branches = ini.default.branches
  # Patch up the following variables.
  if result.doc_modules.len < 1 and ini.default.doc_modules.len > 0:
    result.doc_modules = ini.default.doc_modules
  if result.doc2_modules.is_nil and ini.default.doc2_modules.not_nil:
    result.doc2_modules = ini.default.doc2_modules
  if result.md_files.is_nil and ini.default.md_files.not_nil:
    result.md_files = ini.default.md_files
  if result.rst_files.is_nil and ini.default.rst_files.not_nil:
    result.rst_files = ini.default.rst_files
  if result.link_html.is_nil and ini.default.link_html.not_nil:
    result.link_html = ini.default.link_html


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
  assert s.not_nil
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
  case event.key.normalize
  of "updatehtml": section.update_html = event.value.strip
  of "docdir": section.doc_dir = event.value.strip
  of "ignoretags": section.ignore_tags = parse_lines(event.value)
  of "branches": section.branches.parse_lines(event.value)
  of "doc2modules": section.doc2_modules = parse_lines(event.value)
  of "mdfiles": section.md_files = parse_lines(event.value)
  of "docmodules": section.doc_modules.parse_lines(event.value)
  of "rstfiles": section.rst_files = parse_lines(event.value)
  of "linkhtml": section.link_html = parse_lines(event.value)
  of "multipleindices": section.multiple_indices = true
  else: echo parser.ignore_msg(event)


proc load_ini*(filename: string): Ini_config =
  ## Loads the specified configuration file.
  ##
  ## Returns the Ini_config structure or raises an IOE hexception.
  var f = filename.newFileStream(fmRead)
  if f.is_nil: raise new_exception(EIO, "Could not open " & filename)
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
      if e.section.not_nil:
        s.name = e.section
    of cfgKeyValuePair, cfgOption:
      if s.name.len < 1:
        echo p.ignore_msg(e)
      else:
        s.add(e, p)
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
