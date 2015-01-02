import
  bb_nake, bb_system, lazy_rest, sequtils, osproc, bb_os, gh_nimrod_doc_pages


const
  pkg_name = "gh_nimrod_doc_pages"
  bin_name = pkg_name & "-" & gh_nimrod_doc_pages.version_str & "-binary"


let
  rst_files = concat(glob("*.rst"), glob("docs"/"*rst"),
    glob("docs"/"dist"/"*rst"), glob("vagrant_linux"/"*.rst"))

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

proc run_vagrant() =
  ## Takes care of running vagrant and running build_platform_dist *there*.
  run_vagrant("""
    nimble build
    nake platform_dist
    """)


proc build_platform_dist() =
  ## Runs some compilation tasks to produce the binary dists.
  let
    platform = "-" & host_os & "-" & host_cpu
    dist_bin_dir = dist_dir/bin_name & platform
    release_bin = dist_bin_dir/pkg_name
    debug_bin = dist_bin_dir/pkg_name & "d"

  # Cleanup.
  dist_dir.remove_dir
  dist_bin_dir.create_dir

  # Build the binary.
  dire_shell "nimble build"
  nimcache_dir.remove_dir
  dire_shell(nim_exe, "c -d:release -o:" & release_bin, pkg_name)
  nimcache_dir.remove_dir
  test_shell(nim_exe, "c -d:debug -o:" & debug_bin, pkg_name)

  # Zip the binary and remove the uncompressed files.
  pack_dir(dist_bin_dir)


proc md5() =
  ## Inspects files in zip and generates markdown for github.
  let templ = """
Add the following notes to the release info:

Compiled with Nimrod version https://github.com/Araq/Nim/commit/$$1 or https://github.com/Araq/Nimrod/tree/v0.9.6.

[See the changes
log](https://github.com/gradha/gh_nimrod_doc_pages/blob/v$1/docs/changes.rst).

Binary MD5 checksums:""" % [gh_nimrod_doc_pages.version_str]
  show_md5_for_github(templ)


proc build_dist() =
  ## Runs all the distribution tasks and collects everything for upload.
  doc()
  build_platform_dist()
  run_vagrant()
  collect_vagrant_dist()
  md5()


task "clean", "Removes temporal files, mostly.": clean()
task "doc", "Generates HTML docs.": doc()
task "i", "Uses nimble to force install package locally.": install_nimble()

if sybil_witness.exists_file:
  task "web", "Renders gh-pages, don't use unless you are gradha.": web()
  task "check_doc", "Validates rst format with python.": validate_doc()
  task "postweb", "Gradha uses this like portals, don't touch!": postweb()
  task "vagrant", "Runs vagrant to build linux binaries": run_vagrant()
  task "platform_dist", "Build dist for current OS": build_platform_dist()
  task "dist", "Performs distribution tasks for all platforms": build_dist()
  task "md5", "Computes md5 of files found in dist subdirectory.": md5()

when defined(macosx):
  task "doco", "Like 'doc' but also calls 'open' on generated HTML.": doco()
