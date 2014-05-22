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

proc test() =
  ## Mini unit test proc.
  var
    ini = init_ini_config()
    temp_section: Section
  temp_section.init
  echo "Hey!"

when isMainModule: test()
