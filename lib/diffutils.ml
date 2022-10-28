module type S = sig
  type t

  val equal : t -> t -> bool
  val pp : t Fmt.t
end

module S_String = struct
  type t = string

  let equal = String.equal
  let pp = Fmt.string
end

module LCS (S : S) = struct
  type input = S.t list

  open StdLabels

  let hdn_rev l n =
    let rec aux l n acc1 =
      if n = 0 then (acc1, l)
      else
        match l with
        | [] -> failwith "Turn me into an error"
        | a :: q -> aux q (n - 1) (a :: acc1)
    in
    aux l n []

  module Patch = struct
    type hunk = Keep of int | Remove of int | Add of S.t
    type t = hunk list

    let append_hunk i l =
      match (i, l) with
      | Keep n, Keep m :: q -> Keep (n + m) :: q
      | Remove n, Remove m :: q -> Remove (n + m) :: q
      | _ -> i :: l

    type point = {
      position : int * int;
      old : S.t list;
      new_ : S.t list;
      instr_list : hunk list;
    }

    let common_prefix a b =
      let rec size_common_prefix n a b =
        match (a, b) with
        | ta :: qa, tb :: qb when S.equal ta tb ->
            size_common_prefix (n + 1) qa qb
        | _ -> (n, (a, b))
      in
      size_common_prefix 0 a b

    let follow_diagonal { position = x, y; old; new_; instr_list } =
      let n, (old, new_) = common_prefix old new_ in
      let instr_list =
        if n = 0 then instr_list else append_hunk (Keep n) instr_list
      in
      { position = (x + n, y + n); old; new_; instr_list }

    let is_a_win = function { old = []; new_ = []; _ } -> true | _ -> false

    let remove_old { position = x, y; old; new_; instr_list } =
      follow_diagonal
        {
          position = (x + 1, y);
          old;
          new_;
          instr_list = append_hunk (Remove 1) instr_list;
        }

    let add_new { position = x, y; old; new_; instr_list } a =
      follow_diagonal
        {
          position = (x, y + 1);
          old;
          new_;
          instr_list = append_hunk (Add a) instr_list;
        }

    exception Found3 of point

    let diff old new_ =
      let rec step (state : point list) =
        let rec next state =
          match state with
          | [] -> []
          | [ ({ old = _ :: old; _ } as p) ] ->
              let p = remove_old { p with old } in
              if is_a_win p then raise (Found3 p);
              [ p ]
          | { old = []; _ } :: (({ new_ = a :: new_; _ } as p) :: _ as q) ->
              let p = add_new { p with new_ } a in
              if is_a_win p then raise (Found3 p);
              p :: next q
          | ({ old = _ :: old; _ } as p) :: ({ new_ = []; _ } :: _ as q) ->
              let p = remove_old { p with old } in
              if is_a_win p then raise (Found3 p);
              p :: next q
          | ({ position = x1, _; old = _ :: old; _ } as p1)
            :: (({ position = x2, _; new_ = a :: new_; _ } as p2) :: _ as q) ->
              let p =
                if x1 >= x2 then remove_old { p1 with old }
                else add_new { p2 with new_ } a
              in
              if is_a_win p then raise (Found3 p);
              p :: next q
          | { old = []; _ } :: { new_ = []; _ } :: _ -> failwith "impossible"
          | [ { old = []; _ } ] -> []
        in
        let state =
          match state with
          | [] -> []
          | { new_ = []; _ } :: _ -> next state
          | ({ new_ = a :: new_; _ } as p) :: _ ->
              let p = add_new { p with new_ } a in
              if is_a_win p then raise (Found3 p);
              p :: next state
        in
        step state
      in
      let p =
        follow_diagonal { position = (0, 0); old; new_; instr_list = [] }
      in
      if is_a_win p then raise (Found3 p);
      step [ p ]

    let get_patch ~orig ~new_ =
      try diff orig new_ with Found3 p -> List.rev p.instr_list

    let patch_length hunks =
      List.fold_left
        ~f:(fun acc hunk ->
          match hunk with Add _ -> acc | Remove n | Keep n -> acc + n)
        ~init:0 hunks

    let patch_hunk_rev orig hunk =
      (* Format.printf "Calling phr with orig = %a and hunk = %a\n%!" (Fmt.list S.pp) *)
      (*   orig pp_hunk hunk; *)
      match hunk with
      | Add n -> ([ n ], orig)
      | Remove n ->
          let _, rest = hdn_rev orig n in
          ([], rest)
      | Keep n ->
          let kept, rest = hdn_rev orig n in
          (kept, rest)

    let patch_partial orig patch =
      let rec aux orig patch acc =
        match patch with
        | [] -> (List.rev acc, orig)
        | hunk :: q ->
            let addition, rest = patch_hunk_rev orig hunk in
            aux rest q (addition @ acc)
      in
      aux orig patch []

    let apply orig patch = fst @@ patch_partial orig patch

    type printer = {
      keep : S.t Fmt.t;
      add : S.t Fmt.t;
      remove : S.t Fmt.t;
      sep : unit Fmt.t;
      context : int;
    }

    let git_printer =
      {
        keep = (fun ppf -> Fmt.pf ppf " %a\n" S.pp);
        add = (fun ppf -> Fmt.pf ppf "+%a\n" S.pp);
        remove = (fun ppf -> Fmt.pf ppf "-%a\n" S.pp);
        sep = Fmt.nop;
        context = 3;
      }

    let printer ~keep ~add ~remove ~sep ~context =
      { keep; add; remove; sep; context }

    let _f a = ignore a.sep

    let pp _ =
      (* TODO *)
      let int_min a b = if a < b then a else b in
      let _ =
       fun printer orig patch ->
        let rec aux ?(first = false) orig patch =
          match patch with
          | [] -> ()
          | Add a :: q ->
              Fmt.pr "%a" printer.add a;
              aux orig q
          | Remove n :: q ->
              let hdn, rest = hdn_rev orig n in
              List.iter
                ~f:(fun a -> Fmt.pr "%a" printer.remove a)
                (List.rev hdn);
              aux rest q
          | Keep n :: q -> (
              let n, orig =
                if first then (n, orig)
                else
                  let taken = int_min printer.context n in
                  let ctx_begin, orig = hdn_rev orig taken in
                  List.iter
                    ~f:(fun a -> Fmt.pr "%a" printer.keep a)
                    (List.rev ctx_begin);
                  (n - taken, orig)
              in
              match q with
              | [] -> ()
              | _ ->
                  let rev1, orig = hdn_rev orig n in
                  let taken = int_min printer.context n in
                  let ctx_end, _ = hdn_rev rev1 taken in
                  List.iter ~f:(fun a -> Fmt.pr "%a" printer.keep a) ctx_end;
                  aux orig q)
        in
        aux ~first:true orig patch
      in
      failwith "TODO"
  end

  module Reversible_patch = struct
    type hunk = Keep of int | Remove of S.t | Add of S.t
    type t = hunk list

    let get_patch ~orig:_ ~new_:_ = failwith "Implement me"
    let apply _input _t = failwith "implement me"

    type printer = {
      keep : S.t Fmt.t;
      add : S.t Fmt.t;
      remove : S.t Fmt.t;
      sep : unit Fmt.t;
      context : int;
    }

    let printer ~keep ~add ~remove ~sep ~context =
      { keep; add; remove; sep; context }

    let git_printer =
      {
        keep = (fun _ -> failwith "implement me");
        add = (fun _ -> failwith "implement me");
        remove = (fun _ -> failwith "implement me");
        sep = (fun _ -> failwith "implement me");
        context = 1;
      }

    let pp printer =
      ignore
        (printer.keep, printer.add, printer.remove, printer.sep, printer.context);
      failwith "implement me"
  end

  module Diff = struct
    type conflict2 = { orig : S.t list; new_ : S.t list }
    type hunk = Same of S.t | Diff of conflict2
    type t = hunk list

    let to_inputs (diff : t) =
      diff
      |> List.map ~f:(function
           | Same v -> ([ v ], [ v ])
           | Diff { orig; new_ } -> (orig, new_))
      |> List.split
      |> fun (l_orig, l_new) -> (List.concat l_orig, List.concat l_new)

    let diff_of_patch ~orig patch =
      let rec app x l input =
        match (x, l, input) with
        | Patch.Keep 0, _, _ | Remove 0, _, _ -> (l, input)
        | Keep n, _, a :: q -> app (Keep (n - 1)) (Same a :: l) q
        | Remove n, Diff { orig; new_ } :: l, a :: q ->
            app (Remove (n - 1)) (Diff { orig = a :: orig; new_ } :: l) q
        | Remove n, _, a :: q ->
            app (Remove (n - 1)) (Diff { orig = [ a ]; new_ = [] } :: l) q
        | Add a, Diff { orig; new_ } :: l, q ->
            (Diff { orig; new_ = a :: new_ } :: l, q)
        | Add a, _, q -> (Diff { orig = []; new_ = [ a ] } :: l, q)
        | _ -> failwith "patch is not compatible with original list"
      in
      let inverted_diff, _input =
        List.fold_left
          ~f:(fun (l, input) x -> app x l input)
          ~init:([], orig) patch
      in
      List.fold_left
        ~f:(fun acc x ->
          match x with
          | Same x -> Same x :: acc
          | Diff { orig; new_ } ->
              Diff { orig = List.rev orig; new_ = List.rev new_ } :: acc)
        ~init:[] inverted_diff

    let diff ~orig ~new_ =
      let patch = Patch.get_patch ~orig ~new_ in
      diff_of_patch ~orig patch

    type printer = { same : S.t Fmt.t; diff : conflict2 Fmt.t }

    let printer ~same ~diff = { same; diff }

    let git_printer =
      {
        same = Patch.git_printer.keep;
        diff =
          (fun ppf { orig; new_ } ->
            List.iter ~f:(Patch.git_printer.remove ppf) orig;
            List.iter ~f:(Patch.git_printer.add ppf) new_);
      }

    let html_printer =
      let elem_class class_ pp ppf a =
        Fmt.pf ppf {|@[<hv><div class="%s">@;<0 2>@[<hv>%a@]@,</div>@]|} class_
          pp a
      in
      {
        same =
          (fun ppf a ->
            let pp_common = elem_class "common-line" S.pp in
            elem_class "common"
              (fun ppf a -> Fmt.pf ppf "%a@,%a@," pp_common a pp_common a)
              ppf a;
            Fmt.cut ppf ());
        diff =
          (let pp_removed =
             elem_class "removed "
               (Fmt.list ~sep:Fmt.cut (elem_class "removed-line" S.pp))
           and pp_added =
             elem_class "added"
               (Fmt.list ~sep:Fmt.cut (elem_class "added-line" S.pp))
           in
           elem_class "conflict" (fun ppf { orig; new_ } ->
               pp_removed ppf orig;
               Fmt.cut ppf ();
               pp_added ppf new_));
      }

    let pp diff_printer =
      let pp_dh ppf dh =
        match dh with
        | Same e -> diff_printer.same ppf e
        | Diff c -> diff_printer.diff ppf c
      in
      Fmt.list ~sep:Fmt.nop pp_dh
  end

  (** {1 Diff between three lists} *)
  module Patch3_ = struct
    type patch_conflict = { you : Patch.t; me : Patch.t }

    type hunk =
      | Keep of int
      (* | Me of patch *)
      (* | You of patch *)
      | Conflict of patch_conflict

    type t = hunk list

    let diff_patch a b : t =
      let rec find_next_ml (a : Patch.t) (b : Patch.t) i j acc_me acc_you =
        match (a, b) with
        | Keep _ :: _, Keep _ :: _ when i = j ->
            (* We found a point where the same line is kept *)
            (a, b, i, List.rev acc_me, List.rev acc_you)
        | (Add _ as p) :: q1, _ when i <= j ->
            find_next_ml q1 b i j (p :: acc_me) acc_you
        | (Remove n as p) :: q1, _ when i <= j ->
            find_next_ml q1 b (i + n) j (p :: acc_me) acc_you
        | (Keep n as p) :: q1, _ when i < j && i + n <= j ->
            find_next_ml q1 b (i + n) j (p :: acc_me) acc_you
        | Keep n :: q1, _ when i < j ->
            (* Here i + n > j *)
            find_next_ml
              (Keep (n - (j - i)) :: q1)
              b j j
              (Keep (j - i) :: acc_me)
              acc_you
        | _, (Remove n as p) :: q2 ->
            find_next_ml a q2 i (j + n) acc_me (p :: acc_you)
        | _, (Add _ as p) :: q2 -> find_next_ml a q2 i j acc_me (p :: acc_you)
        | _, (Keep n as p) :: q2 when n <= j - i ->
            find_next_ml a q2 i (j + n) acc_me (p :: acc_you)
        | _, Keep n :: q2 ->
            find_next_ml a
              (Keep (n - (i - j)) :: q2)
              i i acc_me
              (Keep (i - j) :: acc_you)
        | [], [] -> (a, b, i, List.rev acc_me, List.rev acc_you)
        | _ -> Fmt.failwith "impossible in diff_patch %d %d" i j
      in
      let rec find_last_consecutive_ml a b i =
        match (a, b) with
        | Patch.Keep m :: q1, Patch.Keep n :: q2 ->
            if m < n then
              find_last_consecutive_ml q1 (Keep (n - m) :: q2) (i + m)
            else if n < m then
              find_last_consecutive_ml (Keep (m - n) :: q1) q2 (i + n)
            else find_last_consecutive_ml q1 q2 (i + m)
        | _ -> (a, b, i)
      in
      let rec aux (a : Patch.t) b i : t =
        match (a, b) with
        | [], [] -> []
        | _ ->
            (* Format.printf "a b have size %d %d \n %!" (List.length a) *)
            (* (List.length b); *)
            (* Fmt.pr "a is: %a\n %!" (LCS.show Elem.pp_a) a; *)
            (* Fmt.pr "b is: %a\n %!" (LCS.show Elem.pp_a) b; *)
            let a, b, i, me, you = find_next_ml a b i i [] [] in
            let modif =
              let is_keep = function Patch.Keep _ -> true | _ -> false in
              match
                (List.for_all ~f:is_keep me, List.for_all ~f:is_keep you)
              with
              | true, true -> []
              (* | _, true -> [ Me me ] *)
              (* | true, _ -> [ You you ] *)
              | _ -> [ Conflict { me; you } ]
            in
            let a, b, i0 = find_last_consecutive_ml a b i in
            let keep = if i = i0 then [] else [ Keep (i0 - i) ] in
            modif @ keep @ aux a b i0
      in
      aux a b 0

    let get_patch ~base ~me ~you =
      let p1 = Patch.get_patch ~orig:base ~new_:me
      and p2 = Patch.get_patch ~orig:base ~new_:you in
      diff_patch p1 p2
  end

  module Conflict = struct
    type t = { base : input; you : Patch.t; me : Patch.t }
  end

  module Diff3 = struct
    type hunk = Same of S.t | Diff of Conflict.t
    type t = hunk list

    let apply_patch3 orig p3 =
      let rec aux orig p3 acc =
        match p3 with
        | Patch3_.Keep n :: p3 ->
            let rev, q = hdn_rev orig n in
            aux q p3 (List.map ~f:(fun x -> Same x) rev @ acc)
        (* | Me hunks :: p3 -> *)
        (*     let addition, orig = patch_partial orig hunks in *)
        (*     aux orig p3 (List.map ~f:(fun x -> Same3 x) addition @ acc) *)
        (* | You hunks :: p3 -> *)
        (*     let addition, orig = patch_partial orig hunks in *)
        (*     aux orig p3 (List.map ~f:(fun x -> Same3 x) addition @ acc) *)
        | Conflict { me; you } :: p3 ->
            let base, orig =
              Patch.patch_partial orig [ Keep (Patch.patch_length me) ]
            in
            aux orig p3 (Diff { me; base; you } :: acc)
        | [] -> List.rev acc
      in
      aux orig p3 []

    let diff3 ~base ~me ~you =
      apply_patch3 base @@ Patch3_.get_patch ~base ~me ~you

    let to_inputs (diff3 : t) =
      let rec split3 acc1 acc2 acc3 l =
        match l with
        | [] -> (List.rev acc1, List.rev acc2, List.rev acc3)
        | (a, b, c) :: q -> split3 (a :: acc1) (b :: acc2) (c :: acc3) q
      in
      diff3
      |> List.map ~f:(function
           | Same v -> ([ v ], [ v ], [ v ])
           | Diff { base; you; me } ->
               let you = Patch.apply base you and me = Patch.apply base me in
               (base, you, me))
      |> split3 [] [] []
      |> fun (base, you, me) ->
      (List.concat base, List.concat you, List.concat me)

    type printer = { same : S.t Fmt.t; diff : Conflict.t Fmt.t }

    let pp printer =
      let pp_item ppf = function
        | Same a -> printer.same ppf a
        | Diff conflict -> printer.diff ppf conflict
      in
      Fmt.list ~sep:Fmt.nop pp_item

    let git_printer =
      let pp fmt = Fmt.pf fmt "%a\n" S.pp in
      {
        same = pp;
        diff =
          (fun ppf { me; base; you } ->
            let pp_l = Fmt.(list (S.pp ++ const Fmt.char '\n')) in
            let you = Patch.apply base you and me = Patch.apply base me in
            Fmt.pf ppf {|>>>
%a|||
%a===
%a<<<
|} pp_l me pp_l base pp_l you);
      }
  end

  module Patch3 = struct
    include Patch3_

    let apply = Diff3.apply_patch3
  end

  module Merge = struct
    type hunk = Resolved of S.t | Unresolved of Conflict.t
    type t = hunk list
    type resolver = Conflict.t -> t
    type total_resolver = Conflict.t -> input

    let git_resolver conflict =
      let is_keep = function Patch.Keep _ -> true | _ -> false in
      match conflict with
      | { Conflict.base; you; me } when List.for_all ~f:is_keep you ->
          List.map ~f:(fun x -> Resolved x) (Patch.apply base me)
      | { base; you; me } when List.for_all ~f:is_keep me ->
          List.map ~f:(fun x -> Resolved x) (Patch.apply base you)
      | d -> [ Unresolved d ]

    let no_resolver conflict = [ Unresolved conflict ]

    let apply_resolver solver l =
      l
      |> List.map ~f:(function Unresolved c -> solver c | x -> [ x ])
      |> List.concat

    let apply_total_resolver solver l =
      l
      |> List.map ~f:(function Unresolved c -> solver c | Resolved x -> [ x ])
      |> List.concat

    let compose_resolver solver1 solver2 conflict =
      conflict |> solver1 |> apply_resolver solver2

    let compose_total_resolver solver1 solver2 conflict =
      conflict |> solver1 |> apply_total_resolver solver2

    let ( ++ ) = compose_resolver
    let ( && ) = compose_total_resolver

    let merge ?resolver ~base ~you ~me () =
      let resolver = Option.value resolver ~default:git_resolver in
      Diff3.diff3 ~base ~you ~me
      |> List.map ~f:(function
           | Diff3.Same v -> [ Resolved v ]
           | Diff d -> resolver d)
      |> List.concat

    let total_merge merge resolve =
      merge
      |> List.map ~f:(function
           | Resolved s -> [ s ]
           | Unresolved u -> resolve u)
      |> List.concat

    let git_total_resolver ~begin_ ~sep1 ~sep2 ~end_ { Conflict.base; you; me }
        =
      let me = Patch.apply base me and you = Patch.apply base you in
      begin_ @ me @ sep1 @ base @ sep2 @ you @ end_

    type printer = Diff3.printer = { same : S.t Fmt.t; diff : Conflict.t Fmt.t }

    let pp printer =
      let pp_item ppf = function
        | Resolved a -> printer.same ppf a
        | Unresolved conflict -> printer.diff ppf conflict
      in
      Fmt.list ~sep:Fmt.nop pp_item
  end
end

module DiffString = struct
  include LCS (S_String)
end
