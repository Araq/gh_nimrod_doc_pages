===============================
gh_nimrod_doc_pages usage guide
===============================

This is the usage guide for the ``gh_nimrod_doc_pages`` tool of
`gh_nimrod_doc_pages <https://github.com/gradha/gh_nimrod_doc_pages>`_. This
tool is a small helper for developers who want to generate and maintain a
`GitHub Pages website <https://pages.github.com>`_ using the documentation of
their `Nim <http://nim-lang.org>`_ source code. Once you create a small
``.ini`` configuration file with some parameters, ``gh_nimrod_doc_pages`` will
read this file and produce HTML files from all your ``.rst``, ``.md`` and
``.nim`` files for any tags and branches you want.

Here is a small sample of websites using ``gh_nimrod_doc_pages`` and their
``gh-pages`` branch:

* http://gradha.github.io/nimrod-ouroboros/ (`gh-pages
  <https://github.com/gradha/nimrod-ouroboros/tree/gh-pages>`_).
* http://gradha.github.io/seohtracker-logic/ (`gh-pages
  <https://github.com/gradha/seohtracker-logic/tree/gh-pages>`_).
* https://github.com/MrJohz/appdirs (`gh-pages
  <https://github.com/MrJohz/appdirs/tree/gh-pages>`_).

More examples can be found linked from http://gradha.github.io.


Installation
============

Binaries
--------

Precompiled binaries for some platforms are provided through `GitHub releases
<https://github.com/gradha/gh_nimrod_doc_pages/releases>`_.  The binaries are
statically linked, so you can in theory put them anywhere on your system and
have them work fine.

The binary package provides the normal release binary and another version with
the ``d`` suffix. This version is compiled in debug mode. If you experience a
crash running the software you can run again the problematic command line with
the debug binary and get a useful stack trace to attach to your bug report.


Source code
-----------

Stable version
**************

Install the `Nim compiler <http://nim-lang.org>`_. Then use `Nim's Nimble
package manager <https://github.com/nim-lang/nimble>`_ to install::

    $ nimble update
    $ nimble install gh_nimrod_doc_pages
    $ gh_nimrod_doc_pages -v


Development version
*******************

Install the `Nim compiler <http://nim-lang.org>`_. Then use `Nim's
Nimble package manager <https://github.com/nim-lang/nimble>`_ to install
locally the github checkout::

    $ git clone --recursive https://github.com/gradha/gh_nimrod_doc_pages
    $ cd gh_nimrod_doc_pages
    $ nimble install -y

If you don't mind downloading the git repo every time you can also use Nimble
to install the latest development version::

    $ nimble update
    $ nimble install -y gh_nimrod_doc_pages@#head


Usage
=====

3rd party dependencies
----------------------

For the correct usage of the program several binaries have to be found in your
``$PATH``. For instance, to generate HTML documentation from Nim sources you
need to have available the Nim compiler. Git support is provided by your OS
binary of the Git tool.

If you are missing any of these tools the program will refuse to run.


Command line switches
---------------------

Usage parameters:

-h, --help            Displays commandline help and exits.
-v, --version         Displays the current version and exists.
-c, --config STRING   Specify a path to a specific configuration ini or a directory containing a gh_nimrod_doc_pages.ini file. You can't use this switch together with --boot.
-b, --boot            Creates missing files required for operation in the working directory, which should be inside a git tree with a branch named gh-pages. You can't use this switch together with --config.

The actual interesting parameters are in the ``.ini`` file you can generate
with the ``--boot`` switch. The template ``.ini`` is heavily commented and
contains examples.


Setting up a project without the gh-pages branch
------------------------------------------------

If you are a Nim coder and want to use this tool, chances are you don't use
the ``gh-pages`` branch. These are the steps you would do to create and
populate it:

1. ``$ cd path/to/your/git/checkout``
2. ``$ git checkout --orphan gh-pages`` to start a ``gh-pages`` branch without
   parent.
3. ``$ git rm -rf .`` to remove all the files carried over from whatever branch
   you ran the previous command.
4. ``$ gh_nimrod_doc_pages -b`` to create template files.
5. Modify the ``gh_nimrod_doc_pages.ini`` and ``index.html`` files to suit your
   needs. In particular, if your project doesn't have any tags yet, you need to
   specify the ``branches`` parameter or no documentation will be generated at
   all.
6. ``$ gh_nimrod_doc_pages -c .`` to process the configuration file and
   generate all the specified documentation.
7. ``$ git add . && git commit -v`` to add and commit all the files.
8. ``$ git push --set-upstream origin gh-pages`` to tell git you want to push
   stuff in the future from the ``gh-pages`` branch automatically.


Setting up a project with an existing gh-pages branch
-----------------------------------------------------

If you have an existing ``gh-pages`` branch the steps change slightly to
accommodate your existing website. The steps could be something like this:

1. ``$ git checkout gh-pages`` to switch to your website branch.
2. ``$ gh_nimrod_doc_pages -b`` to create template files. Files which already
   exist won't be overwritten.
3. ``$ git status`` will show you the new template files, remove everything
   except the ``gh_nimrod_doc_pages.ini`` file. Or copy the ``.ini`` somewhere
   else and purge and checkout again the branch. The purpose is to get rid of
   the template debris.
4. ``$ gh_nimrod_doc_pages -c .`` will tell you if your HTML file is correctly
   set up, explaining what markers have to be added to it. You need a pair of
   lines, everything inside will be handled by gh_nimrod_doc_pages.
5. After a few attempts you should have your HTML file updated and a new
   documentation directory generated. Commit and push the changes.


Updating generated docs in the future
-------------------------------------

Once you have set up ``gh_nimrod_doc_pages`` updating documentation is very
simple: you switch to your ``gh-pages`` branch, run ``gh_nimrod_doc_pages``,
review the changes and commit/push.


Typical gotchas
---------------

* The default generation behaviour is to process all the repository tags and
  ignore all branches. If you don't have tags, running the program with the
  default parameters won't do much. Modify the ``branches`` parameter in the
  ``gh_nimrod_doc_pages.ini`` file to make it work. Setting that to ``master``
  usually does the trick, but it depends on how you use branches and for what.
* During the generation of documentation from ``.nim`` files in a project
  where there are many ``.nim`` files with specific nimrod configuration
  parameters, the ``doc2`` command is likely not seeing those because it
  doesn't change directory to those files. For the moment you have to use the
  ``doc`` command instead.
* In general the ``doc2`` program is unstable: three of the four source files
  of this program can't be rendered with ``doc2`` because it crashes. Please
  report these issues at `https://github.com/Araq/Nimrod/issues
  <https://github.com/Araq/Nimrod/issues>`_.
