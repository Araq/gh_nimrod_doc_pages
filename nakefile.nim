import
  bb_nake, bb_system, lazy_rest, sequtils, osproc, bb_os


let
  rst_files = concat(glob("*.rst"), glob("docs"/"*rst"),
    glob("docs"/"dist"/"*rst"))

iterator all_html_files(files: seq[string]): tuple[src, dest: string] =
  for filename in files:
    var r: tuple[src, dest: string]
    r.src = filename
    # Ignore files if they don't exist, nimble version misses some.
    if not r.src.exists_file:
      echo "Ignoring missing ", r.src
      continue
    r.dest = filename.change_file_ext("html")
    yield r


proc rst_to_html(src, dest: string): bool =
  # Runs the unsafe rst generator, and if fails, uses the safe one.
  #
  # `src` will always be rendered, but true is only returned when there weren't
  # any errors.
  try:
    dest.write_file(rst_string_to_html(src.read_file, src))
    result = true
  except:
    dest.write_file(safe_rst_file_to_html(src))


proc doc(start_dir = ".", open_files = false) =
  ## Generate html files from the rst docs.
  ##
  ## Pass `start_dir` as the root where you want to place the generated files.
  ## If `open_files` is true the ``open`` command will be called for each
  ## generated HTML file.
  for rst_file, html_file in rst_files.all_html_files:
    let
      full_path = start_dir / html_file
      base_dir = full_path.split_file.dir
    base_dir.create_dir
    if not full_path.needs_refresh(rst_file): continue
    if not rst_to_html(rst_file, full_path):
      quit("Could not generate html doc for " & rst_file)
    else:
      echo rst_file & " -> " & full_path
      if open_files: shell("open " & full_path)

  echo "All docs generated"


proc doco() = doc(open_files = true)


proc validate_doc() =
  for rst_file, html_file in rst_files.all_html_files():
    echo "Testing ", rst_file
    let (output, exit) = execCmdEx("rst2html.py " & rst_file & " > /dev/null")
    if output.len > 0 or exit != 0:
      echo "Failed python processing of " & rst_file
      echo output


proc clean() =
  for path in dot_walk_dir_rec("."):
    let ext = splitFile(path).ext
    if ext == ".html" or ext == ".idx" or ext == ".exe":
      echo "Removing ", path
      path.removeFile()
  echo "Temporary files cleaned"


proc install_nimble() =
  direshell("nimble install -y")
  echo "Installed"


proc web() = switch_to_gh_pages()
proc postweb() = switch_back_from_gh_pages()

task "clean", "Removes temporal files, mostly.": clean()
task "doc", "Generates HTML docs.": doc()
task "i", "Uses nimble to force install package locally.": install_nimble()

if sybil_witness.exists_file:
  task "web", "Renders gh-pages, don't use unless you are gradha.": web()
  task "check_doc", "Validates rst format with python.": validate_doc()
  task "postweb", "Gradha uses this like portals, don't touch!": postweb()

when defined(macosx):
  task "doco", "Like 'doc' but also calls 'open' on generated HTML.": doco()
