=================================
gh_nimrod_doc_pages release steps
=================================

* Create new milestone with version number (``vXXX``) at
  https://github.com/gradha/gh_nimrod_doc_pages/milestones.
* Create new dummy issue `Release versionname` and assign to that milestone.
* ``git flow release start versionname`` (versionname without v).
* Update version numbers:

  * Modify `README.rst <../README.rst>`_.
  * Modify `docs/changes.rst <changes.rst>`_ with list of changes and
    version/number.
  * Modify `gh_nimrod_doc_pages.nimble
    <../gh_nimrod_doc_pages.nimble>`_.
  * Modify `gh_nimrod_doc_pages.nim
    <../gh_nimrod_doc_pages.nim>`_.

* ``git commit -av`` into the release branch the version number changes.
* ``git flow release finish versionname`` (the tagname is versionname without
  ``v``). When specifying the tag message, copy and paste a text version of the
  changes log into the message. Add rst item markers.
* Move closed issues to the release milestone.
* Build binaries for macosx/linux with nake ``dist`` command.
* Archive binaries.
* ``git push origin master stable --tags``.
* Attach the binaries to the appropriate release at
  `https://github.com/gradha/gh_nimrod_doc_pages/releases
  <https://github.com/gradha/gh_nimrod_doc_pages/releases>`_.

  * Use nake ``md5`` task to generate md5 values, add them to the release.
  * Follow the tag link of the release and create a hyper link to its changes
    log on (e.g. presumably gh-pages version?).
  * Also add to the release text the Nim compiler version noted in the
    release issue.

* Increase version numbers, ``master`` branch gets +0.0.1:

  * Modify `README.rst <../README.rst>`_.
  * Modify `gh_nimrod_doc_pages.nim
    <../gh_nimrod_doc_pages.nim>`_.
  * Modify `gh_nimrod_doc_pages.nimble
    <../gh_nimrod_doc_pages.nimble>`_.
  * Add to `docs/changes.rst <changes.rst>`_ development version with unknown
    date.

* ``git commit -av`` into ``master`` with *Bumps version numbers for
  development version. Refs #release issue*.

* Regenerate static website.

  * Make sure git doesn't show changes, then run ``nake web`` and review.
  * ``git add . && git commit``. Tag with
    `Regenerates website. Refs #release_issue`.
  * ``./nakefile postweb`` to return to the previous branch. This also updates
    submodules, so it is easier.

* ``git push origin master stable gh-pages --tags``.
* Close the dummy release issue.
* Announce at `http://forum.nim-lang.org/t/460
  <http://forum.nim-lang.org/t/460>`_.
* Close the milestone on github.
