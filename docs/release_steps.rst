===========================================================
What to do for a new public release of gh_nimrod_doc_pages?
===========================================================

* Create new milestone with version number (``vXXX``) at
  https://github.com/gradha/gh_nimrod_doc_pages.
* Create new dummy issue `Release versionname` and assign to that milestone.
* ``git flow release start versionname`` (versionname without v).
* Update version numbers:

  * Modify `README.rst <../README.rst>`_.
  * Modify `docs/changes.rst <changes.rst>`_ with list of changes and
    version/number.
  * Modify `gh_nimrod_doc_pages.babel
    <../gh_nimrod_doc_pages.babel>`_.
  * Modify `gh_nimrod_doc_pages.nim
    <../gh_nimrod_doc_pages.nim>`_.

* ``git commit -av`` into the release branch the version number changes.
* ``git flow release finish versionname`` (the tagname is versionname without
  ``v``). When specifying the tag message, copy and paste a text version of the
  changes log into the message. Add rst item markers.
* Move closed issues to the release milestone.
* ``git push origin master stable --tags``.
* Build binaries for macosx/linux with nake ``dist`` command.
* Attach the binaries to the appropriate release at
  `https://github.com/gradha/gh_nimrod_doc_pages/releases
  <https://github.com/gradha/gh_nimrod_doc_pages/releases>`_.

  * Use nake ``md5`` task to generate md5 values, add them to the release.
  * Follow the tag link of the release and create a hyper link to its changes
    log on (e.g. presumably gh-pages version?).
  * Also add to the release text the Nimrod compiler version noted in the
    release issue.

* Increase version numbers, ``master`` branch gets +0.0.1:

  * Modify `README.rst <../README.rst>`_.
  * Modify `gh_nimrod_doc_pages.nim
    <../gh_nimrod_doc_pages.nim>`_.
  * Modify `gh_nimrod_doc_pages.babel
    <../gh_nimrod_doc_pages.babel>`_.
  * Add to `docs/CHANGES.rst <CHANGES.rst>`_ development version with unknown
    date.

* ``git commit -av`` into ``master`` with *Bumps version numbers for
  development version. Refs #release issue*.
* ``git push origin master stable --tags``.
* Close the dummy release issue.
* Announce at
  `http://forum.nimrod-lang.org/ <http://forum.nimrod-lang.org/>`_.
* Close the milestone on github.
