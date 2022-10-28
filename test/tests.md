
```ocaml
open Diffutils

let printer = DiffString.Diff.git_printer
let html_printer = DiffString.Diff.html_printer
open DiffString
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
  [Diffutils.DiffString.Patch.Keep 4; Diffutils.DiffString.Patch.Remove 3;
   Diffutils.DiffString.Patch.Add "bli";
   Diffutils.DiffString.Patch.Add "bla"; Diffutils.DiffString.Patch.Keep 5;
   Diffutils.DiffString.Patch.Remove 2; Diffutils.DiffString.Patch.Add "bb";
   Diffutils.DiffString.Patch.Keep 2; Diffutils.DiffString.Patch.Add "16"]
# let p = Diff.diff ~orig ~new_ ;;
val p : Diff.t =
  [Diffutils.DiffString.Diff.Same "0"; Diffutils.DiffString.Diff.Same "1";
   Diffutils.DiffString.Diff.Same "2"; Diffutils.DiffString.Diff.Same "3";
   Diffutils.DiffString.Diff.Diff
    {Diffutils.DiffString.Diff.orig = ["4"; "5"; "6"]; new_ = ["bli"; "bla"]};
   Diffutils.DiffString.Diff.Same "7"; Diffutils.DiffString.Diff.Same "8";
   Diffutils.DiffString.Diff.Same "9"; Diffutils.DiffString.Diff.Same "10";
   Diffutils.DiffString.Diff.Same "11";
   Diffutils.DiffString.Diff.Diff
    {Diffutils.DiffString.Diff.orig = ["12"; "13"]; new_ = ["bb"]};
   Diffutils.DiffString.Diff.Same "14"; Diffutils.DiffString.Diff.Same "15";
   Diffutils.DiffString.Diff.Diff
    {Diffutils.DiffString.Diff.orig = []; new_ = ["16"]}]

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
  [Diffutils.DiffString.Diff.Same "1"; Diffutils.DiffString.Diff.Same "2";
   Diffutils.DiffString.Diff.Same "3";
   Diffutils.DiffString.Diff.Diff
    {Diffutils.DiffString.Diff.orig = ["4"]; new_ = []};
   Diffutils.DiffString.Diff.Same "5";
   Diffutils.DiffString.Diff.Diff
    {Diffutils.DiffString.Diff.orig = ["6"]; new_ = ["10"]};
   Diffutils.DiffString.Diff.Same "7"]
val p2 : Diff.t =
  [Diffutils.DiffString.Diff.Same "1"; Diffutils.DiffString.Diff.Same "2";
   Diffutils.DiffString.Diff.Same "3"; Diffutils.DiffString.Diff.Same "4";
   Diffutils.DiffString.Diff.Same "5";
   Diffutils.DiffString.Diff.Diff
    {Diffutils.DiffString.Diff.orig = ["6"]; new_ = ["11"]};
   Diffutils.DiffString.Diff.Same "7";
   Diffutils.DiffString.Diff.Diff
    {Diffutils.DiffString.Diff.orig = []; new_ = ["8"]}]
# let diff_abc = Diff3.diff3 ~base ~me ~you ;;
val diff_abc : Diff3.t =
  [Diffutils.DiffString.Diff3.Same "1"; Diffutils.DiffString.Diff3.Same "2";
   Diffutils.DiffString.Diff3.Same "3";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = ["4"];
     you = [Diffutils.DiffString.Patch.Keep 1];
     me = [Diffutils.DiffString.Patch.Remove 1]};
   Diffutils.DiffString.Diff3.Same "5";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = ["6"];
     you =
      [Diffutils.DiffString.Patch.Remove 1;
       Diffutils.DiffString.Patch.Add "11"];
     me =
      [Diffutils.DiffString.Patch.Remove 1;
       Diffutils.DiffString.Patch.Add "10"]};
   Diffutils.DiffString.Diff3.Same "7";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = [];
     you = [Diffutils.DiffString.Patch.Add "8"]; me = []}]
```

Let's print it!

```ocaml
# let m = Patch3.get_patch3 ~base ~me ~you ;;
Line 1, characters 9-26:
Error: Unbound value Patch3.get_patch3
Hint: Did you mean get_patch?
# let m = Diff3.diff3 ~base ~me ~you ;;
val m : Diff3.t =
  [Diffutils.DiffString.Diff3.Same "1"; Diffutils.DiffString.Diff3.Same "2";
   Diffutils.DiffString.Diff3.Same "3";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = ["4"];
     you = [Diffutils.DiffString.Patch.Keep 1];
     me = [Diffutils.DiffString.Patch.Remove 1]};
   Diffutils.DiffString.Diff3.Same "5";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = ["6"];
     you =
      [Diffutils.DiffString.Patch.Remove 1;
       Diffutils.DiffString.Patch.Add "11"];
     me =
      [Diffutils.DiffString.Patch.Remove 1;
       Diffutils.DiffString.Patch.Add "10"]};
   Diffutils.DiffString.Diff3.Same "7";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = [];
     you = [Diffutils.DiffString.Patch.Add "8"]; me = []}]
# let printer = Diff3.git_printer ;;
val printer : Merge.printer =
  {Diffutils.DiffString.Diff3.same = <fun>; diff = <fun>}

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
  [Diffutils.DiffString.Patch3.Keep 1;
   Diffutils.DiffString.Patch3.Conflict
    {Diffutils.DiffString.Patch3.you = [];
     me = [Diffutils.DiffString.Patch.Add "y"]};
   Diffutils.DiffString.Patch3.Keep 1;
   Diffutils.DiffString.Patch3.Conflict
    {Diffutils.DiffString.Patch3.you = [Diffutils.DiffString.Patch.Add "z"];
     me = []};
   Diffutils.DiffString.Patch3.Keep 1]
# let a = Patch3.apply base m ;;
val a : Diff3.t =
  [Diffutils.DiffString.Diff3.Same "a";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = []; you = [];
     me = [Diffutils.DiffString.Patch.Add "y"]};
   Diffutils.DiffString.Diff3.Same "b";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = [];
     you = [Diffutils.DiffString.Patch.Add "z"]; me = []};
   Diffutils.DiffString.Diff3.Same "c"]
# let m = Diff3.diff3 ~base ~you ~me ;;
val m : Diff3.t =
  [Diffutils.DiffString.Diff3.Same "a";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = []; you = [];
     me = [Diffutils.DiffString.Patch.Add "y"]};
   Diffutils.DiffString.Diff3.Same "b";
   Diffutils.DiffString.Diff3.Diff
    {Diffutils.DiffString.Conflict.base = [];
     you = [Diffutils.DiffString.Patch.Add "z"]; me = []};
   Diffutils.DiffString.Diff3.Same "c"]
# let m = Merge.merge ~resolver:Merge.no_resolver ~base ~you ~me () ;;
val m : Merge.t =
  [Diffutils.DiffString.Merge.Resolved "a";
   Diffutils.DiffString.Merge.Unresolved
    {Diffutils.DiffString.Conflict.base = []; you = [];
     me = [Diffutils.DiffString.Patch.Add "y"]};
   Diffutils.DiffString.Merge.Resolved "b";
   Diffutils.DiffString.Merge.Unresolved
    {Diffutils.DiffString.Conflict.base = [];
     you = [Diffutils.DiffString.Patch.Add "z"]; me = []};
   Diffutils.DiffString.Merge.Resolved "c"]
```
