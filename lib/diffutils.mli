(** A word on terminology.

    - A patch is the smallest information needed to go from one sequence to
      another. Its main use is to update the original file, while being as small
      as possible (see
      {{:https://www.chromium.org/developers/design-documents/software-updates-courgette/}
      courgette}).
    - On the contrary, a diff consists of the two files organized with common
      and different parts. Contrary to the patch, it is not minimal, in the
      sense that it contains the whole two files. Its main use is to display the
      differences to a human.
    - A merge is an attempt to merge two sequence, given an original sequence.
      It might contains unresolved conflicts.

    There are multiple kind of patches, depending on the operations allowed to
    go from one file to an other. The most famous are:

    - the Longest Common Subsequence (LCS), where deletion and addition are
      allowed,
    - the Lehvenstein distance, where deletion, addition and substitution are
      allowed (See the {{:https://v2.ocaml.org/api/compilerlibref/Diffing.html}
      OCaml module Diffing})
    - Block diff where a copy of a whole block from the input is allowed
    - ...

    In this library, we focus on the LCS diffs, patches and merges. So it won't
    to achieve what {{:http://www.daemonology.net/bsdiff/} bsdiff} and other
    binary patching tools do.

    This library allows you to:

    - Diff two lists of elements
    - Create a LCS patch from one list to another
    - Create a patch from one list to two others
    - Create a diff3 between three lists
    - Merge three lists into one
    - Resolve possible conflicts
    - Print and parse in various format the various values of this library *)

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
  (** A functor to create a diffing module specialized for a given type. *)

  type input = S.t list
  (** The input type for most functions: diffing, patching, merging, ... *)

  module Patch : sig
    (** A patch is a minimal information to get from a sequence of values of
        type {!S.t} to another. *)

    (** In LCS (Longest Common Subsequence), the only operations allowed are
        {!Keep} {!Remove} and {!Add}. Contrary to the usual [diff/patch] format,
        we omit information already present in the original sequence, so
        {!Remove} takes an integer. *)
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

  module Reversible_patch : sig
    (** A patch is a minimal information to get from a sequence of values of
        type {!S.t} to another, and vice versa. *)

    (** In LCS (Longest Common Subsequence), the only operations allowed are
        {!Keep} {!Remove} and {!Add}. Contrary to the usual [diff/patch] format,
        we omit information already present in the original sequence, so
        {!Remove} takes an integer. *)
    type hunk = Keep of int | Remove of S.t | Add of S.t

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
    val pp : printer -> t Fmt.t
  end

  (** A diff defines two sequence and how they relate to each other. *)
  module Diff : sig
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

  module Conflict : sig
    type t = { base : input; you : Patch.t; me : Patch.t }
    (** The reason [you] and [me] are [patch] and not [input] is to be able to
        quickly check if one is equal to [base]. [you] and [me] as {!input} can
        be recovered using {!Patch.apply} with [base]. *)
  end

  (** A diff3 defines 3 lists and how they relate to each other. *)
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

  (** [Patch3] allows to recover two lists from an original one. *)
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

  (** Merges of three lists *)
  module Merge : sig
    type hunk = Resolved of S.t | Unresolved of Conflict.t

    type t = hunk list
    (** Represent partially merges, possibly with conflicts *)

    type resolver = Conflict.t -> t
    type total_resolver = Conflict.t -> input

    val apply_resolver : resolver -> t -> t
    val apply_total_resolver : total_resolver -> t -> input
    val compose_resolver : resolver -> resolver -> resolver
    val compose_total_resolver : resolver -> total_resolver -> total_resolver
    val ( ++ ) : resolver -> resolver -> resolver
    val ( && ) : resolver -> total_resolver -> total_resolver
    val git_resolver : resolver
    val no_resolver : resolver

    val git_total_resolver :
      begin_:S.t list ->
      sep1:S.t list ->
      sep2:S.t list ->
      end_:S.t list ->
      total_resolver
    (** Basically replaces [{base ; me ; you}] with
        [ begin_ @ me @ sep1 @ base @ sep2 @ you @ end_] *)

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

    val total_merge : t -> total_resolver -> input
    (** [total_merge u f] calls [f] on each [`Conflict] to resolve them *)

    type printer = Diff3.printer = { same : S.t Fmt.t; diff : Conflict.t Fmt.t }

    val pp : printer -> t Fmt.t
  end
end

(** A module for diffing sequence of strings. *)
module DiffString : sig
  include module type of LCS (S_String)
end
