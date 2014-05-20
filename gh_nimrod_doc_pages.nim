import argument_parser, os, tables, strutils

type
  Global = object ## \
    ## Holds all the global variables of the process.
    params: Tcommandline_results
    config_path: string ## Empty string or user input path to the config file.
    boot: bool ## True if the user wants to create files in the current dir.
    git_exe: string ## \
    ## Full path to the git executable or the empty string. This is initialized
    ## in process_commandline.


var G: Global

const
  version_str* = "0.1.1" ## Program version as a string.
  version_int* = (major: 0, minor: 1, maintenance: 1) ## \
  ## Program version as an integer tuple.
  ##
  ## Major version changes mean significant new features or a break in
  ## commandline backwards compatibility, either through removal of switches or
  ## modification of their purpose.
  ##
  ## Minor version changes can add switches. Minor
  ## odd versions are development/git/unstable versions. Minor even versions
  ## are public stable releases.
  ##
  ## Maintenance version changes mean bugfixes or non commandline changes.

  config_filename = "gh-nimrod-doc-pages.ini"

  param_help = @["-h", "--help"]
  help_help = "Displays commandline help and exits."

  param_version = @["-v", "--version"]
  help_version = "Displays the current version and exists."

  param_config = @["-c", "--config"]
  help_config = "Specify a path to the configuration ini. By default " &
    "it looks for '" & config_filename & "' in the working directory. " &
    "You can't use this switch together with --boot."

  param_boot = @["-b", "--boot"]
  help_boot = "Creates missing files required for operation in the " &
    "working directory, which should be inside a git tree with a branch " &
    "named gh-pages. You can't use this switch together with --config."

  template_files = @[(config_filename, "stuff")]


proc process_commandline() =
  ## Parses the commandline, modifying the global structure.
  ##
  ## It also initializes fields like *git_exe*.
  G.git_exe = "git".find_exe

  var PARAMS: seq[Tparameter_specification] = @[]
  PARAMS.add(new_parameter_specification(PK_HELP,
    names = param_help, help_text = help_help))
  PARAMS.add(new_parameter_specification(names = param_version,
    help_text = help_version))
  PARAMS.add(new_parameter_specification(PK_STRING, names = param_config,
    help_text = help_config))
  PARAMS.add(new_parameter_specification(names = param_boot,
    help_text = help_boot))

  # Parsing.
  G.params = PARAMS.parse

  proc abort(message: string) =
    echo message & "\n"
    params.echo_help
    quit(QuitFailure)

  if G.params.options.has_key(param_version[0]):
    echo "Version ", version_str
    quit()

  if G.params.options.has_key(param_boot[0]):
    G.boot = true

  if G.params.options.has_key(param_config[0]):
    G.config_path = G.params.options[param_config[0]].str_val
  else:
    G.config_path = ""

  # Input validation.
  if not G.git_exe.exists_file:
    quit "This program relies on the git executable being available, but it " &
      "could not be found on your $PATH!"

  if G.boot and G.config_path.len > 0:
    abort "Sorry, can't use both --boot and --config switches."

  if G.config_path.len > 0 and not G.config_path.exists_file:
    abort "Sorry, '" & G.config_path & "' doesn't seem to be a valid file."


proc generate_templates() =
  ## Generates missing files for the user.
  ##
  ## If any of the files already exists it won't be overwritten.
  for filename, contents in template_files.items:
    if filename.exists_file:
      echo "File '" & filename & "' already exists, skipping."
      continue
    echo "Generating missing '" & filename & "'"
    filename.write_file(contents)


proc main() =
  ## Main entry point of the program.
  ##
  ## Processes the parameters, reads config files and if everything is ok, does
  ## some work.
  process_commandline()
  if G.boot:
    generate_templates()
  echo "Hey!", G.config_path, G.boot


when isMainModule: main()
