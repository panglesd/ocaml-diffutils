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

module S_String : sig
  type t = string

  val equal : t -> t -> bool
  val pp : t Fmt.t
end

module LCS (S : S) : sig
  type input = S.t list

  (** {1 Between two lists} *)

  (** {2 Patches}

      A patch is a minimal information to get from a sequence of values of type
      {!S.t} to another. *)

  (** In LCS (Longest Common Subsequence), the only operations allowed are
      {!Keep} {!Remove} and {!Add}. We omit information already present in the
      original sequence. *)
  module Patch : sig
    type hunk = Keep of int | Remove of int | Add of S.t
    type t = hunk list

    val get_patch : orig:input -> new_:input -> t

    val apply : input -> t -> input
    (** From a {!patch} and the original sequence, one can get the new sequence *)

    type printer

    val printer :
      keep:S.t Fmt.t ->
      add:S.t Fmt.t ->
      remove:S.t Fmt.t ->
      sep:unit Fmt.t ->
      context:int ->
      printer

    val git_printer : printer
    val pp : t Fmt.t
  end
  (** {2 Diffs}

      A diff defines two sequence and how they relate to each other. *)

  (** {2 Printing} *)

  module Diff : sig
    (** In LCS (Longest Common Subsequence), the only operations allowed are
        {!Keep} {!Remove} and {!Add}. We omit information already present in the
        original sequence. *)
    type conflict2 = { orig : S.t list; new_ : S.t list }
    (** In a value of type {!conflict2}, the sequence [orig] and [new_] should
        have no common value. *)

    type hunk = Same of S.t | Diff of conflict2
    type t = hunk list

    val diff : orig:input -> new_:input -> t

    val to_inputs : t -> input * input
    (** From a {!diff} one can recover both sequences. The original is first. *)

    val diff_of_patch : orig:input -> Patch.t -> t
    (** From a {!patch} and the original sequence, one can get a diff *)

    type printer

    val printer : same:S.t Fmt.t -> diff:conflict2 Fmt.t -> printer
    val git_printer : printer
    val html_printer : printer
    val pp : printer -> t Fmt.t
  end

  (** {1 Between three lists of type {!S.t}} *)

  (** {2 Patches} *)
  module Conflict : sig
    type t = { base : input; you : Patch.t; me : Patch.t }
    (** The reason [you] and [me] are [patch] and not [input] is to be able to
        quickly check if one is equal to [base]. [you] and [me] as [input] can
        be recovered using {!apply_patch} with [base]. *)
  end

  module Diff3 : sig
    type hunk = Same of S.t | Diff of Conflict.t

    type t = hunk list
    (** A diff3 defines three lists and how they relate to each others. *)

    val diff3 : base:input -> me:input -> you:input -> t

    val to_inputs : t -> input * input * input
    (** Recover all three lists from a diff3. Order is [base, you, me]. *)

    type printer = { same : S.t Fmt.t; diff : Conflict.t Fmt.t }

    val git_printer : printer
    val pp : printer -> t Fmt.t
  end

  (** {2 Diffs} *)
  module Patch3 : sig
    type patch_conflict = { you : Patch.t; me : Patch.t }

    type hunk =
      | Keep of int
      (* | Me of patch *)
      (* | You of patch *)
      | Conflict of patch_conflict

    type t = hunk list
    (** A patch between three lists contains the minimal information to recover
        two lists from the base one. *)

    val get_patch : base:input -> me:input -> you:input -> t
    (** We can get a {!patch3} with the three files ... *)

    val diff_patch : Patch.t -> Patch.t -> t
    (** ... or with two patches *)

    val apply : input -> t -> Diff3.t
    (** Applying a [patch3] will give three files, which will be given as a
        value of type {!diff3}. *)
  end

  (** {2 Merges} *)

  module Merge : sig
    type hunk = Resolved of S.t | Unresolved of Conflict.t

    type t = hunk list
    (** Represent partially merges, possibly with conflicts *)

    type resolver = Conflict.t -> t

    val apply_resolver : resolver -> t -> t
    val compose_resolver : resolver -> resolver -> resolver
    val ( ++ ) : resolver -> resolver -> resolver
    val git_resolver : resolver
    val no_resolver : resolver

    val merge :
      ?resolver:resolver ->
      base:S.t list ->
      you:S.t list ->
      me:S.t list ->
      unit ->
      t
    (** Tries to merge two files given a base. The optional [resolve] argument
        can resolve some parts and let others unresolved. By default, it
        resolves the case where either {!diff3_diff.you} or {!diff3_diff.me} is
        empty (as git does). *)

    val resolve_merge : t -> (Conflict.t -> input) -> input
    (** [resolve_merge u f] calls [f] on each [`Conflict] to resolve them *)

    type printer = Diff3.printer = { same : S.t Fmt.t; diff : Conflict.t Fmt.t }

    val pp : printer -> t Fmt.t
  end
end

(** A module for diffing sequence of strings.

    For documentation on the API, see the {!LCS} module. *)
module DiffString : sig
  include module type of LCS (S_String)

  val git_merge : Merge.resolver
end
