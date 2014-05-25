import argument_parser, os, tables, strutils, osproc, inidata

type
  Global = object ## \
    ## Holds all the global variables of the process.
    params: Tcommandline_results
    config_path: string ## Empty string or user input path to the config file.
    config_dir: string ## dot or user input path to the config file.
    boot: bool ## True if the user wants to create files in the current dir.
    git_exe: string ## \
    ## Full path to the git executable or the empty string. This is initialized
    ## in process_commandline.
    git_branch: string ## Contains the name of the current branch.
    github_username: string ## Empty string or username.
    github_project: string ## Empty string or GitHub project name.


var G: Global


template slurp_html_template(rel_path: string): expr =
  ## Template used to reduce typing for slurping files.
  (rel_path, slurp("boot_html_template" / rel_path))


template switch_to_config_dir(): stmt =
  ## Switches to the configuration dir and sets a finally to go back later.
  let current_dir = get_current_dir()
  finally: set_current_dir(current_dir)
  G.config_dir.set_current_dir


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

  config_filename = "gh_nimrod_doc_pages.ini"
  git_ssh_prefix = "git@github.com:" ## Used to detect origin information.
  git_https_prefix = "https://github.com/" ## Detects origin url.
  git_suffix = ".git" ## Mandatory at end of origin url.
  template_github_username = "github_username"
  template_github_project = "github_project"

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

  template_files = @[
    slurp_html_template(config_filename),
    slurp_html_template("images/body-bg.png"),
    slurp_html_template("images/highlight-bg.jpg"),
    slurp_html_template("images/hr.png"),
    slurp_html_template("images/octocat-icon.png"),
    slurp_html_template("images/tar-gz-icon.png"),
    slurp_html_template("images/zip-icon.png"),
    slurp_html_template("index.html"),
    slurp_html_template("stylesheets/print.css"),
    slurp_html_template("stylesheets/pygment_trac.css"),
    slurp_html_template("stylesheets/stylesheet.css"),
    ]


proc run_git(params: string): seq[string] =
  ## Runs the specified git commandline.
  ##
  ## Returns the output as text lines. Always returns a valid sequence, but if
  ## there are any problems the sequence will have a single element with the
  ## empty string.
  let (output, exit) = execCmdEx(G.git_exe & " " & params)
  if exit != 0:
    result = @[""]
  else:
    result = output.split_lines


proc gather_git_info() =
  ## Obtains juicy bits about the git project we are on.
  ##
  ## Fills the git_branch, github_project and github_username, or leaves them
  ## as the empty string. Before running the commands changes directory to the
  ## configuration file.
  assert(not G.config_dir.isNil and G.config_dir.len > 0)
  switch_to_config_dir()

  G.git_branch = run_git("rev-parse --abbrev-ref HEAD")[0]
  G.github_username = ""
  G.github_project = ""
  # Try to find out origin remote with full GitHub username/project name
  for line in run_git("remote -v"):
    if not line.starts_with("origin") or line.find("(push)") < 0:
      continue
    # Found line, try to parse info.
    for prefix in [git_ssh_prefix, git_https_prefix]:
      var pos = line.find(git_ssh_prefix)
      if pos > 0: # Found the beginning of the pattern.
        pos += git_ssh_prefix.len
        let split = line.find('/', pos)
        if split > 0: # Found the username/project separator.
          let finish = line.find(git_suffix, split)
          if finish > 0: # Found the trailing project extension.
            G.github_username = line[pos .. <split]
            G.github_project = line[split + 1 .. <finish]
            break

  if G.github_username.len < 1:
    echo "Warning, couldn't extract github username from local repo."
    G.github_username = template_github_username

  if G.github_project.len < 1:
    echo "Warning, couldn't extract github project name from local repo."
    G.github_project = template_github_project


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

  # Patch the global variables to always contain meaningful values.
  if G.config_path.len > 0:
    G.config_dir = G.config_path.parent_dir
  else:
    G.config_dir = "."
    G.config_path = config_filename

  gather_git_info()

  if not "USER_GRADHA".exists_env and G.git_branch != start_branch:
    abort "You have to run the command on your " & start_branch & " branch."


proc generate_templates() =
  ## Generates missing files for the user.
  ##
  ## If any of the files already exists it won't be overwritten. This proc
  ## presumes it will always run with relative paths to the working directory.
  for filename, contents in template_files.items:
    if filename.exists_file:
      echo "File '" & filename & "' already exists, skipping."
      continue
    echo "Generating missing '" & filename & "'"
    # Make sure the directory exists.
    let dir = filename.parent_dir
    if dir.len > 0: dir.create_dir
    let data = (if filename != "index.html": contents else: contents
      .replace(template_github_username, G.github_username)
      .replace(template_github_project, G.github_project))
    filename.write_file(data)


proc main() =
  ## Main entry point of the program.
  ##
  ## Processes the parameters, reads config files and if everything is ok, does
  ## some work.
  process_commandline()
  if G.boot:
    generate_templates()
  else:
    echo G.config_dir
    echo G.config_path


when isMainModule: main()
