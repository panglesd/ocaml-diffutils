# ocaml-diffutils

An OCaml library to manipulate diffs, patches, diff3 and merges!

```ocaml
# open Diffutils ;;
(** A "Longest-common-subsequence" diff on sequence of lines *)
# module Diff = LCS(Line) ;;
# let orig = [ "a" ; "b" ; "c"] and new_ = [ "b" ; "x" ; "c" ] ;;
# let diff = Diff.diff ~orig ~new_ ;;
# Fmt.pr "%a" (Diff.pp_diff Diff.git_diff_printer) diff ;;
-a
 b
+x
 c
# let base = ["a" ; "b" ; "c"] and me = ["a" ; "e" ; "c"] and you = ["a" ; "z" ; "c" ] ;;
# let diff = Diff.diff3 ~base ~me ~you ;;
# Fmt.pr "%a" (Diff.pp_unresolved_merge Diff.git_merge_printer) diff;;
a
>>>
e
|||
b
===
z
<<<
c
```

This is a work in progress. It is usable but the API might change.

First, a bit of terminology:

- Usually, by a `diff` or `patch` we refer to a sequence of edits to go from one
  sequence (for instance of lines) to another sequence. There are multiple way
  to define what is an edit, usually corresponding to an [edit
  distance](https://en.wikipedia.org/wiki/Edit_distance):
  - `LCS` (for longest common subsequence) where the allowed operations are
    addition and deletion
  - the Levenhstein distance for addition, deletion and substitution
  - [block diffs](http://www.daemonology.net/bsdiff/), where copying a whole
    block from the input correspond to one operation. I don’t think the optimal
    distance/diff can be found efficiently.
- There are mainly two usages of those diff/patch:
  - Visualize more easily the changes that occurred from one file to another.
    Very useful! I will refer to diff/patch objects meant to be used like this
    as "diff". Note that I only know use of LCS diffs.
  - Retrieve the modified file from the original one and the diff/patch. Very
    useful! I will refer to diff/patch objects meant to be used like this as
    "patches". Block diffs seems the most suitable for this. It is mostly used
    to save bandwidth when updating files remotely, see for instance
    [courgette](https://www.chromium.org/developers/design-documents/software-updates-courgette/).

## What is this library about?

The goal of this library is not to efficiently implement an efficient diff
algorithm, but to provide tools to manipulate diffs and patches. It does include
an LCS diff algorithm though.

Currently, it is focused on LCS diffs and patches. With it, you can:

- Get a patch of two input sequences `a` and `b`. The patch contains the minimal
  information to recover `b` from `a`.
- Apply a patch to an input sequence.
- Get a diff of two input sequences `a` and `b`. The diff is self-contained and
  ready to be printed in various format. The algorithm currently implemented is
  the Myers algorithm (not a variant) with time complexity `O(nd)` and space
  complexity `O(n²)`. See [here](http://www.xmailserver.org/diff2.pdf) and
  [there](https://blog.jcoglan.com/2017/02/12/the-myers-diff-algorithm-part-1/).
- Print diffs and patches in various format (such as an html visualization!)
- (TODO) Parse patches/diff written in standard format.
- Find a (LCS) patch3 from three input sequences `base`, `me` and `you`. A
  patch3 contains the minimal information to recover `me` and `you` from `base`.
- Find a (LCS) diff3 from three input sequences `base`, `me` and `you`. A diff3
  is self-contained and ready to be printed (and resolved if there are
  conflicts).
- Resolve conflicts in diff3
- Print and parse diff3 in various formats
