import htmlparser, xmltree, strtabs, os, strutils, bb_system, streams,
  globals_for_gh, macros, lazy_rest_pkg/lrstgen

## gh_nimrod_doc_pages html support files.
##
## For project information see https://github.com/gradha/gh_nimrod_doc_pages.
## This module contains code to deal with
## http://forum.nimrod-lang.org/t/473/1#2515. Since current Nimrod code can't
## preserve exactly all the HTML attributes, this module implements an HTML
## rewriter which tries to find the first tag in the original file and copy up
## to this byte verbatim.
##
## Hopefully this won't break final HTML.

type
  First_tag = tuple[pos: int, tag: string]
  pair = tuple[src, dest: string] # Holds text replacement pairs.
  Header_info* = tuple[level: int, href, text: string]


proc post_process_html_local_links(html: PXmlNode, filename: string): bool =
  ## Changes href attributes to point to .html versions of local files.
  ##
  ## This allows authors to leave local links with the .rst/.md/.txt extension,
  ## which is the correct thing, and still have valid links in the generated
  ## docs. Run this after all the HTML files have been created, since this
  ## looks for actual local files to avoid 404 mistakes.
  ##
  ## Pass the HTML tree to the proc and the path to this file. The proc will
  ## return false if no changes were done, or true and modify the input html
  ## PXmlNode.
  assert html.not_nil

  for a in html.find_all("a"):
    let href = a.attrs["href"]
    if not href.is_nil:
      let (dir, name, ext) = href.split_file
      case ext.to_lower
      of ".rst", md_extensions[0], md_extensions[1], ".txt":
        when md_extensions.len != 2: {.fatal: "Missing case checks".}
        let
          rel_path = href.change_file_ext("html")
          test_path = filename.split_file.dir/rel_path
        if test_path.exists_file:
          a.attrs["href"] = rel_path
          result = true


proc find_local_links(html: PXmlNode, filename: string): seq[pair] =
  ## Equivalent of post_process_html_local_links but returning pairs.
  ##
  ## Instead of modifying `html` directly, which is problematic for random HTML
  ## files (see https://github.com/Araq/Nimrod/issues/1276), this function uses
  ## PXmlNode to find attributes to replace, but returns the pairs which would
  ## have to be replaced.
  ##
  ## If no links are found, returns a zero length sequence.
  result = @[]
  assert html.not_nil

  for a in html.find_all("a"):
    let href = a.attrs["href"]
    if not href.is_nil:
      let (dir, name, ext) = href.split_file
      case ext.to_lower
      of ".rst", md_extensions[0], md_extensions[1], ".txt":
        when md_extensions.len != 2: {.fatal: "Missing case checks".}
        let
          rel_path = href.change_file_ext("html")
          test_path = filename.split_file.dir/rel_path
        if test_path.exists_file:
          result.add((src: href, dest: rel_path))


proc find_first_tag(html: PXmlNode): First_tag =
  ## Finds in an PXmlNode the first child with a valid element tag.
  ##
  ## Some HTML files contain previous comments. This proc will return a tuple
  ## with the index to the first html child of the xnElement kind and its text
  ## representation, or a tuple with negative and nil.
  assert html.not_nil
  result.pos = -1
  var pos = 0
  for child in html:
    if child.kind == xnElement:
      result.tag = child.tag
      result.pos = pos
      return
    pos.inc


proc load_prefix(tag, filename: string): string =
  ## Loads `filename` and returns the prefix up to the first `tag`.
  ##
  ## Returns nil if something went wrong or the tag was not found. Otherwise
  ## returns as a string the text up to ``<tag...``.
  let
    buf = filename.read_file
    pos = buf.find("<" & tag)
  if pos < 0:
    return
  result = buf[0 .. <pos]


proc find_href(s: string; pos: int; substr: string): int =
  ## Finds `substr` href inside `s` starting from `pos`.
  ##
  ## This essentially wraps strutils.find but makes sure than in short reverse
  ## length an `href` attribute is found.
  result = pos
  while result >= 0:
    result = s.find(substr, result)
    if result > 0:
      # Make sure in the previous substring there is an href=
      let prefix = s[max(0, result - 8) .. result].to_lower
      if prefix.find("href=") >= 0:
        return
      else:
        # Just increase the result as starting position for next loop
        result.inc
  result = -1


proc post_process_html_local_links*(filename: string) =
  ## Changes href attributes to point to .html versions of local files.
  ##
  ## This allows authors to leave local links with the .rst/.md/.txt extension,
  ## which is the correct thing, and still have valid links in the generated
  ## docs. Run this after all the HTML files have been created, since this
  ## looks for actual local files to avoid 404 mistakes.
  ##
  ## The file won't be updated if no local links are updated.
  when false:
    # DOM style based replacements.
    let
      html = filename.load_html
    if not html.post_process_html_local_links(filename):
      return

    proc save() =
      echo "Mangling local links in ", filename
      filename.write_file($html)

    let first_tag = html.find_first_tag
    # If there is no tag in the input, bail out.
    if first_tag.pos < 0:
      save()
      return

    # Try to extract the right HTML header.
    var prefix = first_tag.tag.load_prefix(filename)
    if prefix.is_nil:
      save()
      return

    # Nice! Lets patch it along with all the other nodes.
    for f in first_tag.pos .. <html.len:
      prefix.add($(html[f]))
    filename.write_file(prefix)
    echo "Patching local links in ", filename
  else:
    # String based replacements. Ugly, but at the moment there is no other way
    # to keep the original HTML intact without damaging transformations.
    let
      html = filename.load_html
      pairs = html.find_local_links(filename)
    if pairs.len < 1:
      return

    # Ok, loop over the replacement pairs searching for the strings to change.
    var
      buf = filename.read_file
      pos = 0
    for src, dest in pairs.items:
      let start = buf.find_href(pos, src)
      if start < 0:
        quit "Inconsistency patching mangled links. Please report as a bug!"
      let
        prefix = buf[0 .. <start]
        postfix = buf[start + src.len .. <buf.len]
      buf = prefix & dest & postfix
      pos = prefix.len + dest.len

    filename.write_file(buf)
    echo "Patching local links in ", filename


proc recursive_text*(n: PXmlNode): string =
  ## Extracts all possible inner text ignoring tags.
  ##
  ## The stdlib innerText proc doesn't deal with headers containing other inner
  ## tags like ``<code>``.
  result = ""
  if n.kind != xnElement:
    return

  for child in n.items:
    if child.kind in {xnText, xnEntity}:
      result.add(child.text)
    else:
      result.add(child.recursive_text)


proc extract_header(n: PXmlNode, result: var seq[Header_info]) =
  ## Extracts from header node `n` the identifier and adds it to `result`.
  ##
  ## If the node can't be extracted safely `result` won't be changed. Empty
  ## headers won't be added either.
  assert n.kind == xnElement
  if n.attrs.is_nil:
    return

  let text = n.recursive_text.strip
  if text.len < 1:
    return

  var level = 0
  case n.tag
  of "h1": level = 1
  of "h2": level = 2
  of "h3": level = 3
  of "h4": level = 4
  of "h5": level = 5
  of "h6": level = 6
  else: return

  if not n.attrs.has_key("id"):
    return

  result.add((level, n.attrs["id"], text))


proc find_all_headers*(n: PXmlNode, result: var seq[Header_info]) =
  ## Iterates over all the children of `n` returning those matching `h?`.
  ##
  ## Found headers will be appended to the `result` sequence, which can't be
  ## nil or the proc will crash. The returned header level info is equal to the
  ## tag level (``h1`` => 1).
  assert result.not_nil
  assert n.kind == xnElement

  for child in n.items():
    if child.kind != xnElement:
      continue

    case child.tag
    of "h1", "h2", "h3", "h4", "h5", "h6":
      child.extract_header(result)
    else:
      child.find_all_headers(result)


proc find_all_headers(html: string): seq[Header_info] =
  ## Wraps extraction of headers from an HTML file.
  ##
  ## Returns the found headers or the empty list.
  let node = html.new_string_stream.parse_html
  result = @[]
  node.find_all_headers(result)


proc tocify_markdown*(filename: string) {.raises: [].} =
  ## Reads `filename` HTML and generates its index companion file.
  ##
  ## The `filename` usually contains the HTML of generated markdown code but in
  ## theory this could work with anything. The generated index will be written
  ## to the IdxExt variant.
  ##
  ## The format of the index file will conform to `Nim's idx file format
  ## <http://nim-lang.org/docgen.html#index-idx-file-format>`_. If there is any
  ## error or the index file ends up empty, the index file won't be created.
  template abort() =
    echo "Error tocifying markdown: " & get_current_exception_msg()
    return

  var toc: seq[Header_info]
  try:
    toc = filename.read_file.find_all_headers
    if toc.len < 1:
      return
  except E_Base:
    abort()

  var
    prefix = filename
    GENERATOR: TRstGenerator

  try: GENERATOR.init_rst_generator(out_html, filename)
  except EOverflow, EInvalidValue: abort()

  if toc[0].level == 1:
    # Special first entry reserved for the title.
    GENERATOR.set_index_term("", toc[0].text)
    system.delete(toc, 0)

  for level, href, text in toc.items:
    GENERATOR.set_index_term(href, text, level.repeat_char & text)

  let idx = filename.change_file_ext("idx")
  try: idx.remove_file
  except EOS: abort()
  try: GENERATOR.write_index_file(idx)
  except E_Base: abort()


proc test() =
  ## Runs internal tests to see if all works as expected.
  let
    filename = "footest.html"
    input_text = """
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!--  This file is generated by Nimrod. -->
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
<title></title>
<body>
<a
href='README.rst'>foo</a>
</body></html>"""

  filename.write_file(input_text)
  filename.post_process_html_local_links
  echo filename.read_file


when isMainModule: test()
