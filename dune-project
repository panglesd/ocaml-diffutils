(lang dune 3.4)

(name diffutils)

(generate_opam_files true)

(source
 (github panglesd/ocaml-diffutils))

(authors "Paul-Elliot Anglès d'Auriac <peada@free.fr>")

(maintainers "Paul-Elliot Anglès d'Auriac <peada@free.fr>")

(license MIT)

(documentation  "https://panglesd.github.io/ocaml-diffutils/")
(using mdx 0.2)
(package
 (name diffutils)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml dune)
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
