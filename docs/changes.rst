===============================
gh_nimrod_doc_pages changes log
===============================

Changes log for `gh_nimrod_doc_pages
<https://github.com/gradha/gh_nimrod_doc_pages/>`_.

v0.2.3 ????-??-??
-----------------

* `Recognises .markdown extension too
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/26>`_.
* `Fixed infinite loop post processing html links
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/27>`_.
* `Support markdown generation with fenced blocks extension
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/28>`_.
* `Replaced local patches with badger_bits
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/33>`_.
* `Modified default directory for HTML files
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/32>`_. You can keep
  using the default ``docs`` directory for generated output, but since this may
  conflict with other same named directories in other branches it is a good
  idea to pick something unique for the ``gh-pages`` branch.
* `Moved badger bits submodule to nimble package
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/37>`_.
* `Uses lazy_rest submodule for faster HTML generation
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/9>`_. Some of the
  improvements this brings:

 * Code block line numbering.
 * Check for infinite include recursion.
 * Syntax highlight for more languages.
 * No separate process spawning, so it should be faster.

* `Improved --version switch output
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/38>`_.
* `Ignores nakefile.nim during default source scan
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/7>`_.
* `Detects and favours nim compiler
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/36>`_.
* `Changed doc to be the default, and doc2 to be optional
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/31>`_.
* `Disable processing of configuration files for module documentation
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/39>`_.
* `Generates .idx files for markdown files
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/16>`_.

v0.2.2 2014-06-18
-----------------

* `Added markdown rendering support
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/5>`_.
* `Added Babel stable installation
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/4>`_.
* `Patched local .rst/.md links in generated HTML
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/17>`_.
* `Fixed boot template title
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/18>`_.
* `Detects incorrect hyperlink case
  <https://github.com/gradha/gh_nimrod_doc_pages/issues/19>`_.

v0.2.0 2014-06-01
-----------------

* Initial release.
