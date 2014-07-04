import htmlparser, xmltree, strtabs, os, strutils, global_patches, streams,
  globals_for_gh, macros

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
          RESULT = true


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
