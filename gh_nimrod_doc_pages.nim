## gh_nimrod_doc_pages main module.
##
## For project information see https://github.com/gradha/gh_nimrod_doc_pages.

import argument_parser, os, tables, strutils, osproc, inidata, sequtils,
  global_patches, sets, algorithm, packages/docutils/rstgen, sorting_lists,
  midnight_dynamite, html_support

when defined(windows):
  import windows
else:
  import posix


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
    nimrod_exe: string ## \
    ## Full path to the nimrod compiler or the empty string. This is
    ## initialized in process_commandline.
    git_branch: string ## Contains the name of the current branch.
    github_username: string ## Empty string or username.
    github_project: string ## Empty string or GitHub project name.
    clone_dir: string ## Path to the temporary git clones directory. \
    ## This path is relative to config_dir.
    md_params: md_params ## Markdown render configuration.


var G: Global
# Obtain current pid and store it for later.
when defined(windows):
  let my_pid = $GetCurrentProcessId()
else:
  let my_pid = $getpid()


template slurp_html_template(rel_path: string): expr =
  ## Template used to reduce typing for slurping files.
  (rel_path, slurp("boot_html_template" / rel_path))


template switch_to_config_dir(body:stmt): stmt =
  ## Switches to the configuration dir and sets a finally to go back later.
  ##
  ## Pass the body you want to run inside the directory.
  assert G.config_dir.not_nil and G.config_dir.len > 0
  let current_dir = get_current_dir()
  try:
    G.config_dir.set_current_dir
    body
  finally:
    current_dir.set_current_dir


const
  name = "gh_nimrod_doc_pages"
  config_filename = name & ".ini"

  version_str* = name & "-0.2.2" ## Program version as a string. \
  ## The format is ``string-digit(.digit)*``.

  version_int* = (major: 0, minor: 2, maintenance: 2) ## \
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
  help_config = "Specify a path to a specific configuration ini or a " &
    "directory containing a " & config_filename & " file. " &
    "You can't use this switch together with --boot."

  param_boot = @["-b", "--boot"]
  help_boot = "Creates missing files required for operation in the " &
    "working directory, which should be inside a git tree with a branch " &
    "named " & start_branch & ". You can't use this switch together " &
    "with --config."

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

  nojekyll_filename = ".nojekyll" ## Witness to disable GitHub jekyll.

  keep_temp = false ## Internal development switch, avoids deletion of files.

  api_list_start = "gh_nimrod_doc_pages_api_list_start" ## Html start marker.
  api_list_end = "gh_nimrod_doc_pages_api_list_end" ## Html end marker.


proc update_html(ini: Ini_config): string =
  ## Returns a properly fixed update_html path considering our globals.
  result = ini.default.update_html
  if not result.is_absolute:
    result = G.config_dir/result


proc doc_dir(ini: Ini_config): string =
  ## Returns a properly fixed doc_dir path considering our globals.
  result = ini.default.doc_dir
  if not result.is_absolute:
    result = G.config_dir/result


proc git(params: string): seq[string] =
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


proc git_tag_or_branch(prefix: string): seq[string] =
  ## Wraps over git() using a specific porcelain to get tag/branches.
  ##
  ## This will invoke "git for-each-ref --format='%(refname)' prefix" where
  ## `prefix` is ``refs/tags``, ``refs/heads`` or any other valid prefix. The
  ## returned list will have ``prefix`` itself removed. See
  ## http://stackoverflow.com/a/3847586/172690 for reference.
  ##
  ## Always returns at least the empty sequence.
  result = @[]
  for line in git("for-each-ref --format='%(refname)' " & prefix):
    if line.starts_with(prefix):
      result.add(line[prefix.len .. <line.len])


proc git_tags(): seq[string] =
  ## Returns the list of available tags or the empty sequence.
  result = git_tag_or_branch("refs/tags/")


proc git_branches(): seq[string] =
  ## Returns the list of available branches or the empty sequence.
  result = git_tag_or_branch("refs/heads/")


proc gather_git_info() =
  ## Obtains juicy bits about the git project we are on.
  ##
  ## Fills the git_branch, github_project and github_username, or leaves them
  ## as the empty string. Before running the commands changes directory to the
  ## configuration file.
  switch_to_config_dir:
    G.git_branch = git("rev-parse --abbrev-ref HEAD")[0]
    G.github_username = ""
    G.github_project = ""
    # Try to find out origin remote with full GitHub username/project name
    for line in git("remote -v"):
      if not line.starts_with("origin") or line.find("(push)") < 0:
        continue
      # Found line, try to parse info.
      for prefix in [git_ssh_prefix, git_https_prefix]:
        var pos = line.find(prefix)
        if pos > 0: # Found the beginning of the pattern.
          pos += prefix.len
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
  ## It also initializes fields like `git_exe` or `nimrod_exe`.
  G.git_exe = "git".find_exe
  G.nimrod_exe = "nimrod".find_exe
  G.md_params.init

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
    echo "Version ", version_str, "."
    quit()

  if G.params.options.has_key(param_boot[0]):
    G.boot = true

  if G.params.options.has_key(param_config[0]):
    G.config_path = G.params.options[param_config[0]].str_val
    if G.config_path.exists_dir:
      G.config_path = G.config_path/config_filename
  else:
    G.config_path = ""

  # Input validation.
  if not G.git_exe.exists_file:
    quit "This program relies on the git executable being available, but it " &
      "could not be found in your $PATH!"

  if not G.nimrod_exe.exists_file:
    quit "This program relies on the nimrod compiler being available, but " &
      "it could not be found in your $PATH!"

  if G.boot and G.config_path.len > 0:
    abort "Sorry, can't use both --boot and --config switches."

  if G.config_path.len > 0 and not G.config_path.exists_file:
    abort "Sorry, '" & G.config_path & "' doesn't seem to be a valid file."

  if not G.boot and not G.config_path.exists_file:
    abort "Sorry, you need to either boot or specify a config file."

  # Patch the global variables to always contain meaningful values.
  if G.config_path.len > 0:
    G.config_dir = G.config_path.parent_dir
  else:
    G.config_dir = "."
    G.config_path = config_filename

  gather_git_info()

  #if not "USER_GRADHA".exists_env and G.git_branch != start_branch:
  #  abort "You have to run the command on your " & start_branch & " branch."


proc generate_templates() =
  ## Generates missing files for the user.
  ##
  ## If any of the files already exists it won't be overwritten. This proc
  ## presumes it will always run with relative paths to the working directory.
  var generated = 0
  for filename, contents in template_files.items:
    if filename.exists_file:
      echo "File '" & filename & "' already exists, skipping."
      continue
    echo "Generating missing '" & filename & "'"
    generated.inc
    # Make sure the directory exists.
    let dir = filename.parent_dir
    if dir.len > 0: dir.create_dir
    let data = (if filename != "index.html": contents else: contents
      .replace(template_github_username, G.github_username)
      .replace(template_github_project, G.github_project))
    filename.write_file(data)

  # If all files were generated, create file to prevent jekyll from running.
  if generated == template_files.len:
    echo "Generating '" & nojekyll_filename & "' due to lack of other files."
    nojekyll_filename.write_file("")


proc obtain_targets_to_work_on(ini: Ini_config):
    tuple[tags, branches: seq[string]]  =
  ## Figures out what tags/branches to work on.
  ##
  ## This will retrieve available tags for the repository and filter them
  ## through Ini_config.ignore_tags. For branches the reverse is done, only
  ## specified branches are looked up in the git project. If something is
  ## wrong, a warning is echoed but execution tries to move forward.
  ##
  ## Returns a tuple with the list of tags/branches that have to be processed.
  ## Tags are not to be rebuilt, branches are always refreshed.
  switch_to_config_dir:
    result.tags = git_tags()
    if ini.default.ignore_tags.not_nil:
      result.tags = result.tags.filter_it(
        not ini.default.ignore_tags.contains(it))

    # Read the available branches.
    let available_branches = git_branches()
    result.branches = ini.default.branches.filter_it(
      available_branches.contains(it))


proc scan_files(extension: string, dir = "."): seq[string] =
  ## Returns the relative paths to files found with the specified extension.
  ##
  ## Hmm... seems like making this an iterator which yields the path crashes
  ## the generated runtime code...
  assert extension.not_nil and extension[0] == '.'
  result = @[]

  for kind, path in dir.walk_dir:
    assert path.len > 2
    let good_path = path[2 .. <path.len]
    # Ignore hidden files and hidden directories.
    if good_path[0] == '.':
      continue
    case kind
    of pcFile, pcLinkToFile:
      if good_path.split_file.ext == extension:
        result.add(good_path)
    of pcDir, pcLinkToDir:
      for recursive in extension.scan_files(path):
        result.add(recursive)


proc nimrod(command, src: string; dest = ""): bool =
  ## Runs Nimrod's `command` from `src` to `dest`.
  ##
  ## Returns true if everything went ok, false if the file was skipped. The
  ## `dest` parameter can't be nil, but if you pass the empty string the the
  ## typical ``--out:dest`` won't be appended to the command.
  assert command.not_nil and src.not_nil and dest.not_nil
  if not src.exists_file and not src.exists_dir:
    echo "Skiping invalid '" & src & "'"
    return

  let
    out_param = if dest.len > 0: "--out:" & dest else: ""
    command = G.nimrod_exe & " " & command &
      " --verbosity:0 --index:on " & out_param & " " & src
    (output, exit) = execCmdEx(command)

  if exit != 0:
    echo output
    echo "Error running " & command & " on '" & src & "', compiler aborted."
    return

  if dest.len > 0 and not dest.exists_file:
    echo output
    echo "Error running " & command & " on '" & src & "', html file not found."
    return
  result = true


proc md(input_md: string): string =
  ## Runs `input_md` through the default Midnight Dynamite conversion.
  ##
  ## Returns the empty string or the relative path to the generated file.
  let dest = input_md.change_file_ext("html")
  dest.remove_file
  G.md_params.render_file(input_md, dest)
  if dest.exists_file:
    result = dest
  else:
    result = ""


proc rst(input_rst: string): string =
  ## Runs `input_rst` through Nimrod's rst2html command.
  ##
  ## Returns the empty string or the relative path to the generated file.
  let dest = input_rst.change_file_ext("html")
  if nimrod("rst2html", input_rst, dest):
    result = dest
  else:
    result = ""


proc doc1(input_nim: string): string =
  ## Runs `input_nim` through Nimrod's doc command.
  ##
  ## Returns the empty string or the relative path to the generated file.
  let dest = input_nim.change_file_ext("html")
  if nimrod("doc", input_nim, dest):
    result = dest
  else:
    result = ""


proc doc2(input_nim: string): string =
  ## Runs `input_nim` through Nimrod's doc2 command.
  ##
  ## Returns the empty string or the relative path to the generated file.
  let dest = input_nim.change_file_ext("html")
  if nimrod("doc2", input_nim, dest):
    result = dest
  else:
    result = ""


proc build_index(directory: string): string =
  ## Builds the index file for `directory`.
  ##
  ## Returns the empty string if something went wrong, or the path to the
  ## generated index file.
  result = ""
  let
    dest = directory/"theindex.html"
    dir = if directory.len < 1: "." else: directory
  if nimrod("buildIndex", dir, dest):
    if dest.exists_file:
      result = dest


proc extract_unique_directories(filenames: seq[string],
    flatten: bool): seq[string] =
  ## Returns the unique paths for the specified filenames.
  ##
  ## The current dir will be returned as the empty string, you might need to
  ## change that to a single dot for certain operations. The proc guarantees
  ## that all directories are returned once even if they are specified multiple
  ## times in `filenames`.
  ##
  ## If `flatten` is true, only unique prefix paths will be returned. So if the
  ## paths are ``a/b``, ``c/b`` and ``a/b/c``, the path ``a/b/c`` will be
  ## dropped because ``a/b`` already includes it.
  ##
  ## The returned paths will be sorted alphabetically.
  var SEEN = initSet[string]()
  # Extract the paths and filter them to have unique entries.
  for filename in filenames:
    let dir = filename.split_file.dir
    SEEN.incl(dir)

  # Sort them, first could be the empty string.
  var TEMP = to_seq(SEEN.items)
  TEMP.sort(system.cmp)

  # Without flattening return already the list.
  if not flatten or TEMP.len < 1:
    result = TEMP
    return

  # Special case were first directory is the current directory (empty string).
  if TEMP[0].len < 1:
    result = TEMP[0 .. 0]
    return

  # Meh, iterate through seen results removing posterior elements.
  var P = 0
  while P < TEMP.len:
    let
      prefix1 = TEMP[P] & dir_sep
      prefix2 = TEMP[P] & alt_sep
    TEMP = TEMP.filter_it(
      (not it.starts_with(prefix1)) and (not it.starts_with(prefix2)))
    P.inc
  result = TEMP


proc mangle_idx(filename, prefix: string): string =
  ## Reads `filename` and returns it as a string with `prefix` applied.
  ##
  ## All the paths in the idx file will be prefixed with `prefix`. This is done
  ## adding the prefix to the second *column* which is meant to be the html
  ## file reference.
  result = ""
  for line in filename.lines:
    var cols = to_seq(line.split('\t'))
    if cols.len > 1: cols[1] = prefix/cols[1]
    result.add(cols.join("\t") & "\n")


proc collapse_idx(base_dir: string) =
  ## Walks `base_dir` recursively collapsing idx files.
  ##
  ## The files are collapsed to the base directory using the semi full relative
  ## path replacing path separators with underscores. The contents of the idx
  ## files are modified to contain the relative path.
  let base_dir = if base_dir.len < 1: "." else: base_dir
  for path in base_dir.dot_walk_dir({pcFile, pcLinkToFile, pcDir, pcLinkToDir}):
    let (dir, name, ext) = path.split_file
    # Ignore files which are not an index.
    if ext != index_ext: continue
    # Ignore files found in the base_dir.
    if dir.same_file(base_dir): continue
    # Extract the parent paths.
    let dest = base_dir/(name & ext)
    var relative_dir = dir[base_dir.len .. <dir.len]
    if relative_dir[0] == dir_sep or  relative_dir[0] == alt_sep:
      relative_dir.delete(0, 0)
    assert(not relative_dir.is_absolute)

    echo "Flattening ", path, " to ", dest
    dest.write_file(mangle_idx(path, relative_dir))


proc generate_docs(s: Section; src_dir: string): seq[string] =
  ## Generates in `src_dir` documentation according to the `s` configuration.
  ##
  ## Returns the list of relative paths to the generated HTML files.
  assert src_dir.not_nil and src_dir.len > 0
  assert s.doc_modules.not_nil
  result = @[]

  # Save the src_dir too, changing to it to get relative paths.
  let current_dir = get_current_dir()
  finally: current_dir.set_current_dir
  src_dir.set_current_dir

  template loop_files(run: proc(x: string): string): stmt =
    # Helper which loops over the `files` variable calling a doc command.
    for filename in files:
      let out_html = filename.run
      if out_html.len > 0:
        result.add(out_html)

  # Process doc2 files, if any specified.
  var files = if s.doc2_modules.is_nil: scan_files(".nim") else: s.doc2_modules
  loop_files(doc2)
  # Process specified doc files.
  files = s.doc_modules
  loop_files(doc1)
  # Markdown files.
  files = if s.md_files.is_nil: scan_files(".md") else: s.md_files
  loop_files(md)
  # And finally rst files.
  files = if s.rst_files.is_nil: scan_files(".rst") else: s.rst_files
  loop_files(rst)

  # Post process links of generated html files.
  for html_file in scan_files(".html"):
    html_file.post_process_html_local_links

  # Generate theindex.html from idx files.
  let dirs = result.extract_unique_directories(not s.multiple_indices)
  # Do we need to preprocess idx files?
  if not s.multiple_indices:
    for dir in dirs: dir.collapse_idx
  # Ok, now process the files.
  for dir in dirs:
    let index = dir.build_index
    if index.len > 0:
      result.add(index)


proc generate_docs(ini: Ini_config; target: string; force: bool) =
  ## Processes the specified target and generates its documentation.
  ##
  ## Pass the ini configuration which will be combined for `target`. If `force`
  ## is false, the documentation won't be generated if the target directory
  ## already exists.
  switch_to_config_dir:
    let
      conf = ini.combine(target)
      checkout_dir = G.clone_dir/target
      final_dir = ini.default.doc_dir/target

    if not force and final_dir.exists_dir:
      echo "Skipping generation for target '", target, "' as it already exists."
      return

    # Make sure to remove temporary files. When appropriate.
    finally:
      if not keep_temp:
        try: checkout_dir.remove_dir
        except EOS: discard

    echo "Generating docs for target '", target, "'"

    discard git("clone --local --branch " & target &
      " --single-branch --recursive --depth 1 . " & checkout_dir)
    if not checkout_dir.exists_dir:
      quit "Error checking out '" & target & "' into '" & checkout_dir & "'."

    for relative_path in conf.generate_docs(checkout_dir):
      let
        src = checkout_dir/relative_path
        dest = final_dir/relative_path
      echo target/relative_path
      dest.split_file.dir.create_dir
      src.copy_file_with_permissions(dest)


proc create_clone_dir() =
  ## Creates a temporary directory for processing and sets it as global.
  ##
  ## The INI.clone_dir field is updated with the new directory. You have to
  ## make sure it gets erased later.
  G.clone_dir = "ghtemp_" & my_pid
  let full = G.config_dir/G.clone_dir
  if full.exists_dir:
    quit "Can't work with existing dir '" & full & "' already there!"
  full.create_dir


proc validate_target_html(filename: string): bool =
  ## Makes sure `filename` is valid and contains necessary markers.
  ##
  ## Returns false if the program should abort. Reports warnings to stdout.
  template abort(trail: string): stmt =
    echo "The HTML file to update (" & filename & ") " & trail
    return

  if not filename.exists_file: abort "doesn't seem to be a valid file."

  let
    html = filename.read_file
    first = html.find(api_list_start)

  if first < 1: abort "doesn't contain the required " &
    "starting marker '" & api_list_start & "'."

  let eol = html.find(newlines, first)
  if eol < 0: abort "doesn't contain markers on different lines."

  if html.find(api_list_end, eol) < 0: abort "doesn't contain the required " &
    "ending marker '" & api_list_end & "' on a separate line."

  result = true


proc generate_html_links(ini: Ini_config;
    final_doc_dir, target: string): string =
  ## Generates the HTML links for a single `target` found in `final_doc_dir`.
  ##
  ## The specific `target` configuration will be extracted from `ini`. The
  ## returned HTML block will be returned surrounded by
  ## ``<li>target: …</li>`` tags only if there is any content to return. If
  ## no files are to be linked, the empty string is returned.
  let section = ini.combine(target)
  var PATHS: seq[string] = @[] # Relative to final_doc_dir/target.
  if section.link_html.not_nil:
    # Go through the files and figure out which ones are good.
    for path in section.link_html:
      let
        path_ext = add_file_ext(path, "html")
        dest = final_doc_dir/target/path_ext

      if dest.exists_file:
        try:
          let expanded = dest.expand_filename
          if expanded.ends_with(path_ext):
            PATHS.add(path_ext)
          else:
            echo "WARNING: link_html '", path,
              "' resolves to a path with different case => ", expanded, "."
        except EOS:
          echo "WARNING: link_html '", path,
            "' doesn't seem to be valid a valid file."
      else:
        echo "WARNING: link_html '", path, "' not found for ", target, "."
  else:
    # Just grab all HTML files.
    let
      base = final_doc_dir/target
      current_dir = get_current_dir()
    finally: current_dir.set_current_dir
    base.set_current_dir
    for path in dot_walk_dir("."):
      assert path.len > 2
      if path.split_file.ext.to_lower == ".html":
        PATHS.add(path[2 .. <path.len])
    PATHS.sort_numerically

  result = ""
  if PATHS.len < 1: return

  # TODO: Here we presume a relative path, should get it out from the html file.
  PATHS.map_it("""<a href="$1">$2</a>""" % [
    ini.default.doc_dir/target/it, it.change_file_ext("")])
  result = "<li>" & target & ": " & PATHS.join(",\n") & "</li>"


proc generate_html_list(ini: Ini_config;
    targets: tuple[tags, branches: seq[string]]): string =
  ## Returns a string with the HTML block to embed between HTML markers.
  ##
  ## The block is returned scanning the directory where files were generated.
  ## Pass the previously obtained available tags and branches
  let dir = ini.doc_dir
  var
    branches: seq[string] = @[]
    tags: seq[string] = @[]

  for kind, path in dir.walk_dir:
    if kind == pcDir:
      let name = path.extract_filename
      if name in targets.tags: tags.add(name)
      elif name in targets.branches: branches.add(name)
      else: echo "Skipping '" & name & "', not an existing tag/branch."

  branches.sort_numerically
  tags.sort_numerically
  tags.reverse

  var html = ""
  for target in branches: html.add(ini.generate_html_links(dir, target))
  for target in tags: html.add(ini.generate_html_links(dir, target))

  if html.len > 0:
    result = "<ul>\n" & html & "\n</ul>\n"
  else:
    result = "Sorry, wasn't able to generate any documentation.\n"


proc update_html(ini: Ini_config, html: string) =
  ## Updates the HTML file with the `html` code.
  let filename = ini.update_html
  var
    buf = new_string_of_cap(int(filename.get_file_size))
    state = 0
  for line in filename.lines:
    case state
    of 0:
      buf.add(line & "\n")
      if line.find(api_list_start) > 0:
        state = 1
    of 1:
      if line.find(api_list_end) > 0:
        buf.add(html)
        buf.add(line & "\n")
        state = 2
    else:
      buf.add(line & "\n")
  filename.write_file(buf)


proc main() =
  ## Main entry point of the program.
  ##
  ## Processes the parameters, reads config files and if everything is ok, does
  ## some work.
  process_commandline()
  if G.boot:
    generate_templates()
  else:
    let
      ini = G.config_path.load_ini
      targets = ini.obtain_targets_to_work_on
    # Figure out if the final HTML file exists, otherwise avoid doing any work.
    if not ini.update_html.validate_target_html: quit("Invalid html to update.")

    create_clone_dir()
    finally:
      if not keep_temp: remove_dir(G.config_dir/G.clone_dir)

    for target in targets.tags: ini.generate_docs(target, false)
    for target in targets.branches: ini.generate_docs(target, true)
    let html_block = ini.generate_html_list(targets)
    ini.update_html(html_block)
    echo "All done."


when isMainModule: main()
