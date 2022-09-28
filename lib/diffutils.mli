(** A word on terminology.

    - A patch is the smallest information needed to go from one sequence to
      another. Its main use is to update the original file, while being as small
      as possible.
    - On the contrary, a diff consists of the two files organized with common
      and special parts. Contrary to the patch, it is not minimal, in the sense
      that it contains the whole two files. It’s main uses is to display the
      differences to a human.

    There are multiple kind of patch, depending on the operations allowed to go
    from one file to an other. The most famous are:

    - the Longest Common Subsequence (LCS), where deletion and addition are
      allowed,
    - the Lehvenstein distance, where deletion, addition and substitution are
      allowed
    - Block diff where a copy of a whole block from the input is allowed
    - ...

    On the contrary, for diffs, to my knowledge, there is only one used way to
    display differences: the LCS way.

    There is also the diff3 and the merge.

    In this library, we implement a O(nd) algorithm for a diff, and an algorithm
    to create diff3 from diffs or patches, as well as tools and printer around
    it.*)

module type S = sig
  type t

  val equal : t -> t -> bool
  val pp : t Fmt.t
end

module Line :  sig
  type t = string

  val equal : t -> t -> bool
  val pp : t Fmt.t
end

module LCS (S : S) : sig
  type input = S.t list
  (** {1 Diff between two lists of type {S.t}} *)

  type hunk = [ `Keep of int | `Remove of int | `Add of S.t ]
  type patch = hunk list

  val get_patch : orig:input -> new_:input -> patch
  val apply_patch : input -> patch -> input

  type conflict2 = { orig : S.t list; new_ : S.t list }
  type diff = [ `Same of S.t | `Diff of conflict2 ] list

  val diff_of_patch : orig:input -> patch -> diff
  val diff : orig:input -> new_:input -> diff

  type patch_printer

  val patch_printer :
    keep:S.t Fmt.t ->
    add:S.t Fmt.t ->
    remove:S.t Fmt.t ->
    sep:unit Fmt.t ->
    context:int ->
    patch_printer

  type diff_printer

  val diff_printer : same:S.t Fmt.t -> diff:conflict2 Fmt.t -> diff_printer
  val git_patch_printer : patch_printer
  val git_diff_printer : diff_printer
  val html_diff_printer : diff_printer
  val pp_patch : patch Fmt.t
  val pp_diff : diff_printer -> diff Fmt.t

  (** {1 Diff between three lists of type {S.t}} *)

  type patch_conflict = { you : hunk list; me : hunk list }

  type hunk3 =
    [ `Keep of int | `Me of patch | `You of patch | `Conflict of patch_conflict ]

  type patch3 = hunk3 list

  val diff_patch : patch -> patch -> patch3

  type unresolved_merge =
    [ `Ok of S.t | `Conflict of input * input * input ] list

  val diff3 : base:input -> me:input -> you:input -> patch3
  val patch3 : input -> patch3 -> unresolved_merge

  val resolve_merge :
    unresolved_merge -> (old:input -> me:input -> you:input -> input) -> input

  type unresolved_merge_printer = {
    same : S.t Fmt.t;
    conflict : (S.t list * S.t list * S.t list) Fmt.t;
  }

  val git_merge_printer : unresolved_merge_printer

  val print_unresolved_merge :
    unresolved_merge_printer -> unresolved_merge -> unit

  val pp_unresolved_merge : unresolved_merge_printer -> unresolved_merge Fmt.t
end
