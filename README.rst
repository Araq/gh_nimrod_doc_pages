==========================
gh_nimrod_doc_pages readme
==========================

**gh_nimrod_doc_pages** is a small helper for developers who want to generate
and maintain a `GitHub Pages website <https://pages.github.com>`_ using the
documentation of their `Nim <http://nim-lang.org>`_ source code. Once you
create a small ``.ini`` configuration file with some parameters,
``gh_nimrod_doc_pages`` will read this file and produce HTML files from all
your ``.rst``, ``.md`` and ``.nim`` files for any tags and branches you want.

Here is a small sample of websites using ``gh_nimrod_doc_pages`` and their
``gh-pages`` branch:

* http://gradha.github.io/nimrod-ouroboros/ (`gh-pages
  <https://github.com/gradha/nimrod-ouroboros/tree/gh-pages>`_).
* http://gradha.github.io/seohtracker-logic/ (`gh-pages
  <https://github.com/gradha/seohtracker-logic/tree/gh-pages>`_).
* https://github.com/MrJohz/appdirs (`gh-pages
  <https://github.com/MrJohz/appdirs/tree/gh-pages>`_).

More examples can be found linked from http://gradha.github.io.


Changes
=======

This is development version 0.2.5. For a list of changes see the
`docs/changes.rst file <docs/changes.rst>`_.


License
=======

`MIT license <license.rst>`_.


Usage
=====

The installation and usage of the ``gh_nimrod_doc_pages`` binary is covered in
the `usage guide <docs/gh_nimrod_doc_pages_usage.rst>`_. Documentation for all
releases of this software in HTML format should be available online at
http://gradha.github.io/gh_nimrod_doc_pages/.


Git branches
============

This project uses the `git-flow branching model
<https://github.com/nvie/gitflow>`_ with reversed defaults. Stable releases are
tracked in the ``stable`` branch. Development happens in the default ``master``
branch.


Feedback
========

You can send me feedback through `github's issue tracker
<https://github.com/gradha/gh_nimrod_doc_pages/issues>`_. I also take a look
from time to time to `Nim's forums <http://forum.nim-lang.org>`_ where
you can talk to other nimrod programmers.
