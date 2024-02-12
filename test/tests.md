
```ocaml
open Diffutils

let printer = Diff.git_printer
let html_printer = Diff.html_printer
```

```ocaml
# let orig = List.init 16 string_of_int ;;
val orig : string list =
  ["0"; "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8"; "9"; "10"; "11"; "12"; "13";
   "14"; "15"]

# let new_ = ["0" ;"1" ;"2" ;"3" ;"bli" ;"bla" ;"7" ;"8" ;"9" ;"10" ;"11" ;"bb" ;"14" ;"15" ;"16"];;
val new_ : string list =
  ["0"; "1"; "2"; "3"; "bli"; "bla"; "7"; "8"; "9"; "10"; "11"; "bb"; "14";
   "15"; "16"]

# let p = Patch.get_patch ~orig ~new_ ;;
val p : Patch.t =
  [Diffutils.Patch.Keep 4; Diffutils.Patch.Remove 3;
   Diffutils.Patch.Add "bli"; Diffutils.Patch.Add "bla";
   Diffutils.Patch.Keep 5; Diffutils.Patch.Remove 2;
   Diffutils.Patch.Add "bb"; Diffutils.Patch.Keep 2;
   Diffutils.Patch.Add "16"]
# let p = Diff.diff ~orig ~new_ ;;
val p : Diff.t =
  [Diffutils.Diff.Same "0"; Diffutils.Diff.Same "1"; Diffutils.Diff.Same "2";
   Diffutils.Diff.Same "3";
   Diffutils.Diff.Diff
    {Diffutils.Diff.orig = ["4"; "5"; "6"]; new_ = ["bli"; "bla"]};
   Diffutils.Diff.Same "7"; Diffutils.Diff.Same "8"; Diffutils.Diff.Same "9";
   Diffutils.Diff.Same "10"; Diffutils.Diff.Same "11";
   Diffutils.Diff.Diff {Diffutils.Diff.orig = ["12"; "13"]; new_ = ["bb"]};
   Diffutils.Diff.Same "14"; Diffutils.Diff.Same "15";
   Diffutils.Diff.Diff {Diffutils.Diff.orig = []; new_ = ["16"]}]

# let _ = Fmt.pr "%a" (Diff.pp printer) p; Format.printf "%!" ;;
 0
 1
 2
 3
-4
-5
-6
+bli
+bla
 7
 8
 9
 10
 11
-12
-13
+bb
 14
 15
+16
- : unit = ()
# let _ = Fmt.pr "%a%!" (Diff.pp html_printer) p ;;
<div class="common">
  <div class="common-line">0</div><div class="common-line">0</div>
</div>
<div class="common">
  <div class="common-line">1</div><div class="common-line">1</div>
</div>
<div class="common">
  <div class="common-line">2</div><div class="common-line">2</div>
</div>
<div class="common">
  <div class="common-line">3</div><div class="common-line">3</div>
</div>
<div class="conflict">
  <div class="removed ">
    <div class="removed-line">4</div>
    <div class="removed-line">5</div>
    <div class="removed-line">6</div>
  </div>
  <div class="added">
    <div class="added-line">bli</div><div class="added-line">bla</div>
  </div>
</div><div class="common">
        <div class="common-line">7</div><div class="common-line">7</div>
      </div>
<div class="common">
  <div class="common-line">8</div><div class="common-line">8</div>
</div>
<div class="common">
  <div class="common-line">9</div><div class="common-line">9</div>
</div>
<div class="common">
  <div class="common-line">10</div><div class="common-line">10</div>
</div>
<div class="common">
  <div class="common-line">11</div><div class="common-line">11</div>
</div>
<div class="conflict">
  <div class="removed ">
    <div class="removed-line">12</div><div class="removed-line">13</div>
  </div>
  <div class="added"><div class="added-line">bb</div></div>
</div><div class="common">
        <div class="common-line">14</div><div class="common-line">14</div>
      </div>
<div class="common">
  <div class="common-line">15</div><div class="common-line">15</div>
</div>
<div class="conflict">
  <div class="removed "></div>
  <div class="added"><div class="added-line">16</div></div>
</div>
- : unit = ()
```

# Testing 3 way merges

We first define our original file a and the two different modifications b
and c.

```ocaml
# let base = "1 2 3 4 5 6 7" |> String.split_on_char ' '
  and me = "1 2 3 5 10 7" |> String.split_on_char ' '
  and you = "1 2 3 4 5 11 7 8" |> String.split_on_char ' ';;
val base : string list = ["1"; "2"; "3"; "4"; "5"; "6"; "7"]
val me : string list = ["1"; "2"; "3"; "5"; "10"; "7"]
val you : string list = ["1"; "2"; "3"; "4"; "5"; "11"; "7"; "8"]
```

Now we do the diff3 of those sequences:

```ocaml
# let p1 = Diff.diff ~orig:base ~new_:me and p2 = Diff.diff ~orig:base ~new_:you;;
val p1 : Diff.t =
  [Diffutils.Diff.Same "1"; Diffutils.Diff.Same "2"; Diffutils.Diff.Same "3";
   Diffutils.Diff.Diff {Diffutils.Diff.orig = ["4"]; new_ = []};
   Diffutils.Diff.Same "5";
   Diffutils.Diff.Diff {Diffutils.Diff.orig = ["6"]; new_ = ["10"]};
   Diffutils.Diff.Same "7"]
val p2 : Diff.t =
  [Diffutils.Diff.Same "1"; Diffutils.Diff.Same "2"; Diffutils.Diff.Same "3";
   Diffutils.Diff.Same "4"; Diffutils.Diff.Same "5";
   Diffutils.Diff.Diff {Diffutils.Diff.orig = ["6"]; new_ = ["11"]};
   Diffutils.Diff.Same "7";
   Diffutils.Diff.Diff {Diffutils.Diff.orig = []; new_ = ["8"]}]
# let diff_abc = Diff3.diff3 ~base ~me ~you ;;
val diff_abc : Diff3.t =
  [Diffutils.Diff3.Same "1"; Diffutils.Diff3.Same "2";
   Diffutils.Diff3.Same "3";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = ["4"]; you = [Diffutils.Patch.Keep 1];
     me = [Diffutils.Patch.Remove 1]};
   Diffutils.Diff3.Same "5";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = ["6"];
     you = [Diffutils.Patch.Remove 1; Diffutils.Patch.Add "11"];
     me = [Diffutils.Patch.Remove 1; Diffutils.Patch.Add "10"]};
   Diffutils.Diff3.Same "7";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = []; you = [Diffutils.Patch.Add "8"]; me = []}]
```

Let's print it!

```ocaml
# let m = Patch3.get_patch ~base ~me ~you ;;
val m : Patch3.t =
  [Diffutils.Patch3.Keep 3;
   Diffutils.Patch3.Conflict
    {Diffutils.Patch3.you = [Diffutils.Patch.Keep 1];
     me = [Diffutils.Patch.Remove 1]};
   Diffutils.Patch3.Keep 1;
   Diffutils.Patch3.Conflict
    {Diffutils.Patch3.you =
      [Diffutils.Patch.Remove 1; Diffutils.Patch.Add "11"];
     me = [Diffutils.Patch.Remove 1; Diffutils.Patch.Add "10"]};
   Diffutils.Patch3.Keep 1;
   Diffutils.Patch3.Conflict
    {Diffutils.Patch3.you = [Diffutils.Patch.Add "8"]; me = []}]
# let m = Diff3.diff3 ~base ~me ~you ;;
val m : Diff3.t =
  [Diffutils.Diff3.Same "1"; Diffutils.Diff3.Same "2";
   Diffutils.Diff3.Same "3";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = ["4"]; you = [Diffutils.Patch.Keep 1];
     me = [Diffutils.Patch.Remove 1]};
   Diffutils.Diff3.Same "5";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = ["6"];
     you = [Diffutils.Patch.Remove 1; Diffutils.Patch.Add "11"];
     me = [Diffutils.Patch.Remove 1; Diffutils.Patch.Add "10"]};
   Diffutils.Diff3.Same "7";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = []; you = [Diffutils.Patch.Add "8"]; me = []}]
# let printer = Diff3.git_printer ;;
val printer : Merge.printer = {Diffutils.Diff3.same = <fun>; diff = <fun>}

# let _ = Fmt.pr "%a%!" (Diff3.pp printer) m;;
1
2
3
>>>
|||
4
===
4
<<<
5
>>>
10
|||
6
===
11
<<<
7
>>>
|||
===
8
<<<
- : unit = ()
# let _ = Fmt.pr "%a%!" (Merge.pp printer) (Merge.merge ~base ~you ~me ());;
1
2
3
5
>>>
10
|||
6
===
11
<<<
7
8
- : unit = ()
```


```ocaml
# let base = ["a" ; "b" ; "c"] and me = ["a" ; "y" ; "b" ; "c"] and you = ["a" ; "b" ; "z" ; "c" ] ;;
val base : string list = ["a"; "b"; "c"]
val me : string list = ["a"; "y"; "b"; "c"]
val you : string list = ["a"; "b"; "z"; "c"]
# let m = Patch3.get_patch ~base ~you ~me ;;
val m : Patch3.t =
  [Diffutils.Patch3.Keep 1;
   Diffutils.Patch3.Conflict
    {Diffutils.Patch3.you = []; me = [Diffutils.Patch.Add "y"]};
   Diffutils.Patch3.Keep 1;
   Diffutils.Patch3.Conflict
    {Diffutils.Patch3.you = [Diffutils.Patch.Add "z"]; me = []};
   Diffutils.Patch3.Keep 1]
# let a = Patch3.apply base m ;;
val a : Diff3.t =
  [Diffutils.Diff3.Same "a";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = []; you = []; me = [Diffutils.Patch.Add "y"]};
   Diffutils.Diff3.Same "b";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = []; you = [Diffutils.Patch.Add "z"]; me = []};
   Diffutils.Diff3.Same "c"]
# let m = Diff3.diff3 ~base ~you ~me ;;
val m : Diff3.t =
  [Diffutils.Diff3.Same "a";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = []; you = []; me = [Diffutils.Patch.Add "y"]};
   Diffutils.Diff3.Same "b";
   Diffutils.Diff3.Diff
    {Diffutils.Conflict.base = []; you = [Diffutils.Patch.Add "z"]; me = []};
   Diffutils.Diff3.Same "c"]
# let m = Merge.merge ~resolver:Merge.no_resolver ~base ~you ~me () ;;
val m : Merge.t =
  [Diffutils.Merge.Resolved "a";
   Diffutils.Merge.Unresolved
    {Diffutils.Conflict.base = []; you = []; me = [Diffutils.Patch.Add "y"]};
   Diffutils.Merge.Resolved "b";
   Diffutils.Merge.Unresolved
    {Diffutils.Conflict.base = []; you = [Diffutils.Patch.Add "z"]; me = []};
   Diffutils.Merge.Resolved "c"]
```


```ocaml
# let my_resolve ({ Conflict.base; me; you } as c) =
  let me = Patch.apply base me and you = Patch.apply base you in
  match (base, me, you) with
  | [ base ], [ me ], [ you ] ->
      let me = String.split_on_char ' ' me
      and base = String.split_on_char ' ' base
      and you = String.split_on_char ' ' you in
      let m = Merge.merge ~me ~base ~you () in
      let begin_ = [ "|||" ]
      and sep1 = [ "|||" ]
      and sep2 = [ "|||" ]
      and end_ = [ "|||" ] in
      let merged =
        Merge.total_merge m (Merge.git_total_resolver ~begin_ ~sep1 ~sep2 ~end_)
      in
      [ Merge.Resolved (String.concat " " merged) ]
  | _ -> [ Unresolved c ];;
val my_resolve : Conflict.t -> Merge.hunk list = <fun>
# let base = ["abc def ghi jkl"] and you = ["abc xxx def ghi jkl"] and me = ["abc def ghi yyy jkl"];;
val base : string list = ["abc def ghi jkl"]
val you : string list = ["abc xxx def ghi jkl"]
val me : string list = ["abc def ghi yyy jkl"]
# Merge.apply_resolver my_resolve @@ Merge.merge ~base ~me ~you ();;
- : Merge.t = [Diffutils.Merge.Resolved "abc xxx def ghi yyy jkl"]
```
