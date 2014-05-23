import parsecfg, strutils, streams, tables

type
  Section* = object ## Contains the parameters for a section in the .ini file.
    name*: string not nil ## Name of the section.
    update_html*: string not nil ## Html file to update.
    doc_dir*: string not nil ## Base directory where docs will be placed.
    ignore_tags*: seq[string] ## Nil or contains the tags to ignore.
    branches*: seq[string] not nil ## ## Branches to regenerate.
    doc2_modules*: seq[string] ## Nil or files to run through doc2 command.
    doc_modules*: seq[string] not nil ## Files to run through doc command.
    rst_files*: seq[string] ## Nil or files to be rested.
    link_html*: seq[string] ## Nil or files to be linked in the index.

  Ini_config* = object ## Holds the whole .ini contents.
    default*: Section ## Content of the default gh-pages section.
    specific*: TTable[string, Section] ## All other possible sections.


proc init(X: var Section) =
  ## Initializes a Section with default values.
  X.name = ""
  X.update_html = ""
  X.doc_dir = ""
  X.branches = @[]
  X.doc_modules = @[]


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


proc load_ini(filename: string): Ini_config =
  ## Loads the specified configuration file.
  ##
  ## Returns the Ini_config structure or raises an IOE hexception.
  var f = filename.newFileStream(fmRead)
  if f.isNil:
    raise new_exception(EIO, "Could not open " & filename)

  finally: f.close

  var p: TCfgParser
  p.open(f, filename)
  finally: p.close

  var section = ""
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
      section = e.section
      echo "section ", section
    of cfgKeyValuePair:
      echo("key-value-pair: " & e.key & ": " & e.value)
    of cfgOption: discard
    of cfgError: raise new_exception(EInvalidValue,
      "Error parsing " & filename & ": " & e.msg)


proc test() =
  ## Mini unit test proc.
  var
    ini = init_ini_config()
    temp_section: Section
  temp_section.init
  ini = load_ini("gh_nimrod_doc_pages.ini")
  echo "Hey!"


when isMainModule: test()
