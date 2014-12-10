[Package]
name         = "gh_nimrod_doc_pages"
version      = "0.2.3"
author       = "Grzegorz Adam Hankiewicz"
description  = "Generates a GitHub documentation website for Nimrod projects."
license      = "MIT"
bin          = "gh_nimrod_doc_pages"

InstallFiles = """

gh_nimrod_doc_pages.babel

"""

[Deps]
Requires: "argument_parser >= 0.2.0, midnight_dynamite >= 0.2.3, https://github.com/gradha/badger_bits.git"
