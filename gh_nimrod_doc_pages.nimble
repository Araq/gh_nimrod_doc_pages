[Package]
name         = "gh_nimrod_doc_pages"
version      = "0.2.3"
author       = "Grzegorz Adam Hankiewicz"
description  = "Generates a GitHub documentation website for Nim projects."
license      = "MIT"
bin          = "gh_nimrod_doc_pages"

InstallFiles = """

gh_nimrod_doc_pages.nimble

"""

[Deps]
Requires: """

argument_parser >= 0.2.0
https://github.com/gradha/badger_bits.git
lazy_rest >= 0.2.0
midnight_dynamite >= 0.2.3

"""
