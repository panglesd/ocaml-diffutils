(lang dune 3.4)

(name diffutils)

(generate_opam_files true)

(source
 (github panglesd/ocaml-diffutils))

(authors "Paul-Elliot Anglès d'Auriac <peada@free.fr>")

(maintainers "Paul-Elliot Anglès d'Auriac <peada@free.fr>")

(license MIT)

(documentation "https://panglesd.github.io/ocaml-diffutils/")

(using mdx 0.2)

(package
 (name diffutils)
 (synopsis "A library to manipulate diff, patch, diff3, patch3, merge...")
 (description "A library to manipulate diff, patch, diff3, patch3, merge. Works for any type but has special support for strings ones.")
 (depends
  (ocaml (>= 4.08))
   dune
   fmt
  (mdx :with-test))
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
