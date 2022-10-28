
```ocaml
open Diffutils

let printer = DiffString.git_diff_printer
let html_printer = DiffString.html_diff_printer
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

# let p = get_patch ~orig ~new_ ;;
val p : patch =
  [Keep 4; Remove 3; Add "bli"; Add "bla"; Keep 5; Remove 2; Add "bb";
   Keep 2; Add "16"]
# let p = diff ~orig ~new_ ;;
val p : diff =
  [Same "0"; Same "1"; Same "2"; Same "3";
   Diff {orig = ["4"; "5"; "6"]; new_ = ["bli"; "bla"]}; Same "7"; Same "8";
   Same "9"; Same "10"; Same "11"; Diff {orig = ["12"; "13"]; new_ = ["bb"]};
   Same "14"; Same "15"; Diff {orig = []; new_ = ["16"]}]

# let _ = Fmt.pr "%a" (pp_diff printer) p; Format.printf "%!" ;;
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
# let _ = Fmt.pr "%a%!" (pp_diff html_printer) p ;;
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
# let p1 = diff ~orig:base ~new_:me and p2 = diff ~orig:base ~new_:you;;
val p1 : diff =
  [Same "1"; Same "2"; Same "3"; Diff {orig = ["4"]; new_ = []}; Same "5";
   Diff {orig = ["6"]; new_ = ["10"]}; Same "7"]
val p2 : diff =
  [Same "1"; Same "2"; Same "3"; Same "4"; Same "5";
   Diff {orig = ["6"]; new_ = ["11"]}; Same "7";
   Diff {orig = []; new_ = ["8"]}]
# let diff_abc = diff3 ~base ~me ~you ;;
val diff_abc : diff3 =
  [Same3 "1"; Same3 "2"; Same3 "3";
   Diff3 {base = ["4"]; you = [Keep 1]; me = [Remove 1]}; Same3 "5";
   Diff3
    {base = ["6"]; you = [Remove 1; Add "11"]; me = [Remove 1; Add "10"]};
   Same3 "7"; Diff3 {base = []; you = [Add "8"]; me = []}]
```

Let's print it!

```ocaml
# let m = get_patch3 ~base ~me ~you ;;
val m : patch3 =
  [Keep3 3; Conflict {Diffutils.DiffString.you = [Keep 1]; me = [Remove 1]};
   Keep3 1;
   Conflict
    {Diffutils.DiffString.you = [Remove 1; Add "11"];
     me = [Remove 1; Add "10"]};
   Keep3 1; Conflict {Diffutils.DiffString.you = [Add "8"]; me = []}]
# let m = diff3 ~base ~me ~you ;;
val m : diff3 =
  [Same3 "1"; Same3 "2"; Same3 "3";
   Diff3 {base = ["4"]; you = [Keep 1]; me = [Remove 1]}; Same3 "5";
   Diff3
    {base = ["6"]; you = [Remove 1; Add "11"]; me = [Remove 1; Add "10"]};
   Same3 "7"; Diff3 {base = []; you = [Add "8"]; me = []}]
# let printer = git_merge_printer ;;
val printer : diff3_printer = {same = <fun>; diff = <fun>}

# let _ = Fmt.pr "%a%!" (pp_diff3 printer) m;;
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
# let _ = Fmt.pr "%a%!" (pp_merge printer) (merge ~base ~you ~me ());;
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
