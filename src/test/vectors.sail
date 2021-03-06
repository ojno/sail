let (bit[3]) v = 0b101
let (bit[4]) v2 = [0,1,0,0]
register (bit[4]) i

let (bit[10]) v3 = 0b0101010111
register (bit[10]) slice_check
register (bit[10]) slice_check_copy
register nat result

function forall Type 'a . 'a id ( x ) = x

register nat match_success
register nat add_check
register bit partial_check

let (vector<0,3,inc,(register<(bit[10])>)>) gpr_small = [slice_check,slice_check,slice_check]

let (bit[3]) indexed = [0=1,1=1,2=0]
let (bit[50]) partial = [0 = 0, 5=1, 32=0; default = 0]
let (bit[50]) partial_unspec = [0=0, 4=0, 7=1, 49=1]

function unit decode ([bitzero, bitzero, bitone, bitzero]) = match_success := 1
and decode x = match_success := x

register (bit[32 : 63]) CR
register (bit[5]) BA

function bit main _ = {

  slice_check := v3;
  slice_check := v3[1..10];
  slice_check := v3[5..10];

  gpr_small[1] := v3; (*Writes to slice_check*)
  slice_check_copy := gpr_small[1];
  (* check that cast are inserted inside function calls (here +), and that the
  previous assignment (to slice_check_copy) got the correct cast *)
  result := gpr_small[1] + slice_check_copy;
  (* idem with type inference for return type *)
  fresh_var := gpr_small[1] + gpr_small[1];
  (* id function call - prevents the correct cast currently *)
  result := gpr_small[1] + id(gpr_small[1]);
 
  add_check := gpr_small[2] + 3;
  partial_check := partial[5];
  partial_check := partial[49];

  i := [bitzero, bitzero, bitone, bitzero];

  (* literal match *)
  switch v {
    case 0b101 -> match_success := 1
    case _ -> match_success := v
  };

  switch i {
    case [bitzero, bitzero, bitone, bitzero] -> match_success := 1
    case _ -> match_success := i
  };

  decode(i);

  (* concatenation *)
  switch i {
    case ([bitzero] : [bitzero, bitone] : [bitzero]) -> match_success := 1
    case _ -> match_success := i
  };
  switch i {
    (* check order of concatenation *)
    case ([bitzero] : [bitone] : [bitzero] : [bitzero]) -> match_success := 99
    case ([bitzero] : [bitzero] : [bitone] : [bitzero]) -> match_success := 1
    case _ -> match_success := i
  };

  (* indexed match *)
  switch i {
    case [0=bitzero, 1=bitzero, 2=bitone, 3=bitzero] -> match_success := 1
    case _ -> match_success := i
  };

  (* slice update *)
  i[0] := bitzero;
  i[2 .. 3] := [bitone, bitone];

  (* constraints checking *)
  BA := 12;
  CR := 0b00000000000000000000000000000000;
  CR[32 + BA] := CR[32 + BA];

  (* slice access of literal *)
  v[0];
}
