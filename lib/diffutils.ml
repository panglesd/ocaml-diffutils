module type S = sig
  type t

  val equal : t -> t -> bool
  val pp : t Fmt.t
end

module Line = struct
  type t = string

  let equal = String.equal
  let pp = Fmt.string
end

module LCS (S : S) = struct
  type input = S.t list
  type hunk = [ `Keep of int | `Remove of int | `Add of S.t ]
  type patch = hunk list
  type conflict2 = { orig : S.t list; new_ : S.t list }
  type diff = [ `Same of S.t | `Diff of conflict2 ] list

  let append_hunk i l =
    match (i, l) with
    | `Keep n, `Keep m :: q -> `Keep (n + m) :: q
    | `Remove n, `Remove m :: q -> `Remove (n + m) :: q
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

  open StdLabels

  let follow_diagonal { position = x, y; old; new_; instr_list } =
    let n, (old, new_) = common_prefix old new_ in
    let instr_list =
      if n = 0 then instr_list else append_hunk (`Keep n) instr_list
    in
    { position = (x + n, y + n); old; new_; instr_list }

  let is_a_win = function { old = []; new_ = []; _ } -> true | _ -> false

  let remove_old { position = x, y; old; new_; instr_list } =
    follow_diagonal
      {
        position = (x + 1, y);
        old;
        new_;
        instr_list = append_hunk (`Remove 1) instr_list;
      }

  let add_new { position = x, y; old; new_; instr_list } a =
    follow_diagonal
      {
        position = (x, y + 1);
        old;
        new_;
        instr_list = append_hunk (`Add a) instr_list;
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
    let p = follow_diagonal { position = (0, 0); old; new_; instr_list = [] } in
    if is_a_win p then raise (Found3 p);
    step [ p ]

  let get_patch ~orig ~new_ =
    try diff orig new_ with Found3 p -> List.rev p.instr_list

  let diff_of_patch ~orig patch =
    let rec app x l input =
      match (x, l, input) with
      | `Keep 0, _, _ | `Remove 0, _, _ -> (l, input)
      | `Keep n, _, a :: q -> app (`Keep (n - 1)) (`Same a :: l) q
      | `Remove n, `Diff { orig; new_ } :: l, a :: q ->
          app (`Remove (n - 1)) (`Diff { orig = a :: orig; new_ } :: l) q
      | `Remove n, _, a :: q ->
          app (`Remove (n - 1)) (`Diff { orig = [ a ]; new_ = [] } :: l) q
      | `Add a, `Diff { orig; new_ } :: l, q ->
          (`Diff { orig; new_ = a :: new_ } :: l, q)
      | `Add a, _, q -> (`Diff { orig = []; new_ = [ a ] } :: l, q)
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
        | `Same x -> `Same x :: acc
        | `Diff { orig; new_ } ->
            `Diff { orig = List.rev orig; new_ = List.rev new_ } :: acc)
      ~init:[] inverted_diff

  let diff ~orig ~new_ =
    let patch = get_patch ~orig ~new_ in
    diff_of_patch ~orig patch

  let hdn_rev l n =
    let rec aux l n acc1 =
      if n = 0 then (acc1, l)
      else
        match l with
        | [] -> failwith "Turn me into an error"
        | a :: q -> aux q (n - 1) (a :: acc1)
    in
    aux l n []

  let patch_length hunks =
    List.fold_left
      ~f:(fun acc hunk ->
        match hunk with `Add _ -> acc | `Remove n | `Keep n -> acc + n)
      ~init:0 hunks

  let patch_hunk_rev orig hunk =
    match hunk with
    | `Add n -> ([ n ], orig)
    | `Remove n ->
        let _, rest = hdn_rev orig n in
        ([], rest)
    | `Keep n ->
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

  let apply_patch orig patch = fst @@ patch_partial orig patch

  type patch_printer = {
    keep : S.t Fmt.t;
    add : S.t Fmt.t;
    remove : S.t Fmt.t;
    sep : unit Fmt.t;
    context : int;
  }

  let patch_printer ~keep ~add ~remove ~sep ~context =
    { keep; add; remove; sep; context }

  type diff_printer = { same : S.t Fmt.t; diff : conflict2 Fmt.t }

  let diff_printer ~same ~diff = { same; diff }

  let git_patch_printer =
    {
      keep = (fun ppf -> Fmt.pf ppf " %a\n" S.pp);
      add = (fun ppf -> Fmt.pf ppf "+%a\n" S.pp);
      remove = (fun ppf -> Fmt.pf ppf "-%a\n" S.pp);
      sep = Fmt.nop;
      context = 3;
    }

  let _f a = ignore a.sep

  let git_diff_printer =
    {
      same = git_patch_printer.keep;
      diff =
        (fun ppf { orig; new_ } ->
          List.iter ~f:(git_patch_printer.remove ppf) orig;
          List.iter ~f:(git_patch_printer.add ppf) new_);
    }

  let html_diff_printer =
    let elem_class class_ pp ppf a =
      Fmt.pf ppf {|@[<hv><div class="%s">@;<0 2>@[<hv>%a@]@,</div>@]|} class_ pp
        a
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

  let pp_diff diff_printer =
    let pp_dh ppf dh =
      match dh with
      | `Same e -> diff_printer.same ppf e
      | `Diff c -> diff_printer.diff ppf c
    in
    Fmt.list ~sep:Fmt.nop pp_dh

  let pp_patch _ =
    (* TODO *)
    let _ =
     fun printer orig patch ->
      let rec aux ?(first = false) orig patch =
        match patch with
        | [] -> ()
        | `Add a :: q ->
            Fmt.pr "%a" printer.add a;
            aux orig q
        | `Remove n :: q ->
            let hdn, rest = hdn_rev orig n in
            List.iter ~f:(fun a -> Fmt.pr "%a" printer.remove a) (List.rev hdn);
            aux rest q
        | `Keep n :: q -> (
            let n, orig =
              if first then (n, orig)
              else
                let taken = Int.min printer.context n in
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
                let taken = Int.min printer.context n in
                let ctx_end, _ = hdn_rev rev1 taken in
                List.iter ~f:(fun a -> Fmt.pr "%a" printer.keep a) ctx_end;
                aux orig q)
      in
      aux ~first:true orig patch
    in
    failwith "TODO"

  (** {1 Diff between three lists} *)

  type patch_conflict = { you : hunk list; me : hunk list }

  type hunk3 =
    [ `Keep of int | `Me of patch | `You of patch | `Conflict of patch_conflict ]

  type patch3 = hunk3 list

  let diff_patch a b =
    let rec find_next_ml a b i j acc_me acc_you =
      match (a, b) with
      | `Keep _ :: _, `Keep _ :: _ when i = j ->
          (a, b, i, List.rev acc_me, List.rev acc_you)
      | (`Add _ as p) :: q1, _ when i <= j ->
          find_next_ml q1 b i j (p :: acc_me) acc_you
      | (`Remove n as p) :: q1, _ when i <= j ->
          find_next_ml q1 b (i + n) j (p :: acc_me) acc_you
      | (`Keep n as p) :: q1, _ when i < j && n <= j - i ->
          find_next_ml q1 b (i + n) j (p :: acc_me) acc_you
      | (`Keep n as p) :: q1, _ when i < j ->
          find_next_ml (`Keep (n - (j - i)) :: q1) b j j (p :: acc_me) acc_you
      | _, (`Remove n as p) :: q2 ->
          find_next_ml a q2 i (j + n) acc_me (p :: acc_you)
      | _, (`Add _ as p) :: q2 -> find_next_ml a q2 i j acc_me (p :: acc_you)
      | _, (`Keep n as p) :: q2 when n <= j - i ->
          find_next_ml a q2 i (j + n) acc_me (p :: acc_you)
      | _, (`Keep n as p) :: q2 ->
          find_next_ml a (`Keep (n - (i - j)) :: q2) i i acc_me (p :: acc_you)
      | [], [] -> (a, b, i, List.rev acc_me, List.rev acc_you)
      | _ -> Fmt.failwith "impossible in diff_patch %d %d" i j
    in
    let rec find_last_consecutive_ml a b i =
      match (a, b) with
      | `Keep m :: q1, `Keep n :: q2 ->
          if m < n then find_last_consecutive_ml q1 (`Keep (n - m) :: q2) (i + m)
          else if n < m then
            find_last_consecutive_ml (`Keep (m - n) :: q1) q2 (i + m)
          else find_last_consecutive_ml q1 q2 (i + m)
      | _ -> (a, b, i)
    in
    let rec aux a b i =
      match (a, b) with
      | [], [] -> []
      | _ ->
          (* Format.printf "a b have size %d %d \n %!" (List.length a) *)
          (* (List.length b); *)
          (* Fmt.pr "a is: %a\n %!" (LCS.show Elem.pp_a) a; *)
          (* Fmt.pr "b is: %a\n %!" (LCS.show Elem.pp_a) b; *)
          let a, b, i, me, you = find_next_ml a b i i [] [] in
          let modif =
            let is_keep = function `Keep _ -> true | _ -> false in
            match (List.for_all ~f:is_keep me, List.for_all ~f:is_keep you) with
            | true, true -> []
            | _, true -> [ `Me me ]
            | true, _ -> [ `You you ]
            | _ -> [ `Conflict { me; you } ]
          in
          let a, b, i0 = find_last_consecutive_ml a b i in
          let keep = if i = i0 then [] else [ `Keep (i0 - i) ] in
          modif @ keep @ aux a b i0
    in
    aux a b 0

  type unresolved_merge =
    [ `Ok of S.t | `Conflict of input * input * input ] list

  let apply_patch3 orig p3 =
    let rec aux orig p3 acc =
      match p3 with
      | `Keep n :: p3 ->
          let rev, q = hdn_rev orig n in
          aux q p3 (List.map ~f:(fun x -> `Ok x) rev @ acc)
      | `Me hunks :: p3 ->
          let addition, orig = patch_partial orig hunks in
          aux orig p3 (List.map ~f:(fun x -> `Ok x) addition @ acc)
      | `You hunks :: p3 ->
          let addition, orig = patch_partial orig hunks in
          aux orig p3 (List.map ~f:(fun x -> `Ok x) addition @ acc)
      | `Conflict { me; you } :: p3 ->
          let me, orig = patch_partial orig me
          and you, _ = patch_partial orig you
          and kept, _ = patch_partial orig [ `Keep (patch_length me) ] in
          aux orig p3 (`Conflict (me, kept, you) :: acc)
      | [] -> List.rev acc
    in
    aux orig p3 []

  let patch3 ~base ~me ~you =
    let p1 = get_patch ~orig:base ~new_:me
    and p2 = get_patch ~orig:base ~new_:you in
    diff_patch p1 p2

  let diff3 ~base ~me ~you =
    apply_patch3 base @@ patch3 ~base ~me ~you

  let resolve_merge _unresolved_merge = failwith "implement me"

  type unresolved_merge_printer = {
    same : S.t Fmt.t;
    conflict : (S.t list * S.t list * S.t list) Fmt.t;
  }

  let git_merge_printer =
    let pp fmt = Fmt.pf fmt "%a\n" S.pp in
    {
      same = pp;
      conflict =
        (fun ppf (a, b, c) ->
          let pp_l = Fmt.list ~sep:(Fmt.const Fmt.char '\n') S.pp in
          Fmt.pf ppf {|>>>
%a
|||
%a
===
%a
<<<
|} pp_l a pp_l b pp_l c);
    }

  let pp_unresolved_merge printer =
    let pp_item ppf = function
      | `Ok a -> printer.same ppf a
      | `Conflict (me, kept, you) -> printer.conflict ppf (me, kept, you)
    in
    Fmt.list ~sep:Fmt.nop pp_item

  let print_unresolved_merge printer merged =
    List.iter
      ~f:(fun line ->
        match line with
        | `Ok a -> Fmt.pr "%a" printer.same a
        | `Conflict (me, kept, you) ->
            Fmt.pr "%a" printer.conflict (me, kept, you))
      merged
end
